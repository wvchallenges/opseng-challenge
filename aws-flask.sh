#!/bin/bash
set -e
INSTANCE_NAME="ashew-flask-app-$(date +%y%m%d-%H%M)"
echo -e "Creating unique keypair\n"
aws ec2 create-key-pair --key-name ${INSTANCE_NAME} --query '[KeyMaterial]' --output text > ${INSTANCE_NAME}.pem
echo -e "Private key stored in current directory as ${INSTANCE_NAME}.pem - Please do not commit it to git!\n"
echo -e "Launching ec2 instance as ${INSTANCE_NAME}\n"
INSTANCE_ID=$(aws ec2 run-instances --image-id ami-7b386c11 --instance-type t1.micro --subnet-id subnet-dddef6ab --key-name ${INSTANCE_NAME} --security-group-ids sg-ee6ada95 --associate-public-ip-address | grep "InstanceId" | cut -f4 -d '"')
sleep 3
aws ec2 create-tags --resources ${INSTANCE_ID} --tags Key=Name,Value=${INSTANCE_NAME}
echo -ne "$INSTANCE_ID created, waiting for state to be running"
while ! [[ $(aws ec2 describe-instances --instance-id ${INSTANCE_ID} --query 'Reservations[*].Instances[*].[State.Name]' --output text) == 'running' ]] ; do
  echo -ne "."
  sleep 5
done
echo -ne "done!\n\n"
sleep 10
PUBLIC_IP=$(aws ec2 describe-instances --instance-id ${INSTANCE_ID} --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[Association.PublicIp]' --output text)
echo -ne "Waiting for SSH to open"
RC=1
while [[ $RC -ne 0 ]] ; do
  echo -ne "."
  sleep 5
  ssh -q -o 'StrictHostKeyChecking no' -i ${INSTANCE_NAME}.pem ubuntu@${PUBLIC_IP} exit && RC=$?
done
echo -ne "ready!\n\n"
echo "Tarballing up our chef cookbook for bootstrapping and moving ahead"
tar cj . | ssh -o 'StrictHostKeyChecking no' -i ${INSTANCE_NAME}.pem ubuntu@${PUBLIC_IP} '
sudo rm -rf ~/chef &&
mkdir ~/chef &&
cd ~/chef &&
tar xj &&
cd ashew-flask &&
sudo apt-get -qq install chef &&
sudo service chef-client stop &&
sudo update-rc.d chef-client disable &&
sudo apt-get update -qq &&
sudo chef-solo -c ashew-flask-solo.rb -j ashew-flask-solo.json
'
echo -e "\n\n*********************************************************************\n Chef run complete, webserver should be serving on ${PUBLIC_IP}\n*********************************************************************\n"
exit

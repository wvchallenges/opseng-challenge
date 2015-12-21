#!/bin/bash
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Need to set AWS_ACCESS_KEY_ID"
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Need to set AWS_SECRET_ACCESS_KEY"
    exit 1
fi

# Run these steps as-needed to install jq, pip, wget, boto and awscli
echo installing prerequisites ...
sudo apt-get -Vy install jq python-pip software-properties-common wget 2>&1 >> install.log
sudo pip install awscli boto 2>&1 >> install.log
sudo apt-add-repository -y ppa:ansible/ansible 2>&1 >> install.log
sudo apt-get update -qq
sudo apt-get install -Vy ansible 2>&1 >> install.log

echo create key pair
aws ec2 create-key-pair --key-name rvanoo-key-pair | jq -r .KeyMaterial > ~/.ssh/rvanoo-aws-ec2-key.pem
chmod 600 ~/.ssh/rvanoo-aws-ec2-key.pem

echo capture own IP address
MY_IP=`wget http://ipinfo.io/ip -qO -`

echo "create security group and open SSH and HTTP to own IP address ($MY_IP) only"
aws ec2 create-security-group --group-name rvanoo-web --description 'ssh and http access' > /dev/null
aws ec2 authorize-security-group-ingress --group-name rvanoo-web --protocol tcp --port 22 --cidr $MY_IP/32 > /dev/null
aws ec2 authorize-security-group-ingress --group-name rvanoo-web --protocol tcp --port 80 --cidr $MY_IP/32 > /dev/null

echo create EC2 instance
INSTANCE_ID=`aws ec2 run-instances --image-id ami-b82176d2 --count 1 --key-name rvanoo-key-pair --instance-type t1.micro --associate-public-ip-address | jq -r .Instances[].InstanceId`
AZ=`aws ec2 describe-instances --instance-id $INSTANCE_ID | jq -r .Reservations[].Instances[].Placement.AvailabilityZone`
echo "instance $INSTANCE_ID created in the $AZ availability zone" 

echo -n "waiting for instance to finish initializing "
while true; do
    echo -n .
    sleep 10
    status=`aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r .Reservations[].Instances[].State.Name`
    if [ "$status" == "running" ]; then
        echo
        break
    fi
done
echo instance in 'running' state

PUBLIC_IP=`aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r .Reservations[].Instances[].PublicIpAddress`
echo "found public IP address ($PUBLIC_IP)"

# add security group to instance
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --groups `aws ec2 describe-security-groups | jq -r .SecurityGroups[].GroupId` > /dev/null

# set Name tag on instance
SECURITY_GROUP_ID=`aws ec2 describe-security-groups --group-name 'default' | jq -r .SecurityGroups[].GroupId`
aws ec2 create-tags --resources $INSTANCE_ID $SECURITY_GROUP_ID --tags Key=Name,Value=rvanoo-web > /dev/null

echo -n "waiting for instance to start SSH server "
while true; do
    echo -n .
    sleep 10
    nmap $PUBLIC_IP -PN -p ssh | grep -q 'open'
    RESULT=$?
    if [ "$RESULT" -eq 0 ]; then
        echo
        break
    fi
done

echo running playbook on new instance at $PUBLIC_IP ...
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ec2.py --private-key=~/.ssh/rvanoo-aws-ec2-key.pem -u ubuntu -b deploy.yml

echo "Flask application is running at http://$PUBLIC_IP"

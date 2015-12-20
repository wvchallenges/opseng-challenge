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
# sudo apt-get -yV install jq python-pip software-properties-common wget
# sudo apt-add-repository -y ppa:ansible/ansible
# sudo apt-get update -qq
# sudo pip install awscli boto
# sudo apt-get install -y ansible

# capture own IP address
MY_IP=`wget http://ipinfo.io/ip -qO -`

echo create key pair
aws ec2 create-key-pair --key-name rvanoo-key-pair | jq -r .KeyMaterial > ~/.ssh/rvanoo-ec2-key.pem
chmod 600 ~/.ssh/rvanoo-key.pem

echo "create security group and open SSH and HTTP to own IP address ($MY_IP) only"
aws ec2 create-security-group --group-name rvanoo-web --description 'ssh and http access' > /dev/null
aws ec2 authorize-security-group-ingress --group-name rvanoo-web --protocol tcp --port 22 --cidr $MY_IP/32 > /dev/null
aws ec2 authorize-security-group-ingress --group-name rvanoo-web --protocol tcp --port 80 --cidr $MY_IP/32 > /dev/null

echo create EC2 instance
INSTANCE_ID=`aws ec2 run-instances --image-id ami-b82176d2 --count 1 --key-name rvanoo-key-pair --instance-type t1.micro --associate-public-ip-address | jq -r .Instances[].InstanceId`

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
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --groups `aws ec2 describe-security-groups | jq -r .SecurityGroups[].GroupId` > /dev/null
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=rvanoo-web > /dev/null

echo running playbook on new instance at $PUBLIC_IP ...
ansible-playbook -i ec2.py --private-key=~/.ssh/rvanoo-key.pem -u ubuntu -b $PUBLIC_IP -m ping

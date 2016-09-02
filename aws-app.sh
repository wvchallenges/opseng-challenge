#!/bin/bash

# ==========================================================================================
#
# Date: August 16, 2016
#
# Author: The-Binh Le
#
# Usage:
#  - Copy this script to an empty, writeable directory on your local Linux system with
#    aws cli installed
#  - Make sure the script is executable: chmod +x aws-app.sh
#  - Run it: ./aws-app.sh
#
# ------------------------------------------------------------------------------------------
#
# This script responds to the Opseng challenge.
# It is meant to be run by anyone with valid access to AWS EC2.
#
# The script does the following:
#
# 1) Gathering the AWS credentials and set environment variables
# 2) Creating a key pair for ssh access to EC2 instance
# 3) Creating a security group to allow inbound access to ports 22 (ssh) and 8000 (web app)
#    of EC2 instance
# 4) Creating an EC2 instance
# 5) Deploying and running Docker image tledocker/waveweb (priorly built by myself)
#    on EC2 instance to provision the web app
# 6) Displaying the URL to access the app from the Internet
# 7) Cleaning up EC2 artifacts (i.e., key pair, security group and EC2 instance)
#    and local temporary files
#
# NOTE: Initially I planned to use AWS EC2 Container Service (ECS) to deploy the web app,
# however I realized my AWS account was not permitted to perform certain ECS operations
# so I implemented the above instead. The idea is to showcase the use of Docker container
# to provision services.
#
# ==========================================================================================

#
# Gather AWS credentials and set region
# 
echo
echo "INFO: This section is to gather AWS access details."
echo "INFO: To simplify the process, please provide the access details anyway"
echo "INFO: even if you have already run 'aws configure'."
echo "INFO: If you have set environment variables AWS_ACCESS_KEY_ID and"
echo "INFO: AWS_SECRET_ACCESS_KEY you will not be prompted."
echo

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
   echo -n "Enter your aws access key id: "; read AWS_ACCESS_KEY_ID
   export AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo -n "Enter your aws secret access key: "; read AWS_SECRET_ACCESS_KEY
   export AWS_SECRET_ACCESS_KEY
fi

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo "ERROR: AWS credentials are not provided. Exit."
   exit 2
fi

# Set AWS region accordingly. Here we use us-west-2.

export AWS_DEFAULT_REGION=us-west-2

#
# Set some variables
#
VPCID="vpc-45e8a320"   # default VPC
KEY_PAIR_NAME=tle-key-pair
SEC_GROUP_NAME=tle-security-group
IMAGE_ID=ami-a426edc4  # ECS-optimized image for us-west-2

#
# Create key pair and save private key
#
echo
echo "INFO: Creating key pair..."
echo
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME > ${KEY_PAIR_NAME}.out 2>&1
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to create key pair. See ${KEY_PAIR_NAME}.out for details. Exit."
   exit 3
fi

grep -i keymaterial ${KEY_PAIR_NAME}.out | awk -F'"' '{ print $4 }' | sed -e's/\\n/\n/g' > ${KEY_PAIR_NAME}.pem
chmod 600 ${KEY_PAIR_NAME}.pem
echo "INFO: Private key file is ${KEY_PAIR_NAME}.pem"

#
# Create security group
#
echo
echo "INFO: Creating security group..."
echo
aws ec2 create-security-group --group-name $SEC_GROUP_NAME --description "My Security Group" --vpc-id $VPCID > ${SEC_GROUP_NAME}.out 2>&1
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to create security group $SEC_GROUP_NAME. See ${SEC_GROUP_NAME}.out for details. Exit."
   exit 4
fi

# Allow access to port 22 for ssh

aws ec2 authorize-security-group-ingress --group-name $SEC_GROUP_NAME --protocol tcp --port 22 --cidr 0.0.0.0/0 > ${SEC_GROUP_NAME}.ssh.out 2>&1
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to allow access for ssh. See ${SEC_GROUP_NAME}.ssh.out for details. Exit."
   exit 4
fi

# Allow access to port 8000 for web app

aws ec2 authorize-security-group-ingress --group-name $SEC_GROUP_NAME --protocol tcp --port 8000 --cidr 0.0.0.0/0 > ${SEC_GROUP_NAME}.app.out 2>&1
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to allow access for app. See ${SEC_GROUP_NAME}.app.out for details. Exit."
   exit 4
fi

SECGRPID=`aws ec2 describe-security-groups --group-name $SEC_GROUP_NAME | grep -i groupid | awk -F'"' '{ print $4 }'`

echo "INFO: The created security group ID is $SECGRPID"

#
# Create an EC2 instance
#
echo
echo "INFO: Creating an EC2 instance..."
echo
aws ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type t2.micro --key-name $KEY_PAIR_NAME --security-group-ids $SECGRPID > create-instance.out
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to create EC2 instance. See create-instance.out for details. Exit."
   exit 5
fi

echo "INFO: Waiting until the EC2 instance is up and running..."
INSTID=`grep -i instanceid create-instance.out | awk -F'"' '{ print $4 }'`
echo "INFO: EC2 instance ID is $INSTID"

aws ec2 wait instance-running --instance-ids $INSTID
if [ $? -ne 0 ]; then
   echo "ERROR: Instance failed to come up. Exit."
   exit 5
fi

# Get public DNS hostname of the instance

aws ec2 describe-instances --instance-ids $INSTID > describe-instance.out
HNAME=`grep -i publicdnsname describe-instance.out | awk -F'"' '{ print $4 }' | uniq`

#
# Deploy the web app inside a Docker container running on the EC2 instance
#

echo
echo "INFO: Deploying the web app inside a Docker container running on EC2 instance..."
echo "INFO: Making sure ssh on $HNAME is ready before proceeding..."
while :
do
   ssh -i ${KEY_PAIR_NAME}.pem -o "StrictHostKeyChecking=no" ec2-user@${HNAME} pwd > /dev/null 2>&1
   if [ $? -eq 0 ]; then
      echo "INFO: ssh on $HNAME is ready. Proceeding..."
      break
   fi
   echo "INFO: Waiting another 5 seconds for ssh on $HNAME to become ready..."
   sleep 5
done

echo
echo "INFO: Deploying the web app in a Docker container running on EC2 instance..."
echo

# Quick note: Since the AMI image used is ECS-optimized so docker has been pre-installed
# in the image. In a more general case, docker installation should probably be added.
#
ssh -i ${KEY_PAIR_NAME}.pem -T -o "StrictHostKeyChecking=no" ec2-user@${HNAME} <<EOF
sudo -i
service docker start
docker pull tledocker/waveweb
docker run -d --name mywaveapp -p 8000:8000 tledocker/waveweb
EOF

echo
echo "INFO: Point your web browser to http://${HNAME}:8000 to verify"
echo

#
# Clean things up
#
echo -n "Enter \"Y\" to clean up things on AWS and in local directory prior to exiting: "; read ANS
if [ "$ANS" != "Y" ]; then
   echo "INFO: You have chosen to exit without cleaning things up. Exit."
   exit
fi

echo
echo "INFO: Stopping EC2 instance..."
aws ec2 stop-instances --force --instance-ids $INSTID > /dev/null 2>&1
sleep 5
echo "INFO: Terminating EC2 instance..."
aws ec2 terminate-instances --instance-ids $INSTID > /dev/null 2>&1

echo
echo "INFO: Deleting key pair..."
aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME

echo
echo "INFO: Deleting security group..."
while :
do
   aws ec2 delete-security-group --group-name $SEC_GROUP_NAME > /dev/null 2>&1
   if [ $? -eq 0 ]; then
      echo "INFO: Security group \"$SEC_GROUP_NAME\" deleted"
      break
   fi
   echo "INFO: Waiting another 10 seconds then delete it again (due to dependency)..."
   sleep 10
done

echo
echo "INFO: Deleting local temporary files..."
rm -f *.out *.pem

#
# END
#
echo
echo "INFO: Program has ended."

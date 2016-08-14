#!/usr/bin/env bash

AMI="ami-2d39803a"
SECURITY_GROUP="hecber_sg"
INSTANCE_NAME="hecber_wave"
APP_PORT="8080"
INSTANCE_TYPE="t2.micro"
USER_DATA="user_data.sh"

# Check if ACCESS KEY ID has been defined
if [ -z ${AWS_ACCESS_KEY_ID} ]; then
  echo "Please set and export AWS_ACCESS_KEY_ID"
  exit 2
fi
# Check if SECRET ACCESS KEy has been defined
if [ -z ${AWS_SECRET_ACCESS_KEY} ]; then
  echo "Please set and export AWS_SECRET_ACCESS_KEY"
  exit 2
fi
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION-"us-east-1"}
export AMI
export SECURITY_GROUP
export INSTANCE_NAME
export APP_PORT
export INSTANCE_TYPE
export USER_DATA

# Create Security Group, port 8000 must be open
aws ec2 create-security-group --group-name "${SECURITY_GROUP}" \
--description "${SECURITY_GROUP}" >/dev/null 2>&1

# Add Rules to the Security Group
aws ec2 authorize-security-group-ingress --group-name "${SECURITY_GROUP}" \
--protocol tcp --port "${APP_PORT}" --cidr 0.0.0.0/0 >/dev/null 2>&1

# Run instance
INSTANCE_ID=`aws ec2 run-instances --image-id "${AMI}" --count 1 \
--security-groups "${SECURITY_GROUP}" \
--instance-type "${INSTANCE_TYPE}" \
--user-data file://"${USER_DATA}" | grep InstanceId | egrep -o "i\-[0-9a-f]+"`

# Get Public Ip Address
IP_ADDR=`aws ec2 describe-instances \
--filter "Name=instance-id,Values=${INSTANCE_ID}" | grep PublicIpAddress | egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"`
sleep 25
# Give some time to provision
for((I=0;$I<10;I=$I+1))
do
curl --connect-timeout 8 "http://${IP_ADDR}:${APP_PORT}" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  break
fi
sleep 6
done

# Output URL
echo "http://${IP_ADDR}:${APP_PORT}"

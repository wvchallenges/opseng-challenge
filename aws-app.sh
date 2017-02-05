#!/bin/bash


# aws-app.sh script for Wave ops engineering challenge
# Glen Yu
# 2017.01.26
# assumption: whomever runs this has access key id & secret access key for gyu


# launch amazon ecs ami instance in us-west-2
#aws ec2 run-instances --image-id ami-8e7bc4ee --count 1 --instance-type t2.micro --key-name gyu --security-groups glen-sg

# run task -- if one is already running nothing this does nothing -- output redirected
aws ecs run-task --cluster glen-cluster --task-definition glen-task:1 --count 1 > /dev/null 2>&1

# get instance state & id
RUNNING_INSTANCE_ID=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text | grep -E "pending|running" | awk '{print $2}')

#############################################################################################################
# No need for this section as cluster will terminate a stopped instance and start up a new one on its own
#############################################################################################################
#if [ "${RUNNING_INSTANCE_ID}" == "" ]
#then
#	#no running instances
#	STOPPED_INSTANCE_ID=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[State.Name, InstanceId]' --output text | grep -E "shutting-down|terminated|stopping|stopped" | awk '{print $2}')
#	aws ec2 start-instances --instance-id ${STOPPED_INSTANCE_ID}
#fi
##############################################################################################################

# output public dns name of running instance & port
echo -n "$(aws ec2 describe-instances --instance-id ${RUNNING_INSTANCE_ID} --query 'Reservations[].Instances[].PublicDnsName' --output text):8000"

echo ''

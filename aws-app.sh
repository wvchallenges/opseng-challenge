#!/bin/bash

# Basic Python app git parameters
HELLO_APP_GIT_URL=https://github.com/wvchallenges/opseng-challenge-app
HELLO_APP_DEFAULT_BRANCH_OR_TAG=master

# SSH Key Pair name
KEY_PAIR_NAME=julien.HelloAppKey

# Security group
SECGRP_NAME=julien.HelloAppSecGrp
SECGRP_DESC="Security group for Hello App access"
SECGRP_RULES_PORT=( 22 80 )

# Variables related to EC2 Instance installation and configuration
REQUIRED_PKGS="git-core nginx python python-pip"
HELLOAPP_INSTALLDIR=/var/www/helloapp
GUNICORN_PORT=8000
# Base Nginx configuration to use for app publication
NGINX_TEMPLATE=resources/nginx/helloapp
NGINX_CONFDIR=/etc/nginx

# AWS EC2 Instance parameters
AWS_EC2_INSTANCE_TYPE=t2.micro
AWS_EC2_INSTANCE_TAG_NAME=Name
AWS_EC2_INSTANCE_TAG_VALUE=julien.HelloAppInstance

# Ubuntu Xenial Amazon image
AWS_EC2_UBUNTU_AMI_ID=ami-7c803d1c
AWS_EC2_UBUNTU_LOGIN=ubuntu

# SSH related commands for EC2 Instance
SSH_CMD="ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/${KEY_PAIR_NAME}.pem -l ${AWS_EC2_UBUNTU_LOGIN}"
SCP_CMD="scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/${KEY_PAIR_NAME}.pem"

# Get this script install dir
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/inc/outputs.sh"
source "${SCRIPT_DIR}/inc/aws.sh"
source "${SCRIPT_DIR}/inc/aws-app-steps.sh"

HELLO_APP_BRANCH_OR_TAG=
while [ $# -ge 1 ]
do
  key="$1"

  case $key in
      -b|--branch-or-tag)
      HELLO_APP_BRANCH_OR_TAG="$2"
      shift # past argument
      ;;
      -h|--help)
      printHelp
      exit 0
      ;;
      *)
              # unknown option
      ;;
  esac
  shift # past argument or value
done

if [ -z "${HELLO_APP_BRANCH_OR_TAG}" ]; then
  HELLO_APP_BRANCH_OR_TAG=$HELLO_APP_DEFAULT_BRANCH_OR_TAG
fi

echoStep "Starting HelloApp deployment"

# 1- Manage SSH key pair
manageKeypair ${KEY_PAIR_NAME}

# 2- Manage security group
manageSecGrp ${SECGRP_NAME} "${SECGRP_DESC}"

# 3- Create EC2 instance
manageInstance ${AWS_EC2_UBUNTU_AMI_ID} ${AWS_EC2_INSTANCE_TYPE} ${KEY_PAIR_NAME} ${SECGRP_NAME} ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE} "${SSH_CMD}"

INSTANCE_ID=$(getInstanceId ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE})
INSTANCE_PUBLIC_DNS_NAME=$(getInstancePublicDnsName ${INSTANCE_ID})
echoInfo "EC2 instance public DNS name: ${INSTANCE_PUBLIC_DNS_NAME}"

# 4- Configure instance and install app
setupAndDeployApp ${INSTANCE_PUBLIC_DNS_NAME} $HELLO_APP_BRANCH_OR_TAG $HELLO_APP_GIT_URL \
                  $HELLOAPP_INSTALLDIR $AWS_EC2_UBUNTU_LOGIN "$REQUIRED_PKGS" "${SCRIPT_DIR}/${NGINX_TEMPLATE}" \
                  $GUNICORN_PORT $NGINX_CONFDIR "$SSH_CMD" "$SCP_CMD"

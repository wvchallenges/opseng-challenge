#!/bin/bash

# Basic Python app git parameters
BASIC_APP_URL=https://github.com/wvchallenges/opseng-challenge-app
BASIC_APP_DEFAULT_BRANCH_OR_TAG=master

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

BASIC_APP_BRANCH_OR_TAG=
while [ $# -ge 1 ]
do
  key="$1"

  case $key in
      -b|--branch-or-tag)
      BASIC_APP_BRANCH_OR_TAG="$2"
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

if [ -z "${BASIC_APP_BRANCH_OR_TAG}" ]; then
  BASIC_APP_BRANCH_OR_TAG=$BASIC_APP_DEFAULT_BRANCH_OR_TAG
fi

echoStep "Starting HelloApp deployment"

# 1- Manage SSH key pair
echoStep "Manage SSH key pair"
checkKeypair ${KEY_PAIR_NAME}
if [ $? -ne 0 ]; then
  echoWarning "${KEY_PAIR_NAME} key pair does not exist. We are going to create it."
  createAndInstallKeypair ${KEY_PAIR_NAME}
  if [ $? -ne 0 ]; then
    echoError "Could not create and install new key pair. Exiting."
    exit 1
  fi
else
  echoSuccess "${KEY_PAIR_NAME} key pair already exists."
  if [ ! -f ~/.ssh/${KEY_PAIR_NAME}.pem ]; then
    echoWarning "Private key file does not exist locally. We are going to recreate key pair."
    deleteKeypair ${KEY_PAIR_NAME}
    if [ $? -ne 0 ]; then
      echoError "Could not delete existing key pair. Exiting."
      exit 1
    fi
    createAndInstallKeypair ${KEY_PAIR_NAME}
    if [ $? -ne 0 ]; then
      echoError "Could not create and install new key pair. Exiting."
      exit 1
    fi
  fi
fi

# 2- Manage security group
echoStep "Manage security group"
CREATE_RULES=0
checkSecGrp ${SECGRP_NAME}
if [ $? -ne 0 ]; then
  echoWarning "${SECGRP_NAME} security group does not exist. We are going to create it."
  createSecGrp ${SECGRP_NAME} "${SECGRP_DESC}"
  if [ $? -ne 0 ]; then
    echoError "Could not create security group. Exiting."
    exit 1
  fi
  CREATE_RULES=1
else
  echoSuccess "${SECGRP_NAME} security group already exists. Will check rules to be sure they exist."
  CREATE_RULES=1
fi

if [ $CREATE_RULES -eq 1 ]; then
  for i in "${SECGRP_RULES_PORT[@]}"
  do
  	createSecGrpRule ${SECGRP_NAME} ${i}
    if [ $? -ne 0 ]; then
      echoError "Could not create inbound rule for port ${i}. Exiting."
      exit 1
    fi
  done
fi

# 3- Create EC2 instance
echoStep "Create EC2 instance"
checkInstance ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE}
if [ $? -eq 0 ]; then
  echoInfo "EC2 instance already exists. We are going to try to ssh it."
  INSTANCE_ID=$(getInstanceId ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE})
  if [ $? -ne 0 ]; then
    echoError "Could not get EC2 instance ID"
    exit 1
  fi
  INSTANCE_PUBLIC_DNS_NAME=$(getInstancePublicDnsName ${INSTANCE_ID})
  if [ $? -ne 0 ]; then
    echoError "Could not get EC2 instance public DNS name"
    exit 1
  fi
  echoInfo "Existing EC2 instance public DNS name: ${INSTANCE_PUBLIC_DNS_NAME}"
  ${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} exit
  if [ $? -ne 0 ]; then
    echoError "Could not ssh EC2 instance. We are going to delete and recreate it."
    deleteInstance ${INSTANCE_ID}
    if [ $? -ne 0 ]; then
      echoError "Could not terminate existing instance. Exiting."
      exit 1
    fi
    echoSuccess "EC2 instance successfully deleted."
    INSTANCE_ID=$(createAndRunInstance ${AWS_EC2_UBUNTU_AMI_ID} ${AWS_EC2_INSTANCE_TYPE} ${KEY_PAIR_NAME} ${SECGRP_NAME})
    if [ $? -ne 0 ]; then
      echoError "Could not create and run new EC2 instance. Exiting."
      exit 1
    fi
    echoSuccess "EC2 instance successfully created and launched."
    echoInfo "Create tag for new instance"
    tagInstance ${INSTANCE_ID} ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE}
    if [ $? -ne 0 ]; then
      echoError "Could not create tag EC2 instance. Exiting."
      exit 1
    fi
    echoSuccess "EC2 instance successfully tagged."
  else
    echoSuccess "SSH connection to EC2 instance successfully acheived."
  fi
else
  echoInfo "EC2 instance not found, we are going to create it."
  INSTANCE_ID=$(createAndRunInstance ${AWS_EC2_UBUNTU_AMI_ID} ${AWS_EC2_INSTANCE_TYPE} ${KEY_PAIR_NAME} ${SECGRP_NAME})
  if [ $? -ne 0 ]; then
    echoError "Could not create and run new EC2 instance. Exiting."
    exit 1
  fi
  echoSuccess "EC2 instance successfully created and launched."
  echoInfo "Create tag for new instance"
  tagInstance ${INSTANCE_ID} ${AWS_EC2_INSTANCE_TAG_NAME} ${AWS_EC2_INSTANCE_TAG_VALUE}
  if [ $? -ne 0 ]; then
    echoError "Could not create tag EC2 instance. Exiting."
    exit 1
  fi
  echoSuccess "EC2 instance successfully tagged."
fi

INSTANCE_PUBLIC_DNS_NAME=$(getInstancePublicDnsName ${INSTANCE_ID})
echoInfo "EC2 instance public DNS name: ${INSTANCE_PUBLIC_DNS_NAME}"

echoStep "Wait some time so as to let EC2 instance start..."
sleep 5

# 4- Configure instance and install app
echoStep "Configure instance and install app"
echoInfo "Update available packages list"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "sudo apt-get update -q  > /dev/null 2>&1"
if [ $? -ne 0 ]; then
  echoError "Unable to update packages list. Exiting."
  exit 1
fi
echoSuccess "Packages list successfully updated."
echoInfo "Install required packages on instance (${REQUIRED_PKGS})"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "sudo apt-get install -yq ${REQUIRED_PKGS} > /dev/null 2>&1"
if [ $? -ne 0 ]; then
  echoError "Something went wrong during packages installation. Exiting."
  exit 1
fi
echoSuccess "Required packages successfully installed."
echoInfo "Get HelloApp code (branch or tag = ${BASIC_APP_BRANCH_OR_TAG})"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "sudo rm -rf ${HELLOAPP_INSTALLDIR} 2> /dev/null; \
                                        sudo mkdir -p ${HELLOAPP_INSTALLDIR} \
                                        && sudo chown ${AWS_EC2_UBUNTU_LOGIN} ${HELLOAPP_INSTALLDIR} \
                                        && cd ${HELLOAPP_INSTALLDIR} \
                                        && git clone --branch ${BASIC_APP_BRANCH_OR_TAG} --depth 1 ${BASIC_APP_URL} . > /dev/null 2>&1"
if [ $? -ne 0 ]; then
  echoError "Something went wrong during Hello App source code installation. Exiting."
  exit 1
fi
echoSuccess "Hello App source code successfully downloaded."
echoInfo "Install HelloApp Python requirements"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "cd ${HELLOAPP_INSTALLDIR} \
                                        && sudo pip install -r requirements.txt > /dev/null 2>&1"
if [ $? -ne 0 ]; then
  echoError "Something went wrong during Hello App Python requirements installation. Exiting."
  exit 1
fi
echoSuccess "Hello App source Python requirements successfully installed."
echoInfo "Launch Gunicorn"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "cd ${HELLOAPP_INSTALLDIR} \
                                        && sudo gunicorn -D app:app > /dev/null 2>&1"
if [ $? -ne 0 ]; then
  echoError "An error occured while trying to launch Gunicorn. Exiting."
  exit 1
fi
echoSuccess "Gunicorn successfully started."
echoInfo "Generate Nginx configuration from template"
sed "s/##SERVERNAME##/${INSTANCE_PUBLIC_DNS_NAME}/g;\
     s@##WEBROOT##@${HELLOAPP_INSTALLDIR}@g;\
     s/##GUNICORN_PORT##/${GUNICORN_PORT}/g" "${SCRIPT_DIR}/${NGINX_TEMPLATE}" > /tmp/helloapp.nginx 2> /dev/null
if [ $? -ne 0 ]; then
 echoError "Something went wrong during Nginx configuration generation. Exiting."
 exit 1
fi
echoSuccess "NGinx configuration successfully generated."
echoInfo "Send Nginx configuration to EC2 instance"
${SCP_CMD} /tmp/helloapp.nginx ${AWS_EC2_UBUNTU_LOGIN}@${INSTANCE_PUBLIC_DNS_NAME}:/tmp/helloapp
if [ $? -ne 0 ]; then
 echoError "Something went wrong during Nginx configuration SCP transfer. Exiting."
 exit 1
fi
echoSuccess "NGinx configuration successfully sent to EC2 instance."
echoInfo "Configure Nginx on EC2 instance"
${SSH_CMD} ${INSTANCE_PUBLIC_DNS_NAME} "sudo cp /tmp/helloapp ${NGINX_CONFDIR}/sites-available \
                                        && sudo rm -f ${NGINX_CONFDIR}/sites-enabled/* \
                                        && sudo ln -s ${NGINX_CONFDIR}/sites-available/helloapp ${NGINX_CONFDIR}/sites-enabled/helloapp \
                                        && sudo service nginx restart > /dev/null 2>&1"
if [ $? -ne 0 ]; then
 echoError "Something went wrong during Nginx configuration. Exiting."
 exit 1
fi
echoSuccess "NGinx successfully configured."
echoStep "HelloApp deployment successfully finished, it is available at http://${INSTANCE_PUBLIC_DNS_NAME}"

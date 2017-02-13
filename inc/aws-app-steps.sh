#!/bin/bash

manageKeypair() {
  local _KEY_PAIR_NAME=$1

  echoStep "Manage SSH key pair"
  checkKeypair ${_KEY_PAIR_NAME}
  if [ $? -ne 0 ]; then
    echoWarning "${_KEY_PAIR_NAME} key pair does not exist. We are going to create it."
    createAndInstallKeypair ${_KEY_PAIR_NAME}
    if [ $? -ne 0 ]; then
      echoError "Could not create and install new key pair. Exiting."
      cleanupAndExit 1
    fi
  else
    echoSuccess "${_KEY_PAIR_NAME} key pair already exists."
    if [ ! -f ~/.ssh/${_KEY_PAIR_NAME}.pem ]; then
      echoWarning "Private key file does not exist locally. We are going to recreate key pair."
      deleteKeypair ${_KEY_PAIR_NAME}
      if [ $? -ne 0 ]; then
        echoError "Could not delete existing key pair. Exiting."
        cleanupAndExit 1
      fi
      createAndInstallKeypair ${_KEY_PAIR_NAME}
      if [ $? -ne 0 ]; then
        echoError "Could not create and install new key pair. Exiting."
        cleanupAndExit 1
      fi
    fi
  fi
}

manageSecGrp() {
  local _SECGRP_NAME=$1
  local _SECGRP_DESC="$2"

  echoStep "Manage security group"
  local _CREATE_RULES=0
  checkSecGrp ${_SECGRP_NAME}
  if [ $? -ne 0 ]; then
    echoWarning "${_SECGRP_NAME} security group does not exist. We are going to create it."
    createSecGrp ${_SECGRP_NAME} "${_SECGRP_DESC}"
    if [ $? -ne 0 ]; then
      echoError "Could not create security group. Exiting."
      cleanupAndExit 1
    fi
    _CREATE_RULES=1
  else
    echoSuccess "${_SECGRP_NAME} security group already exists. Will check rules to be sure they exist."
    _CREATE_RULES=1
  fi

  if [ $_CREATE_RULES -eq 1 ]; then
    for i in "${SECGRP_RULES_PORT[@]}"
    do
    	createSecGrpRule ${_SECGRP_NAME} ${i}
      if [ $? -ne 0 ]; then
        echoError "Could not create inbound rule for port ${i}. Exiting."
        cleanupAndExit 1
      fi
    done
  fi
}

manageInstance() {
  local _EC2_AMI_ID=$1
  local _EC2_INSTANCE_TYPE=$2
  local _KEY_PAIR_NAME=$3
  local _SECGRP_NAME=$4
  local _TAG_NAME=$5
  local _TAG_VALUE=$6
  local _SSH_CMD="$7"

  if [ -f ./instance.id ]; then
    rm -f ./instance.id
  fi

  echoStep "Create EC2 instance"
  checkInstance ${_TAG_NAME} ${_TAG_VALUE}
  if [ $? -eq 0 ]; then
    echoInfo "EC2 instance already exists. We are going to try to ssh it."
    local _INSTANCE_ID=$(getInstanceId ${_TAG_NAME} ${_TAG_VALUE})
    if [ $? -ne 0 ]; then
      echoError "Could not get EC2 instance ID"
      cleanupAndExit 1
    fi
    local _INSTANCE_PUBLIC_DNS_NAME=$(getInstancePublicDnsName ${_INSTANCE_ID})
    if [ $? -ne 0 ]; then
      echoError "Could not get EC2 instance public DNS name"
      cleanupAndExit 1
    fi
    echoInfo "Existing EC2 instance public DNS name: ${_INSTANCE_PUBLIC_DNS_NAME}"
    ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} exit
    if [ $? -ne 0 ]; then
      echoWarning "Could not ssh EC2 instance. We are going to delete and recreate it."
      deleteInstance ${_INSTANCE_ID}
      if [ $? -ne 0 ]; then
        echoError "Could not terminate existing instance. Exiting."
        cleanupAndExit 1
      fi
      echoSuccess "EC2 instance successfully deleted."
      echoInfo "Create new EC2 instance."
      createAndTagInstance ${_EC2_AMI_ID} ${_EC2_INSTANCE_TYPE} ${_KEY_PAIR_NAME} ${_SECGRP_NAME} ${_TAG_NAME} ${_TAG_VALUE}
    else
      echo $_INSTANCE_ID > ./instance.id
      echoSuccess "SSH connection to EC2 instance successfully acheived."
    fi
  else
    echoWarning "EC2 instance not found, we are going to create it."
    createAndTagInstance ${_EC2_AMI_ID} ${_EC2_INSTANCE_TYPE} ${_KEY_PAIR_NAME} ${_SECGRP_NAME} ${_TAG_NAME} ${_TAG_VALUE}
  fi
}

createAndTagInstance() {
  local _EC2_AMI_ID=$1
  local _EC2_INSTANCE_TYPE=$2
  local _KEY_PAIR_NAME=$3
  local _SECGRP_NAME=$4
  local _TAG_NAME=$5
  local _TAG_VALUE=$6

  local _INSTANCE_ID=$(createAndRunInstance ${_EC2_AMI_ID} ${_EC2_INSTANCE_TYPE} ${_KEY_PAIR_NAME} ${_SECGRP_NAME})
  if [ $? -ne 0 ]; then
    echoError "Could not create and run new EC2 instance. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "EC2 instance successfully created and launched."
  echo $_INSTANCE_ID > ./instance.id
  echoStep "Wait some time so as to let EC2 instance start..."
  sleep 5
  echoInfo "Create tag for new instance"
  tagInstance ${_INSTANCE_ID} ${_TAG_NAME} ${_TAG_VALUE}
  if [ $? -ne 0 ]; then
    echoError "Could not create tag EC2 instance. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "EC2 instance successfully tagged."
}

setupAndDeployApp() {
  local _INSTANCE_PUBLIC_DNS_NAME=$1
  local _APP_BRANCH_OR_TAG=$2
  local _APP_URL=$3
  local _APP_INSTALLDIR=$4
  local _INSTANCE_LOGIN=$5
  local _REQUIRED_PKGS="$6"
  local _NGING_TPL="$7"
  local _GUNICORN_PORT=$8
  local _NGINX_CONFDIR=$9
  local _SSH_CMD="${10}"
  local _SCP_CMD="${11}"

  echoStep "Configure instance and install app"
  echoInfo "Update available packages list"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "sudo apt-get update -q  > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
    echoError "Unable to update packages list. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "Packages list successfully updated."
  echoInfo "Install required packages on instance (${_REQUIRED_PKGS})"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "sudo apt-get install -yq ${_REQUIRED_PKGS} > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
    echoError "Something went wrong during packages installation. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "Required packages successfully installed."
  echoInfo "Get HelloApp code (branch or tag = ${_APP_BRANCH_OR_TAG})"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "sudo rm -rf ${_APP_INSTALLDIR} 2> /dev/null; \
                                          sudo mkdir -p ${_APP_INSTALLDIR} \
                                          && sudo chown ${_INSTANCE_LOGIN} ${_APP_INSTALLDIR} \
                                          && cd ${_APP_INSTALLDIR} \
                                          && git clone --branch ${_APP_BRANCH_OR_TAG} --depth 1 ${_APP_URL} . > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
    echoError "Something went wrong during Hello App source code installation. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "Hello App source code successfully downloaded."
  echoInfo "Install HelloApp Python requirements"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "cd ${_APP_INSTALLDIR} \
                                            && sudo pip install -r requirements.txt > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
    echoError "Something went wrong during Hello App Python requirements installation. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "Hello App source Python requirements successfully installed."
  echoInfo "Launch Gunicorn"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "sudo killall -q gunicorn ; \
                                            cd ${_APP_INSTALLDIR} \
                                            && sudo gunicorn -b 127.0.0.1:${_GUNICORN_PORT} -D app:app > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
    echoError "An error occured while trying to launch Gunicorn. Exiting."
    cleanupAndExit 1
  fi
  echoSuccess "Gunicorn successfully started."
  echoInfo "Generate Nginx configuration from template"
  sed "s/##SERVERNAME##/${_INSTANCE_PUBLIC_DNS_NAME}/g;\
       s@##WEBROOT##@${_APP_INSTALLDIR}@g;\
       s/##GUNICORN_PORT##/${_GUNICORN_PORT}/g" "${_NGING_TPL}" > /tmp/helloapp.nginx 2> /dev/null
  if [ $? -ne 0 ]; then
   echoError "Something went wrong during Nginx configuration generation. Exiting."
   cleanupAndExit 1
  fi
  echoSuccess "NGinx configuration successfully generated."
  echoInfo "Send Nginx configuration to EC2 instance"
  ${_SCP_CMD} /tmp/helloapp.nginx ${_INSTANCE_LOGIN}@${_INSTANCE_PUBLIC_DNS_NAME}:/tmp/helloapp
  if [ $? -ne 0 ]; then
   echoError "Something went wrong during Nginx configuration SCP transfer. Exiting."
   cleanupAndExit 1
  fi
  rm -f /tmp/helloapp.nginx
  echoSuccess "NGinx configuration successfully sent to EC2 instance."
  echoInfo "Configure Nginx on EC2 instance"
  ${_SSH_CMD} ${_INSTANCE_PUBLIC_DNS_NAME} "sudo cp /tmp/helloapp ${_NGINX_CONFDIR}/sites-available \
                                          && sudo rm -f ${_NGINX_CONFDIR}/sites-enabled/* \
                                          && sudo ln -s ${_NGINX_CONFDIR}/sites-available/helloapp ${_NGINX_CONFDIR}/sites-enabled/helloapp \
                                          && sudo service nginx restart > /dev/null 2>&1"
  if [ $? -ne 0 ]; then
   echoError "Something went wrong during Nginx configuration. Exiting."
   cleanupAndExit 1
  fi
  echoSuccess "NGinx successfully configured."
  echoStep "HelloApp deployment successfully finished, it is available at http://${_INSTANCE_PUBLIC_DNS_NAME}"
}

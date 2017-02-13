#!/bin/bash

AWS_CLI_OUTPUT=json
AWS_CLI_REGION=us-west-1
AWS_CLI_EC2_CMD="aws --output ${AWS_CLI_OUTPUT} --region ${AWS_CLI_REGION} ec2"

# Key pair management
checkKeypair() {
  local _KEYPAIR_NAME=$1

  ${AWS_CLI_EC2_CMD} describe-key-pairs --key-names ${_KEYPAIR_NAME} > /dev/null 2>&1
}
export -f checkKeypair

deleteKeypair() {
  local _KEYPAIR_NAME=$1

  ${AWS_CLI_EC2_CMD} delete-key-pair --key-name ${_KEYPAIR_NAME} > /dev/null 2>&1
}
export -f deleteKeypair

createAndInstallKeypair() {
  local _KEYPAIR_NAME=$1

  ${AWS_CLI_EC2_CMD} create-key-pair --key-name ${_KEYPAIR_NAME} > /tmp/keypair.out 2>&1
  if [ $? -ne 0 ]; then
    rm -f /tmp/keypair.out
    return 1
  else
    echo /tmp/keypair.out | python -c "import sys, json; print json.load(sys.stdin)['KeyMaterial']" > ~/.ssh/${_KEYPAIR_NAME}.pem
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    chmod 400 ~/.ssh/${_KEYPAIR_NAME}.pem
    rm -f /tmp/keypair.out
    return 0
  fi
}
export -f createAndInstallKeypair

# Security group management
checkSecGrp() {
  local _SECGRP_NAME=$1

  ${AWS_CLI_EC2_CMD} describe-security-groups --group-names ${_SECGRP_NAME} > /dev/null 2>&1
}
export -f checkSecGrp

createSecGrp() {
  local _SECGRP_NAME=$1
  local _SECGRP_DESC=$2

  ${AWS_CLI_EC2_CMD} create-security-group --group-name ${_SECGRP_NAME} --description "${_SECGRP_DESC}" > /dev/null 2>&1
}
export -f createSecGrp

createSecGrpRule() {
  local _SECGRP_NAME=$1
  local _SECGRP_RULE_PORT=$2

  ${AWS_CLI_EC2_CMD} authorize-security-group-ingress --group-name ${_SECGRP_NAME} --protocol tcp --port ${_SECGRP_RULE_PORT} --cidr 0.0.0.0/0 > /dev/null 2> /tmp/secgroup_rule.err

  if [ $? -ne 0 ]; then
    if [ $(grep -c "InvalidPermission.Duplicate" /tmp/secgroup_rule.err) -gt 0 ]; then
      return 0
    fi
    return 1
  fi
  return 0
}
export -f createSecGrpRule

# Instances management
checkInstance() {
  local _TAG_NAME=$1
  local _TAG_VALUE=$2

  local _INSTANCES_COUNT=$(${AWS_CLI_EC2_CMD} describe-instances --filters "Name=tag:${_TAG_NAME},Values=${_TAG_VALUE}" "Name=instance-state-code,Values=16" | python -c "import sys, json; print len(json.load(sys.stdin)['Reservations'])")

  if [ $_INSTANCES_COUNT -gt 0 ]; then
    return 0
  fi

  return 1
}
export -f checkInstance

getInstanceId() {
  local _TAG_NAME=$1
  local _TAG_VALUE=$2

  local _INSTANCE_ID=$(${AWS_CLI_EC2_CMD} describe-instances --filters "Name=tag:${_TAG_NAME},Values=${_TAG_VALUE}" "Name=instance-state-code,Values=16" | python -c "import sys, json; print json.load(sys.stdin)['Reservations'][0]['Instances'][0]['InstanceId']")
  echo ${_INSTANCE_ID}
}
export -f getInstanceId

deleteInstance() {
  local _INSTANCE_ID=$1

  ${AWS_CLI_EC2_CMD} terminate-instances --instance-ids ${_INSTANCE_ID} > /dev/null 2>&1
}
export -f deleteInstance

createAndRunInstance() {
  local _AMI_IMAGE_ID=$1
  local _INSTANCE_TYPE=$2
  local _KEYPAIR_NAME=$3
  local _SECGRP_NAME=$4

  ${AWS_CLI_EC2_CMD} run-instances --image-id ${_AMI_IMAGE_ID} --count 1 --instance-type ${_INSTANCE_TYPE} --key-name ${_KEYPAIR_NAME} --security-groups ${_SECGRP_NAME} > /tmp/instance.out 2>&1

  if [ $? -ne 0 ]; then
    return 1
  else
    local _INSTANCE_ID=$(cat /tmp/instance.out | python -c "import sys, json; print json.load(sys.stdin)['Instances'][0]['InstanceId']")
    echo ${_INSTANCE_ID}
    return 0
  fi
}
export -f createAndRunInstance

getInstancePublicDnsName() {
  local _INSTANCE_ID=$1

  local _PUBLIC_DNS_NAME=$(${AWS_CLI_EC2_CMD} describe-instances --instance-ids ${_INSTANCE_ID} | python -c "import sys, json; print json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PublicDnsName']")
  echo ${_PUBLIC_DNS_NAME}
}
export -f getInstancePublicDnsName

tagInstance() {
  local _INSTANCE_ID=$1
  local _TAG_NAME=$2
  local _TAG_VALUE=$3

  ${AWS_CLI_EC2_CMD} create-tags --resources ${_INSTANCE_ID} --tags Key=${_TAG_NAME},Value=${_TAG_VALUE} > /dev/null 2>&1
}
export -f tagInstance

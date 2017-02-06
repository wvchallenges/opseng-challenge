#!/usr/bin/env bash

# aws-app.sh

# Requirements:
#  - awscli >= 1.11.44
#  - docker

# This scripts is broken up into three stages:
# - Infrastructue
# - Application Build
# - Application Deployment
# decided to not use ansible or terraform to keep dependencies minimal
# and to make most use of awscli
# made a dependency on docker so as to use ECS
# decided not to use a CI service in order to keep things simple
# the idea is that this repo manages the complete lifecycle of infrastructure management, app build
# and deploy
# there is minimal coupling between this repo and the opseng-challenge-app repo. ideally the Dockerfile would live with the
# application code but since that wasn't an option it is in this repo.
# user does not have to do anything other than run aws-app.sh. the only option added was "--destroy" which
# will destroy all of the AWS infra that is created by this script
# deploy works by comparing sha of HEAD to docker label in service's active task definition
# Improvements:
# - DNS name
# - https instead of http
# - Dockerfile should live in app repo
# used git sha's as in this scenerio I do not have access to the app repo. using git tags would be better

# To do:
#  - add docker reg to cfn
#  - add ECS cluster to cfn
#  - auto create first task definition and service

set -eu
#set -x

# global vars
USAGE="\nUsage:$0 [--destroy|-d]\n"
CFN_STACK_NAME="mschurenko-VPC"
#GIT_REPO="https://github.com/wvchallenges/opseng-challenge-app.git"
GIT_REPO="https://github.com/mschurenko/opseng-challenge-app.git"
REPO_DIR="opseng-challenge-app"
APP_NAME="opseng-challenge-app"
ALB_NAME="mschurenko-alb"
#ALB_TARGET_GROUP="arn:aws:elasticloadbalancing:us-east-1:505545132866:targetgroup/ecs-mschur-myapp/7803dbaee8ffa693"
ALB_TARGET_GROUP="arn:aws:elasticloadbalancing:us-east-1:505545132866:targetgroup/mschurnenko-ecs-service/2c2ac7d975a213fc"
ECS_CLUSTER="mschurenko-cluster"
ECS_SERVICE="mschurenko-servicev2"
ECS_DESIRED_COUNT=1
ECS_TASK_FAMILY="mschurenko-task"
ECS_CONTAINER_PORT=8000
IAM_ROLE="arn:aws:iam::505545132866:role/ecsServiceRole"

export AWS_DEFAULT_OUTPUT=text

## Functions ##
b_print() {
    local msg="$1"
    echo -e "\e[96m${msg}\e[0m"
}

g_print() {
    echo -e "\e[92mUnchanged\e[0m"
}

y_print() {
    echo -e "\e[93mChanged\e[0m"
}

r_print() {
    echo -e "\e[91mFailed\e[0m"
}

p_stage() {
    local msg="$1"
    echo -e "\e[4;100mStage: $msg\e[0m"
}

sanity_checks() {
    set +u
    if [[ -z $AWS_DEFAULT_REGION ]] || [[ -z $AWS_ACCESS_KEY_ID ]] || \
       [[ -z $AWS_SECRET_ACCESS_KEY ]];then
        echo "The follwing environmet vars must be set:"
        echo "AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        exit 2
    fi

    if ! which docker &>/dev/null;then
        echo 'docker not found in $PATH'
        echo "This is needed in order to build and deploy $REPO_DIR"
        echo "Exiting."
        exit 3
    fi
    set -u
}

get_stack_status() {
    local CFN_STACK_NAME=$1
    aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME 2>/dev/null\
    |awk '/^STACKS/ {print $NF}'
}

create_infra() {
    echo "Creating Infrastructure..."
}

destroy_infra() {
    echo "Destroying infrastructure..."
    exit
}
#-------
# main
#-------
sanity_checks

if [[ -n $@ ]];then
    case $@ in
        --destroy|-d)
            read -p "Are you sure you want to destroy? Enter 'yes' if sure: " \
            confirm
            if [[ $confirm == "yes" ]];then
                destroy_infra
            else
                echo "Skipping destroy of infrastructure.";exit
            fi
        ;;
        --help|-h) echo -e "$USAGE";exit;;
        *) echo -e "$USAGE";exit 1
        ;;
    esac
fi

BASE_DIR=$(pwd)

#----------------------
# Infrastructure Stage
#----------------------
p_stage "Infrastructure"

stack_status=$(get_stack_status $CFN_STACK_NAME)

echo "Checking if we need to build infrastructure..."

cd infra
if [[ $stack_status =~ _COMPLETE$ ]];then
    aws cloudformation validate-template --template-body file://./vpc.yaml
    aws cloudformation update-stack \
    --template-body file://./vpc.yaml \
    --stack-name $CFN_STACK_NAME \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=ECSCluserName,ParameterValue=${ECS_CLUSTER} \
    --tags Key=Name,Value=$CFN_STACK_NAME
    echo "Waiting for stack update on $CFN_STACK_NAME to complete..."
    aws cloudformation wait stack-update-complete --stack-name $CFN_STACK_NAME
else
    echo "$CFN_STACK_NAME not in a state where it can be updated. Status is $stack_status"
    echo "State: $(r_print)"
    exit 4
fi

exit
# aws cloudformation wait stack-exists --stack-name $CFN_STACK_NAME
# wait until cluster state is ACTIVE
# cluster_state=$(aws ecs describe-clusters --clusters mschurenko-test|awk '/^CLUSTERS/ {print $NF}')

echo "Gathering outputs from $CFN_STACK_NAME"
ecr_name=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
awk -F\t '/^OUTPUTS/ {if($3=="ECRName"){print $NF}}')
ECR_REPO=$(aws ecr describe-repositories --repository-names $ecr_name|awk '/^REPOSITORIES/ {print $NF}')

cd $BASE_DIR
#--------------
# Build Stage
#--------------
p_stage "Build"
cd build
echo "Checking if we need to build/deploy..."
if [[ ! -d $REPO_DIR ]];then
    git clone $GIT_REPO $REPO_DIR &>/dev/null
    cd $REPO_DIR
    git_sha=$(git rev-parse --short HEAD)
else
    cd $REPO_DIR
    git pull &>/dev/null
    git_sha=$(git rev-parse --short HEAD)
fi
cd ..

docker_image=${ECR_REPO}:${git_sha}
deploy=false

# compare git SHA with deployed container
set +e
service=$(aws ecs list-services --cluster $ECS_CLUSTER|grep $ECS_SERVICE)
set -e
echo "service: $service"
if [[ -n $service ]];then
    service_exists=true
    cur_task_def=$(aws ecs describe-services --service $ECS_SERVICE --cluster $ECS_CLUSTER\
    |awk '/^SERVICES/ {print $NF}')
    cur_img=$(aws ecs describe-task-definition --task-definition $cur_task_def\
    |awk '/^CONTAINERDEFINITIONS/ {print $4}')
else
    service_exists=false
    cur_img=""
    deploy=true
fi

echo "service exists: $service_exists"
echo "cur image: $cur_img"
echo "docker image: $docker_image"

if [[ -z $cur_img ]] || [[ $cur_img != $docker_image ]];then
    b_print "Building ${ECR_REPO}:${git_sha}..."
    docker build -t ${APP_NAME}:${git_sha}\
    --build-arg repo=${REPO_DIR} \
    --build-arg version=${git_sha} .
    docker tag ${APP_NAME}:${git_sha} $docker_image
    $(aws ecr get-login)
    docker push $docker_image
    cd $BASE_DIR
    echo "Status: $(y_print)"
    deploy=true
else
    echo "Status: $(g_print)"
fi

#--------------
# Deploy Stage
#--------------
p_stage "Deploy"
if [[ $deploy == "true" ]];then
    b_print "Deploying $docker_image"
    cd deploy
    temp_json=${$}_tmp.json
    # creating a task def is idempotent
    ${BASE_DIR}/utils/set-task-def.py $ECS_TASK_FAMILY $APP_NAME $docker_image \
    < task-def-skel.json > $temp_json
    task_def=$(aws ecs register-task-definition --cli-input-json file://./${temp_json}\
    |awk '/^TASKDEFINITION/ {print $NF}')
    command rm $temp_json

    if [[ $service_exists == "true" ]];then
        aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --task-definition $task_def|grep ^DEPLOYMENTS
    else
        aws ecs create-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --task-definition $task_def \
        --desired-count $ECS_DESIRED_COUNT \
        --load-balancers \
        containerName=${APP_NAME},containerPort=${ECS_CONTAINER_PORT},targetGroupArn=${ALB_TARGET_GROUP} \
        --role $IAM_ROLE
    fi
    # wait for service to be healthy
    g_print "$docker_image has been deployed to $ECS_SERVICE"
else
    echo "Status: $(g_print)"
fi

echo "URL is http://"

#!/usr/bin/env bash

set -eu
#set -x

AWS_CMD="aws --output text"
GIT_REPO="https://github.com/wvchallenges/opseng-challenge-app.git"
REPO_DIR="opseng-challenge-app"
DOCKER_REG="505545132866.dkr.ecr.us-east-1.amazonaws.com/mschurenko-challenge-app"
APP_NAME="opseng-challenge-app"
VER=99
IMAGE_NAME=${APP_NAME}:${VER}
REPO_IMAGE_NAME=${DOCKER_REG}:${VER}

## functions

get_stack_status() {
    if [[ $# -ne 1 ]];then
        echo "ERROR: ${FUNCNAME[0]}() takes one argument"
        exit 1
    fi
    local stack_name=$1
    $AWS_CMD cloudformation describe-stacks --stack-name $stack_name 2>/dev/null\
    |awk '/^STACKS/ {print $NF}'
}

CWD=$(pwd)

# create cfn stacks
cd cfn
stack_name="mschurenko-VPC"
stack_status=$(get_stack_status $stack_name)

echo $stack_status

# if [[ $stack_status == "CREATE_COMPLETE" ]] || [[ $stack_status == "UPDATE_COMPLETE" ]];then
#     AWS_CMD cloudformation validate-template --template-body file://./vpc.yaml
#     AWS_CMD cloudformation update-stack \
#     --template-body file://./vpc.yaml \
#     --stack-name "${name}-VPC" \
#     --capabilities CAPABILITY_IAM \
#     --tags Key=Name,Value=${name}
# else
#     echo "$stack_name already exists"
# fi

cd $CWD
# build
build_image=false
if [[ ! -d opseng-challenge-app ]];then
    git clone $GIT_REPO $REPO_DIR
    build_image=true
else
    (cd $REPO_DIR && git pull)
    # compare git SHA with deployed container
fi

deploy_image=false
if [[ build_image ]];then
    docker build -t $IMAGE_NAME \
    --build-arg repo=${REPO_DIR} \
    --build-arg version=${VER} .
    docker tag $IMAGE_NAME $REPO_IMAGE_NAME
    $(aws ecr get-login)
    docker push $REPO_IMAGE_NAME
    deploy_image=true
fi

cd $CWD
# deploy

if [[ deploy_image ]];then
    cd ecs
    task_def=$($AWS_CMD --output text ecs register-task-definition --cli-input-json \
    file://./task-definition.json|awk '/^TASKDEFINITION/ {print $NF}')
    echo $task_def
    $AWS_CMD ecs update-service --cluster mschurenko-test --service myapp \
    --task-definition $task_def|grep ^DEPLOYMENTS
fi
#cd ecs
# create task definition
# create service
#task_def=$($AWS_CMD --output text ecs register-task-definition --cli-input-json \
#file://./task-definition.json|awk '/^TASKDEFINITION/ {print $NF}')
#echo $task_def
#$AWS_CMD ecs update-service --cluster mschurenko-test --service myapp \
#--task-definition $task_def|grep ^DEPLOYMENTS

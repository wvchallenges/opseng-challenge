#!/usr/bin/env bash

# aws-app.sh

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

set -eu
#set -x

# global vars
USAGE="\nUsage:$0 [--destroy|-d]\n"
#GIT_REPO="https://github.com/wvchallenges/opseng-challenge-app.git"
GIT_REPO="https://github.com/mschurenko/opseng-challenge-app.git"
REPO_DIR="opseng-challenge-app"
DOCKER_REG="505545132866.dkr.ecr.us-east-1.amazonaws.com/mschurenko-challenge-app"
APP_NAME="opseng-challenge-app"
ECS_SERVICE="myapp"
ECS_CLUSTER="mschurenko-test"

export AWS_DEFAULT_OUTPUT=text

## Functions ##
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
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name $stack_name 2>/dev/null\
    |awk '/^STACKS/ {print $NF}'
}

create_infra() {
    echo "Creating Infrastructure..."
}

destroy_infra() {
    echo "Destroying infrastructure..."
    exit
}

# main #
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
        --help|-h) echo -e $USAGE;exit;;
        *) echo -e $USAGE;exit 1
        ;;
    esac
fi

BASE_DIR=$(pwd)

## Stages ##

### Infrastructure ###
cd cfn
stack_name="mschurenko-VPC"
stack_status=$(get_stack_status $stack_name)

echo $stack_status

# if [[ $stack_status == "CREATE_COMPLETE" ]] || [[ $stack_status == "UPDATE_COMPLETE" ]];then
#     aws cloudformation validate-template --template-body file://./vpc.yaml
#     aws cloudformation update-stack \ #     --template-body file://./vpc.yaml \
#     --stack-name "${name}-VPC" \
#     --capabilities CAPABILITY_IAM \
#     --tags Key=Name,Value=${name}
# else
#     echo "$stack_name already exists"
# fi
# aws cloudformation wait stack-exists --stack-name $stack_name
# wait until cluster state is ACTIVE
# cluster_state=$(aws ecs describe-clusters --clusters mschurenko-test|awk '/^CLUSTERS/ {print $NF}')

cd $BASE_DIR

### Application Build ###
if [[ ! -d $REPO_DIR ]];then
    git clone $GIT_REPO $REPO_DIR
    build_image=true
    git_sha=$(git rev-parse --short HEAD)
else
    cd $REPO_DIR
    git pull
    git_sha=$(git rev-parse --short HEAD)
fi

echo "git sha: $git_sha"

# compare git SHA with deployed container
cur_task_def=$(aws ecs describe-services --service $ECS_SERVICE --cluster $ECS_CLUSTER\
|awk '/^SERVICES/ {print $NF}')
echo "Current task def: $cur_task_def"
docker_label=$(aws ecs describe-task-definition --task-definition $cur_task_def\
|awk '/^DOCKERLABELS/ {print $2}')
echo "Current docker label: $docker_label"

cd $BASE_DIR
if [[ $docker_label != $git_sha ]];then
    echo "$docker_label and $git_sha don't match"
    ## Build Applicaiton ##
    docker build -t ${APP_NAME}:${git_sha}\
    --build-arg repo=${REPO_DIR} \
    --build-arg version=${git_sha} .
    docker tag ${APP_NAME}:${git_sha} ${DOCKER_REG}:${git_sha}
    $(aws ecr get-login)
    docker push ${DOCKER_REG}:${git_sha}
    cd $BASE_DIR

    ## Deploy Appication ##
    cd ecs
    # set name, image and dockerlabel
    temp_json=${$}_tmp.json
    ../utils/set-task-def.py test ${DOCKER_REG}:${git_sha} $git_sha < task-definition.json > $temp_json
    task_def=$(aws ecs register-task-definition --cli-input-json file://./${temp_json}\
    |awk '/^TASKDEFINITION/ {print $NF}')
    command rm $temp_json

    echo "New task def: $task_def"

    echo "Updating Service $ECS_SERVICE"
    aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE \
    --task-definition $task_def|grep ^DEPLOYMENTS
    # wait for service to be healthy
else
    echo "ECS is up-to-date with $REPO_DIR"
fi
#cd ecs
# create task definition
# create service
#task_def=$(aws --output text ecs register-task-definition --cli-input-json \
#file://./task-definition.json|awk '/^TASKDEFINITION/ {print $NF}')
#echo $task_def
#aws ecs update-service --cluster mschurenko-test --service myapp \
#--task-definition $task_def|grep ^DEPLOYMENTS

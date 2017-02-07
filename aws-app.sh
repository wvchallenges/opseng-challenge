#!/usr/bin/env bash

set -eu

## global vars ##
USAGE="\nUsage:$0 [--destroy|-d]\n"
CLI_MIN_VER="1.11.44"
CFN_STACK_NAME="mschurenko-ecs-infra"
GIT_REPO="https://github.com/wvchallenges/opseng-challenge-app.git"
APP_NAME="opseng-challenge-app"
ALB_NAME="mschurenko-alb"
ECS_CLUSTER="mschurenko-cluster"
ECS_SERVICE="mschurenko-service"
ECS_DESIRED_COUNT=1
ECS_TASK_FAMILY="mschurenko-task"
ECS_CONTAINER_PORT=8000

export AWS_DEFAULT_OUTPUT=text

## Functions ##
bold_print() {
    local msg="$1"
    echo "    >- ${msg}"
}

stage_print() {
    local msg="$1"
    echo "|-- ${msg} Stage --|"
}

check_path() {
    local cmd="$1"
    if ! which docker &>/dev/null;then
        echo "$cmd not found in \$PATH"
        echo "This is needed in order to build and deploy $APP_NAME"
        echo "Exiting."
        exit 3
    fi
}

sanity_checks() {
    set +u
    if [[ -z $AWS_DEFAULT_REGION ]] || [[ -z $AWS_ACCESS_KEY_ID ]] || \
       [[ -z $AWS_SECRET_ACCESS_KEY ]];then
        echo "The follwing environmet vars must be set:"
        echo "AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        exit 2
    fi

    check_path docker

    check_path aws
    # check awscli version
    cli_ver=($(aws --version 2>&1|awk -F/ '{print $2}'|awk '{print $1}'|awk -F. '{print $1, $2, $3}'))
    cli_min_ver_a=($(echo $CLI_MIN_VER|awk -F. '{print $1, $2, $3}'))
    for n in $(seq 0 $(( ${#cli_ver[@]} - 1 )));do
        if [[ ${cli_ver[n]} < ${cli_min_ver_a[n]} ]];then
            echo "awscli is too old. >= $CLI_MIN_VER is required. Exiting"
            exit 6
        fi
    done
}

get_stack_status() {
    local cfn_stack_name=$1
    aws cloudformation describe-stacks --stack-name $cfn_stack_name 2>/dev/null\
    |awk '/^STACKS/ {print $NF}'
}

get_cfn_outputs() {
    bold_print "Gathering outputs from $CFN_STACK_NAME"
    ECR_NAME=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
    awk -F\t '/^OUTPUTS/ {if($2=="ECRName"){print $NF}}')
    ECR_REPO=$(aws ecr describe-repositories --repository-names $ECR_NAME|awk '/^REPOSITORIES/ {print $NF}')

    ALB_TARGET_GROUP=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
    awk -F\t '/^OUTPUTS/ {if($2=="TargetGroup"){print $NF}}')

    ALB_DNS_NAME=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
    awk -F\t '/^OUTPUTS/ {if($2=="ALBDNSName"){print $NF}}')

    ASG_NAME=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
    awk -F\t '/^OUTPUTS/ {if($2=="EcsAsg"){print $NF}}')

    ECS_SERVICE_ROLE=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME|\
    awk -F\t '/^OUTPUTS/ {if($2=="EcsServiceRole"){print $NF}}')

    if [[ -z $ECR_REPO ]] || [[ -z $ALB_TARGET_GROUP ]] || [[ -z $ALB_DNS_NAME ]] || \
        [[ $ASG_NAME ]] || [[ -z $ECS_SERVICE_ROLE ]];then
        bold_print "Could not gather all outputs from $CFN_STACK_NAME"
        exit 5
    fi
}

destroy_all() {
    bold_print "Destroying everything..."
    get_cfn_outputs

    bold_print "Deleting ${ECR_NAME}..."
    aws ecr delete-repository --repository-name $ECR_NAME --force

    bold_print "Deleting ${ECS_SERVICE}..."
    aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count 0 >/dev/null
    aws ecs delete-service --cluster $ECS_CLUSTER --service $ECS_SERVICE >/dev/null

    bold_print "Degreistering container instances from ${ECS_CLUSTER}..."
    for arn in $(aws ecs list-container-instances --cluster $ECS_CLUSTER\
    |awk '/^CONTAINERINSTANCEARNS/ {print $2}');do
        aws ecs deregister-container-instance --force --cluster $ECS_CLUSTER --container-instance "$arn" >/dev/null
    done

    bold_print "Destroying ${CFN_STACK_NAME}..."
    aws cloudformation delete-stack --stack-name $CFN_STACK_NAME
    aws cloudformation wait stack-delete-complete --stack-name $CFN_STACK_NAME
    bold_print "Destruction complete"
}

## main ##
sanity_checks

if [[ -n $@ ]];then
    case $@ in
        --destroy|-d)
            read -p "Are you sure you want to destroy? Enter 'yes' if sure: " \
            confirm
            if [[ $confirm == "yes" ]];then
                destroy_all
                exit
            else
                echo "Skipping destroy of infrastructure."
                exit
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
stage_print "Infrastructure"

stack_status=$(get_stack_status $CFN_STACK_NAME)

bold_print "Checking if we need to build infrastructure..."

cd infra
# check if stack exists
set +e
cur_stack=$(aws cloudformation describe-stacks --stack-name $CFN_STACK_NAME 2>/dev/null)
set -e

if [[ -z $cur_stack ]];then
    bold_print "Stack $CFN_STACK_NAME doesn't exist. Creating..."
    bold_print "Using first two availbility zones in $AWS_DEFAULT_REGION"
    azs=($(aws ec2 describe-availability-zones|awk '/^AVAILABILITYZONES/ {if($3 == "available"){print $4}}'))
    aws cloudformation validate-template --template-body file://./ecs.yaml >/dev/null
    aws cloudformation create-stack \
    --template-body file://./ecs.yaml \
    --stack-name $CFN_STACK_NAME \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=ECSClusterName,ParameterValue=${ECS_CLUSTER} \
    ParameterKey=ECRName,ParameterValue=mschurenko-${APP_NAME} \
    ParameterKey=TargetGroupName,ParameterValue=${ECS_SERVICE} \
    ParameterKey=Az1,ParameterValue=${azs[0]} \
    ParameterKey=Az2,ParameterValue=${azs[1]} \
    --tags Key=Name,Value=$CFN_STACK_NAME
    bold_print "Waiting for stack $CFN_STACK_NAME to complete..."
    aws cloudformation wait stack-create-complete --stack-name $CFN_STACK_NAME
    # should we wait until cluster state is ACTIVE?
    # cluster_state=$(aws ecs describe-clusters --clusters $ECS_CLUSTER|awk '/^CLUSTERS/ {print $NF}')
else
   cur_stack_state=$(echo "$cur_stack"|awk -F\t '/^STACKS/ {print $7}')
   if [[ $cur_stack_state == "CREATE_COMPLETE" ]] || [[ "$cur_stack_state" == "UPDATE_COMPLETE" ]];then
        bold_print "$CFN_STACK_NAME stack already exists."
    else
        bold_print "$CFN_STACK_NAME stack is in state $cur_stack_state which is not healhty."
        bold_print "Exiting"
        exit 1
   fi
fi


get_cfn_outputs

cd $BASE_DIR
#--------------
# Build Stage
#--------------
stage_print "Build"
cd build
bold_print "Checking if we need to build/deploy..."
if [[ ! -d $APP_NAME ]];then
    git clone $GIT_REPO $APP_NAME &>/dev/null
    cd $APP_NAME
    git_sha=$(git rev-parse --short HEAD)
else
    cd $APP_NAME
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

if [[ -z $cur_img ]] || [[ $cur_img != $docker_image ]];then
    bold_print "Detected a change. Building ${ECR_REPO}:${git_sha}..."
    docker build -t ${APP_NAME}:${git_sha}\
    --build-arg repo=${APP_NAME} \
    --build-arg version=${git_sha} .
    docker tag ${APP_NAME}:${git_sha} $docker_image
    $(aws ecr get-login)
    docker push $docker_image
    cd $BASE_DIR
    deploy=true
else
    bold_print "Nothing to build"
fi

#--------------
# Deploy Stage
#--------------
stage_print "Deploy"
if [[ $deploy == "true" ]];then
    bold_print "Deploying $docker_image"
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
        --task-definition $task_def >/dev/null
    else
        aws ecs create-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --task-definition $task_def \
        --desired-count $ECS_DESIRED_COUNT \
        --load-balancers \
        containerName=${APP_NAME},containerPort=${ECS_CONTAINER_PORT},targetGroupArn=${ALB_TARGET_GROUP} \
        --role $ECS_SERVICE_ROLE >/dev/null
    fi
    bold_print "$docker_image has been deployed to $ECS_SERVICE"
else
    bold_print "Nothing to deploy"
fi

# wait for service to be healthy
stage_print "Check"

URL="http://${ALB_DNS_NAME}"
MAX_ATTEMPTS=30
tries=0
while :;do
    bold_print "Checking $URL for 200 OK..."
    r_status=$(curl --connect-timeout 10 -s -o /dev/null -w %{http_code} $URL)
    if [[ $r_status == 200 ]];then break;fi
    if [[ $tries -eq $MAX_ATTEMPTS ]];then
        bold_print "$URL failed to return 200 after $MAX_ATTEMPTS"
        exit
    fi
    let tries=tries+1
    sleep 10
done
bold_print "Result: $APP_NAME is running at http://${ALB_DNS_NAME}"

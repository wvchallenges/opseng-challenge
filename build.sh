#!/usr/bin/env bash

set -e

[[ $# -eq 1 ]] || exit 1

docker_reg="505545132866.dkr.ecr.us-east-1.amazonaws.com/mschurenko-challenge-app"
app_name="opseng-challenge-app"
ver=$1
image_name=${app_name}:${ver}
repo_image_name=${docker_reg}:${ver}

docker build -t $image_name --build-arg run_dir=${ver} .
docker tag $image_name $repo_image_name
$(aws ecr get-login)
docker push $repo_image_name

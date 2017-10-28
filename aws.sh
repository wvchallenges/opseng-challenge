#!/bin/sh

export TF_VAR_aws_access_key="$(pass opseng-challenge/access-key)"
export TF_VAR_aws_secret_key="$(pass opseng-challenge/secret-key)"

export AWS_ACCESS_KEY_ID="${TF_VAR_aws_access_key}"
export AWS_SECRET_ACCESS_KEY="${TF_VAR_aws_secret_key}"

export TF_date="$(date +%Y%m%d%k%M%S)"


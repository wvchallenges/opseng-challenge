#!/bin/sh

owd=`pwd`
cd packer
packer build image.json
cd ../terraform
terraform init
terraform get
terraform apply

# Bugs: no error checking.


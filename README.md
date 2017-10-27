# Overview 

This repo has two parts:

1. The packer dir. It has everything to make an AWS EC2 image that has the app "baked in". The product of this dir is an AMI.

2. the terraform dir . This is where some infrastucture gets lit up running  that app. At this time it's just a lone vpc-less intance.

I tried to keep this as simple as I could whle being functional. I also thorugh about security, usablity , and scalability

aws.sh populates your environment with your aws creds.

# Packer

There are three parts that make this up.

image.json
  the packer template
  references the two files before.

provision.sh
  a script run at ami build time that gets the app installed.
  supprting software install is in this file.

rc.local
  a start up script that ensures that the services is running as the instance comes up.
  startup options are in this file.

# Terraform

Just a lone instance at this time.

You need to make your own key pair and specify it in terraform.tfvars.

In tfvars you also need to enter the ami id of the ami created by packer above.


# Pre-requisites and Requirements

1. put your aws api keys into pass in: ( https://www.passwordstore.org/ )

pass opseng-challenge/access-key
pass opseng-challenge/secret-key

2. packer from hashicorp ( https://www.packer.io/ )

3. terraform from hashicorp ( https://www.terraform.io/ )

# To Do

Security
Auto Scaling
Try making this a docker image and using AWS ECS.

# Bugs

A temporary ssh key was committed to the repo and has since been removed form the repo and the cloud itself.

The terraform data lookup for the ami will choose the latest image, you might want more granular control.

Deployment process. There is no elegant way to get a new version deployed.
  At this time the process would be:
    1. rerun packer to make a new image.
    2. rerun terraform for it to see the more recent ami.



# Wave Operations Engineering Development Challenge

## Requirements
- awscli >= 1.11.44 (required to register an ALB Target Group with an ECS Service)
- Docker (both the binary as well as a running daemon)

## Explanation
In order to minimize dependences I decided to do everything with bash, the awscli and Docker.

### Stages
`aws-app.sh` is broken up into four stages:

#### Infrastructure
The first time `aws-app.sh` is run it will create a CloudFormation stack. This creates a VPC as well as all the components of an ECS Cluster.

#### Build
 During the build stage `aws-app.sh` finds the SHA of opseng-challenge-app master. It then uses this to check if a docker image has been deployed that contains the same SHA. If this is not the case then a new docker image is built and uploaded to ECR.

Note: it would have been preferable to use git tags rather than a SHA; however for this exercise I treated the application repo as though it were out of my control. It also would be preferable to have the Dockerfile live in the opseng-challenge-app repo.

#### Deploy
The application is deployed as an ECS task definition. It is then assoicated with an ECS service which uses the new Applicaton Load Balancer (ALB). ALB was choosen as it supports running multiple contaners of the same type on a single container instance (this was not possible with ELB due to how port mappings worked.) As a new version of a task definition is created the ECS service handles spawning tasks and adding/removing them from the ALB Target Group. A deploy is sucessfull if it passes the health check of the ALB. Because of this there can be up to two different versions of a task running concurrently. This is because ECS waits for ALB connection draining to finish before descheduling a task.

#### Check
This checks that the ALB returns an HTTP 200 OK. (Note this doesn't check for a specfic version)

## Possible Improvements (there's surely a lot more than these)
- A CNAME for the DNS ALB A record
- HTTPS instead of HTTP for the ALB
- Tests (unit/integration) for opseng-challenge-app build and `aws-app.sh`
- Decoupling `aws-app.sh` from opseng-challenge-app so that it can be used for multple projects
- A CI server or service would be better to do the application build
- Using a KeyPair for the container instances might be a good idea (currently there is no way of ssh'ing in if you need to)
- More sanity checks in `aws-app.sh` (probably better to turn this into a python script and package)
- Use private subnets(s) for the ECS container instances
- Try to put cfn stack back if it differs from template (probably better to use Terraform for this)

## Instructions

### Start/Deploy latest HEAD
```
$ git clone https://github.com/mschurenko/opseng-challenge.git
$ cd opseng-challenge
$ ./aws-app.sh
```

### Clean Up
```
$ ./aws-app.sh --destroy
```

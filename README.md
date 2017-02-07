# Wave Operations Engineering Development Challenge

## Requirements
- awscli >= 1.11.44 (required to register an ALB Target Group with an ECS Service)
- Docker (both the binary as well as a running daemon)

## Explanation
In order to minimize dependences I decided to do everything with bash, the awscli and Docker.

### Stages
aws-app.py is broken up into three stages:

#### Infrastructure
The first time aws-app.sh is run it will create a CloudFormation stack that necessary infrastrucrue to run an ECS Cluster. This includes

#### Build
 During the build stage aws-app.py finds which SHA HEAD is pointing to. It then uses this to check if a docker image has been deployed that contains the same SHA. If this is not the case then a new docker image is built and uploaded to ECR.

Note: it would have been preferable to use git tags rather than a SHA; however for this exercise I treated the application repo as though it were out of my control. It also would be preferable to have the Dockerfile live in the opseng-challenge-app repo.

#### Deploy
The application is deployed as a task in an ECS service that uses the new Applicaton Load Balancer (ALB). I wanted to use this as it supports running multiple instances of the same contaner on a single container instance (this was not possible with ELB due to how port mappings worked.) As a new version of task definition is created the ECS service handles spawning tasks and adding/removing them from the Target Group of the ALB. A deploy is sucessfull if it passes the health check of the ALB (for this it is simply "/").

## Possible Improvements
- A CNAME for the DNS ALB A record
- HTTPS instead of HTTP for the ALB
- Testing (unit/integration) for application build
- Decoupling aws-app.sh from opseng-challenge-app so that it can be used for multple projects
- A CI server or service would be better to do the application build
- Using a KeyPair for the container instances might be a good idea (currently there is no way of ssh'ing in if you need to)
- More error handling in aws-app.sh (probably prudent to turn this into a python script as it's getting somewhat unwieldly)

## Instructions
```
$ git clone https://github.com/mschurenko/opseng-challenge.git
$ cd opseng-challenge
$ ./aws-app.sh
```

## Clean Up
```
$ ./aws-app.sh --destroy
```

#### Notes

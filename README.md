# AWS APP delivery

This project runs an EC2 instance in the default VPC, providing the initial configuration of the instance in the user-data section.

The tools used are:

1. SHELL Scripting: bash in order to create the instance coupled with awscli to create all resources needed, like security groups and EC2 instance, together with an initial script to be executed in the instance during the initialization process. The use of bash as an initial solution to create the AWS resources is applicable to UNIX like systems.

1. Ansible: The user-data script installs ansible and clone a repository with the roles to be applied to the running instance. Using ansible as a configuration tool adds important capabilities that allows to extend this solution to other types of applications. 

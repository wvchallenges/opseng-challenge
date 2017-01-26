#!/bin/bash

#uses awscli to query ec2 instances and output the public dns name while appending port to the end of the output
echo -n "$(aws ec2 describe-instances --query 'Reservations[].Instances[].PublicDnsName' --output text):8000"
echo ''


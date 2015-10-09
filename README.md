# opseng-challenge
This is the read me for lily's opseng-challenge

It's include 3 parts

1、aws-flask.sh

This is a bash script for launch an aws instance automaticlly.

Before you use this script, please fill out the 4 and 5 lines as below.
access_key='Your aws access key'
secret_key='Your aws secret key'

Also, You need to installed the aws cli utility and configured it.
you can also set the environment variable in the top of aws-flask.sh。

2、app

The directory called app are include of files for Flask app

The developers should be upload the code to this directory, then can be deploy the application through aws cli + ansible.

Right now there is just a python code show "hello world"


3、ansible-playbook file

  



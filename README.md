# opseng-challenge
This is the read me for lily's opseng-challenge

It's include 3 parts

###

1、aws-flask.sh

This is a bash script for launch an aws instance automaticlly. It only test in centos6.5.

Before you use this script, please fill out the 4 and 5 lines as below.
access_key='Your aws access key'
secret_key='Your aws secret key'

Also, You need to installed the git, ansible, aws cli utility and configured it.

you can also set the environment variable in the top of aws-flask.sh.

This script will just create 1 instances. If instance is already existed, it will be exit.



2、app

The directory called app are include of files for Flask app

The developers should be upload the code to this directory, then can be deploy the application through aws cli + ansible.

Right now there is just a python code show "hello world"



3、ansible-playbook file

The directory called ansible are include of the files for auto configure the aws ec2 instance environment and auto deploy the flask app.

ansible-playbook file should be work with aws-flask.sh together.

If the ec2 instance is empty, ansible-playbook will be set up and run it;

If the ec2 instance is already configured, ansible-playbook will just fetch the latest flask app from git hub.



###How to set up by one step

cd /tmp && git clone https://github.com/clover1983/opseng-challenge.git && cd /tmp/opseng-challenge && chmod u+x aws-flask.sh && sed -i "s/access_key=''/access_key='Your Key'/g" aws-flask.sh && sed -i "s/secret_key=''/secret_key='Your Key'/g" aws-flask.sh && sh -x ./aws-flask.sh

###How to deploy by ansible

ansible-playbook /etc/ansible/lilyopseng.yml -u "Your user" --become-user=root --become-method=sudo -b  --private-key="Your key file"


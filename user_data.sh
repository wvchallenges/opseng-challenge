#!/usr/bin/env bash
apt-add-repository ppa:ansible/ansible -y
apt-get update -y
apt-get install ansible -y
apt-get install git -y
mkdir /usr/local/repo
git clone https://github.com/skysec/opseng-challenge.git /usr/local/repo
cd /usr/local/repo/playbook
ansible-playbook site.yml

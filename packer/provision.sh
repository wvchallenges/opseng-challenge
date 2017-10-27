#!/bin/sh

sudo apt-get update
sudo apt-get install -y git python-pip
mkdir deploy
cd deploy
git clone https://github.com/wvchallenges/opseng-challenge-app.git
cd opseng-challenge-app
sudo pip install -r requirements.txt
# gunicorn app:app --bind 0.0.0.0:8000

sudo cp /home/ubuntu/rc.local /etc/rc.local



FROM centos:latest
MAINTAINER Glen Yu
RUN yum -y install epel-release
RUN yum -y install python2-pip
COPY . /wvchallengeapp
WORKDIR /wvchallengeapp
RUN pip install -r requirements.txt
CMD gunicorn -b 0.0.0.0:8000 app:app

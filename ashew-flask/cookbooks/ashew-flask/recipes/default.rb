#
# Cookbook Name:: ashew-flask
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.
apt_package 'python-pip'
apt_package 'python-dev'
apt_package 'build-essential'
apt_package 'gunicorn'
apt_package 'nginx'
apt_package 'git'
apt_package 'gcc'

include_recipe 'python'
python_pip 'Flask==0.10.1'

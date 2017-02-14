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

bash 'install_flask' do
	code <<-EOH
		pip install 'Flask==0.10.1'
		EOH
end

directory '/var/www/ashew-flask' do
  owner 'www-data'
  group 'www-data'
  mode '0755'
  recursive true
  action :create
end

git '/tmp/ashew-flask' do
  repository 'git://github.com/ashew/opseng-challenge.git'
  reference 'master'
  action :sync
end

bash 'install_ashew-flask_app' do
  cwd '/var/www/ashew-flask'
  code <<-EOH
    cp -r /tmp/ashew-flask/python-app/* ./
    EOH
end

cookbook_file '/etc/gunicorn.d/ashew-flask.conf' do
  source 'etc/gunicorn.d/ashew-flask.conf'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :reload, 'service[gunicorn]', :delayed
end

cookbook_file '/etc/nginx/sites-available/ashew-flask.conf' do
  source 'etc/nginx/sites-available/ashew-flask.conf'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :reload, 'service[nginx]', :delayed
end

link '/etc/nginx/sites-enabled/ashew-flask.conf' do
  to '/etc/nginx/sites-available/ashew-flask.conf'
end

link '/etc/nginx/sites-enabled/default' do
  action :delete
end

service 'gunicorn' do
  action :restart
  ignore_failure
end

service 'nginx' do
  action :restart
  ignore_failure
end
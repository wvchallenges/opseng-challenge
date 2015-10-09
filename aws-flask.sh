#!/bin/bash
#2015-10-08
#aws-flask.sh, test at Centos6.5
access_key=''
secret_key=''
group_name=lily.example.com
key_name=lily.example.com
key_file='/tmp/lily.example.com.pem'
image_id='ami-00e30733'
instance_tag='lily.example.com'
ansible_conf='/etc/ansible/hosts'
ansible_host='lilyopseng'
ansible_user='ubuntu'


###check AWS CLI can be running. 

aws --version

if [ $? -eq 0 ]; then
  echo "aws cli is installed!"
else
  echo "please install aws cli first!";
  exit
fi


cat ~/.aws/credentials | grep $access_key

if [ $? -eq 0 ]; then
  echo "aws cli access key id is configured correct!"
else
  echo "you need to configured aws cli access key id first!";
  exit
fi


cat ~/.aws/credentials | grep $secret_key

if [ $? -eq 0 ]; then
  echo "aws cli secret access key is configured correct!"
else
  echo "you need to configured aws cli secret access key first!";
  exit
fi


aws ec2 describe-key-pairs

if [ $? -eq 0 ]; then
  echo "aws cli for user lily is running correct!"
else
  echo "please configured aws cli for user lily first!";
  exit
fi


####Test if security-group is existed. If yes, exit. If no, create.

aws ec2 describe-security-groups --group-name $group_name

if [ $? -eq 0 ]; then
  echo "security-groups is already exist!"
else
  aws ec2 create-security-group --group-name $group_name --description "security group for opseng-challenge in EC2 create by lily"
fi

####Test if security-group ssh rules is existed. If yes, exit. If no, create.

aws ec2 describe-security-groups --group-name $group_name --filters Name=ip-permission.from-port,Values=22 Name=ip-permission.to-port,Values=22 Name=ip-permission.cidr,Values='0.0.0.0/0'  | grep -A 10 -B 10 "22" | grep '0.0.0.0/0'

if [ $? -eq 0 ]; then
  echo "security-groups ssh rule is already exist!"
else
  aws ec2 authorize-security-group-ingress --group-name $group_name --protocol tcp --port 22 --cidr 0.0.0.0/0
fi

####Test if security-group http rules is existed. If yes, exit. If no, create.

aws ec2 describe-security-groups --group-name $group_name --filters Name=ip-permission.from-port,Values=80 Name=ip-permission.to-port,Values=80 Name=ip-permission.cidr,Values='0.0.0.0/0'  | grep -A 10 -B 10 "80" | grep '0.0.0.0/0'

if [ $? -eq 0 ]; then
  echo "security-groups http rule is already exist!"
else
  aws ec2 authorize-security-group-ingress --group-name $group_name --protocol tcp --port 80 --cidr 0.0.0.0/0
fi


####Test if key-pair is existed. If yes, exit. If no, create.

aws ec2 describe-key-pairs --key-name $key_name

if [ $? -eq 0 ]; then
  echo "key-pair is already exist!"
else
  aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > $key_file;
  chmod 400 $key_file
fi


####Test if instance is existed. If yes, exit. If no, create.

aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_tag" "Name=instance-state-code,Values=16" | grep "$instance_tag"

if [ $? -eq 0 ]; then
  echo "instance is already exist!"
else
  instance_id=`aws ec2 run-instances --image-id $image_id --count 1 --instance-type t1.micro --key-name $key_name --security-groups $group_name --query 'Instances[0].InstanceId' | 
sed -e 's/\"//g'`;
  aws ec2 create-tags --resources $instance_id --tags "Key=Name,Value=$instance_tag";
  sleep 60;
  instance_ip=`aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress' | sed -e 's/\"//g'`
  export instance_ip;
fi

###Test ansible is installed or not.

ansible --version 

if [ $? -eq 0 ]; then
  echo "ansbile is installed!"
else
  echo "installing ansible ......"
  os=$(cat /etc/issue |sed -n '1p' | cut -d ' ' -f 1) ;
  case $os in
    CentOS | Red | Fedora) yum install -y ansible
    ;;
    Ubuntu | Debian) sudo apt-get install -y ansible
    ;;
	SUSE) zypper install -y ansible
    ;;
	*) echo "please install ansible manually" && exit
	;;
  esac	
fi


###Test if the instance host is already in the ansible host file.

grep -A 4 -B 4 "$ansible_host" $ansible_conf | grep "$instance_ip"

if [ $? -eq 0 ]; then
  echo "The host is already add!"
else
  echo "[$ansible_host]" >> $ansible_conf
  echo "$instance_ip" >> $ansible_conf
fi

###Test git is installed or not.

git --version

if [ $? -eq 0 ]; then
  echo "git is installed!"
else
  echo "installing git ......"
  os=$(cat /etc/issue |sed -n '1p' | cut -d ' ' -f 1) ;
  case $os in
    CentOS | Red | Fedora) yum install -y git
    ;;
    Ubuntu | Debian) sudo apt-get install -y git
    ;;
	SUSE) zypper install -y git
    ;;
	*) echo "please install git manually" && exit
	;;
  esac	
fi


###Clone the ansible playbook script for install flask

if [ -d /etc/ansible/roles/lilyopseng ] && [ -f /etc/ansible/lilyopseng.yml ]; then
  echo "ansible playbook script already exist!"
else
  cd /etc/ansible/ && git clone https://github.com/clover1983/opseng-challenge.git
fi
  


###Run ansible playbook

ansible $ansible_host --private-key=$key_file -m ping

if [ $? -eq 0 ]; then
  ansible-playbook /etc/ansible/lilyopseng.yml -u $ansible_user --become-user=root --become-method=sudo -b  --private-key=$key_file
else
  echo "ssh connect wrong!"
fi


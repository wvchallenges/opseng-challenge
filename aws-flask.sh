#/bin/bash
set -e
export ANSIBLE_NOCOWS=1
export ANSIBLE_HOST_KEY_CHECKING=False # set to avoid prompt on fresh AWS server

# AWS instance needs some time to calm down, its not the fastest or the strongest.
# Therefore, this is done first.
echo "Preparing AWS instance"
ec2ipaddr=$(ansible-playbook build/ansible/create_instance.yml | \
			grep '"msg":' | \
			tail -1 | \
			grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')

echo "Beginning Docker build"
(cd build/docker && make > /dev/null)

echo "Deploying container to AWS"
ansible-playbook -u ubuntu -i "${ec2ipaddr}," build/ansible/setup_docker.yml > /dev/null

printf "Flask application running at http://%s.\n" "$ec2ipaddr"

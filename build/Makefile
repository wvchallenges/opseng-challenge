NAME=adiana/opseng

build:
	rsync -az --exclude 'venv' ../src/ docker/app
	cd docker; docker build -t=${NAME}:latest .
	docker save --output="opsgadget.tar" ${NAME}:latest
	docker rmi ${NAME}:latest

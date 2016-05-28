EPOCH=$(shell date +%s )
NAME=adiana/opseng

build:
	rsync -az --exclude 'venv' ../src/ docker/app
	cd docker; docker build -t=${NAME}:${EPOCH} .
	docker save --output="image.tar" ${NAME}:${EPOCH}

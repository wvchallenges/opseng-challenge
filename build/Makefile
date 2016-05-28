EPOCH=$(shell date +%s )
NAME=adiana/opseng

build:
	cd docker; docker build -t=${NAME}:${EPOCH} .
	docker save --output="image.tar" ${NAME}:${EPOCH}

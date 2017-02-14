NAME=adiana/opseng

build:
	rm -r ./app/
	rsync -az --exclude 'venv' ../../src/ ./app
	docker build -t=${NAME}:latest .
	docker save --output="opsgadget.tar" ${NAME}:latest
	docker rmi ${NAME}:latest

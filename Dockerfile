FROM alpine:3.5
MAINTAINER matt.schurenko@gmail.com

RUN apk add --update bash git py2-pip

ARG repo
ARG version
COPY $repo $version
WORKDIR $version
RUN pip install -r requirements.txt
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]

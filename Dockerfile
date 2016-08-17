################################################
# Dockerfile to build a simple web app
# based on Ubuntu
################################################

# Set base image
FROM ubuntu

# Mainter
MAINTAINER  TL

# Update repository sources list
RUN apt-get update

# Export port
EXPOSE 8000

# Set holding directory for required files
ENV REQDIR /wave-app

# Install and upgrade PIP
RUN apt-get -y install python-pip
RUN pip install --upgrade pip

# Create directory for required files
RUN mkdir ${REQDIR}

# copy needed files
COPY ./requirements.txt ${REQDIR}
COPY ./app.py ${REQDIR}

# Install prepreqs
RUN pip install -r ${REQDIR}/requirements.txt

# CMD 
CMD cd ${REQDIR} && gunicorn -b 0.0.0.0:8000 app:app

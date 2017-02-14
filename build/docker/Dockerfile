FROM base/archlinux

# uncomment if you value mirror speed over build cache
#ADD ./conf/mirrorlist /etc/pacman.d/mirrorlist

RUN pacman --noconfirm -Sy archlinux-keyring
RUN pacman --noconfirm -S nginx supervisor python2-pip openssl

# expose port(s)
EXPOSE 80

ADD ./conf/supervisord.conf /etc/supervisord.conf
ADD ./conf/nginx.conf /etc/nginx/nginx.conf
ADD ./app /opt/app

# install python deps
RUN pip2 install -r /opt/app/requirements.txt

# start supervisor to run our wsgi server
CMD supervisord -c /etc/supervisord.conf -n

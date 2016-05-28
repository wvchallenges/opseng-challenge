FROM base/archlinux

ADD ./conf/mirrorlist /etc/pacman.d/mirrorlist
RUN pacman --noconfirm -Sy archlinux-keyring
RUN pacman --noconfirm -S nginx supervisor

# expose port(s)
EXPOSE 80

ADD ./conf/supervisord.conf /etc/supervisord.conf
ADD ./conf/nginx.conf /etc/nginx/nginx.conf
ADD ./app /opt/app

# start supervisor to run our wsgi server
CMD supervisord -c /etc/supervisord.conf -n

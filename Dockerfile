FROM node:10.16-jessie

RUN useradd -m -d /home/myuser -s /bin/bash myuser
RUN apt-get -y update
RUN apt-get -y install vim curl unzip
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp
RUN mkdir -p /opt/app/myserver
COPY . /opt/app/myserver/
RUN chown -R myuser:myuser /opt/app/myserver/

USER myuser
WORKDIR /opt/app/myserver

EXPOSE 3000
CMD ["yarn", "start"]

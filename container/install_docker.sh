#!/bin/bash

# Add the docker group if it doesn't already exist:
# sudo groupadd docker

# Add the connected user "$USER" to the docker group. Change the user name to match your preferred user if you do not want to use your current user:
# sudo gpasswd -a $USER docker
# sudo usermod -aG docker $USER
# sudo setfacl -m user:$USER:rw /var/run/docker.sock

apt-get -y remove docker docker-engine docker.io containerd runc
apt-get -y update
apt-get -y install ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

apt-get -y update
apt-get -y install docker.io
#docker-ce docker-ce-cli containerd.io

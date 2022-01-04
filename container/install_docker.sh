#!/bin/bash

apt-get -y remove docker docker-engine docker.io containerd runc
apt-get -y update
apt-get -y install ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

apt-get -y update
apt-get -y install docker.io
#docker-ce docker-ce-cli containerd.io

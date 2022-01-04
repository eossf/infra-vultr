#!/bin/bash

apt -y remove ansible
apt -y install software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt -y update
apt -y install ansible
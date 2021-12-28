# K3s ansible on Vultr

## Create console VULTR
### script creating the console
````
./install_k3s_vultr.sh "CONSOLE01"
````
### copy id_rsa in the console01
````
scp -i ~/.ssh/id_rsa ~/.ssh/id_rsa root@PUB_IP_CONSOLE01:~/.ssh/id_rsa
````

## Create infrastructure VULTR
### script creating the masters and nodes
````
ssh -i ~/.ssh/id_rsa root@PUB_IP_CONSOLE01
git clone git@github.com:eossf/infra-vultr.git
cd infra-vultr
apt install jq
export  VULTR_API_KEY="YYYY"
export  K3S_TOKEN="ZZZZ"
./install_k3s_vultr.sh "MASTER01 NODE01"
````
### ansible 
Still on the console01
````
apt remove ansible 
apt install software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt update
apt install ansible
````
### install role 
````
ansible-galaxy install xanmanning.k3s
````
### deploy k3s cluster
````
ansible-playbook -i inventory.yml cluster.yml
````

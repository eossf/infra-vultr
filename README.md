# K3s ansible on Vultr
## ansible playbook
### install ansible
sudo apt remove ansible 
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt install ansible
### install role 
ansible-galaxy install xanmanning.k3s

## create infrastructure
### script creating masters and nodes for vultr
./install_k3s_vultr.sh "MASTER01 NODE01"
## install k3s
ansible-playbook -i inventory.yml cluster.yml

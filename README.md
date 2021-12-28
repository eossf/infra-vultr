# K3s ansible on Vultr

## script creating masters and nodes for vultr

## ansible playbook
sudo apt remove ansible 
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt install ansible
# install role 
ansible-galaxy install xanmanning.k3s
ansible-playbook -i inventory.yml cluster.yml

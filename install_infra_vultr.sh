#!/bin/bash

# default value
DEFAULTNODELIST="CONSOLE01 MASTER01 NODE01 "

# ubuntu 21.10
UBUNTU="517"

# centos8 x64
CENTOS="362"
plan_console="vc2-1c-2gb"
plan_master="vc2-2c-4gb"
plan_node="vc2-1c-2gb"
osid=$UBUNTU
region="cdg"
number_node=0
number_master=0
number_console=0
file_inventory_master="/tmp/kube_master.yml"
file_inventory_node="/tmp/kube_node.yml"

# --- params ---
nodelist="$1"
vultrapikey="$2"
if [[ $nodelist == "" ]] ; then
	nodelist=$DEFAULTNODELIST
fi
if [[ $vultrapikey == "" ]] ; then
	vultrapikey=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $vultrapikey == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi

VULTR_API_KEY=$vultrapikey

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

echo " ----------------------------"
echo "OSID             = $osid"
echo "NODELIST         = $nodelist"
echo "VM master        = $plan_master"
echo "VM node          = $plan_node"

echo " ----------------------------"
echo "Get private network list"
APN=`curl -s "https://api.vultr.com/v2/private-networks" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.networks[].id' | tr -d '"'`
if [[ $APN == "" ]]; then 
    echo "Create one private network"
    APN=`curl -s "https://api.vultr.com/v2/private-networks" \
    -X POST \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
        "region" : "'$region'",
        "description" : "K3s Private Network",
        "v4_subnet" : "192.168.0.0",
        "v4_subnet_mask" : 16
    }' | jq '.network.id' | tr -d '"'`
fi
echo "VPN id : $APN"
echo " ----------------------------"
echo "Get SSH key for accessing servers"
SSHKEY_ID=`curl -s "https://api.vultr.com/v2/ssh-keys"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.ssh_keys[].id' | tr -d '"'`

echo "Create masters and nodes"
echo " ----------------------------"
for node in $nodelist
do
  if [[ ${node} =~ "CONSOLE" ]]; then
    plan=$plan_console
    number_console=$((number_console++))
  fi
  if [[ ${node} =~ "MASTER" ]]; then
    plan=$plan_master
    number_master=$((number_master++))
  fi
  if [[ ${node} =~ "NODE" ]]; then 
    plan=$plan_node
    number_node=$((number_node++))
  fi
DATA='{"region":"'$region'",
"plan":"'$plan'",
"label":"'$node'",
"hostname":"'$node'",
"os_id":'$osid',
"attach_private_network":["'$APN'"],
"sshkey_id":["'$SSHKEY_ID'"]
}'

  echo "Create node:"$node
  curl -s "https://api.vultr.com/v2/instances" -X POST -H "Authorization: Bearer ${VULTR_API_KEY}" -H "Content-Type: application/json" --data "${DATA}"
  echo
done

echo "Wait provisionning finishes ..."
echo " ----------------------------"
sleep $((15+(number_master+number_node)*10))
echo

echo "Get Nodes and set internal interface "
NODES=`curl -s "https://api.vultr.com/v2/instances" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODES_COUNT=`echo $NODES | jq '.instances' | grep -i '"id"' | tr -d "," | cut -d ":" -f2 | tr -d " " | tr -d '"'`
for t in ${NODES_COUNT[@]}; do
  NODE=`curl -s "https://api.vultr.com/v2/instances/${t}" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
  NODE_LABEL=`echo $NODE | jq '.instance.label' | tr -d '"'`
  NODE_INTERNAL_IP=`echo $NODE | jq '.instance.internal_ip' | tr -d '"'`
  NODE_MAIN_IP=`echo $NODE | jq '.instance.main_ip' | tr -d '"'`
  if [[ $osid == "$CENTOS" ]]; then
    echo "CentOS Linux detected"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli | grep 'disconnected' | cut -d':' -f1 > /tmp/ITF"
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/ITF /tmp/ITF
    ITF=`cat /tmp/ITF`
    rm /tmp/ITF
    localfile="ifcfg-$ITF.yaml"
    netfile="ifcfg-$ITF"
    echo "Capture itf name : $localfile"
    cp -f net-centos8.tmpl $localfile
    echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
    sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' $localfile
    sed -i 's/#ITF#/'$ITF'/g' $localfile
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" "./$localfile" root@"$NODE_MAIN_IP:/etc/sysconfig/network-scripts/$netfile"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli con load /etc/sysconfig/network-scripts/$netfile"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli con up 'System "$ITF"'"
    fi
  if [[ $osid == "$UBUNTU" ]]; then
    echo "Ubuntu Linux detected"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "ip a | grep -iA2 '3: enp' | grep -i 'link/ether' | cut -d' ' -f6 > /tmp/MAC"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "ip a | grep -i '3: enp' | cut -d':' -f2 | tr -d ' ' > /tmp/ITF"
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/MAC /tmp/MAC
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/ITF /tmp/ITF
    MAC=`cat /tmp/MAC`
    rm /tmp/MAC
    ITF=`cat /tmp/ITF`
    rm /tmp/ITF
    localfile="10-$ITF.txt"
    netfile="10-$ITF"
    echo "Capture itf name :$netfile"
    cp -f net-ubuntu.tmpl $netfile
    echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
    sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' $localfile
    sed -i 's/#ITF#/'$ITF'/g' $localfile
    sed -i 's/#MAC#/'$MAC'/g' $localfile
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" "./$localfile" root@"$NODE_MAIN_IP:/etc/netplan/$netfile"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "netplan apply" 
  fi
done

echo "Prepare files for Ansible ..."
echo " ----------------------------"

# get info back for ansible provisionning
NODES=`curl -s "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODE_LABEL=`echo $NODES | jq '.instances[].label' | tr -d '"'`
NODE_MAIN_IP=`echo $NODES | jq '.instances[].main_ip' | tr -d '"'`
NODE_INTERNAL_IP=`echo $NODES | jq '.instances[].internal_ip' | tr -d '"'`

echo "NODE             = $NODE"
echo "NODE_LABEL       = $NODE_LABEL"
echo "NODE_MAIN_IP     = $NODE_MAIN_IP"
echo "NODE_INTERNAL_IP = $NODE_INTERNAL_IP"

echo "Display hosts"
echo " ----------------------------"
HOSTNAME=()
i=0
for t in ${NODE_LABEL[@]}; do
  HOSTNAME[$i]=$t
  echo "Host : $t"
  ((i++))
done

function remove_file()
{
  local remove_master=$1
  local remove_node=$2
  if [ -f "$remove_master" ]; then
    rm $remove_master
  fi
  if [ -f "$remove_node" ]; then
    rm $remove_node
  fi
}

function create_inventory()
{
  local ips=$1
  local inventory=$2
  echo "Print out inventory file: $inventory for public ip"
  echo " ----------------------------"
  i=0
  for ip in $ips
  do
      echo "Public ip:$ip"
      if valid_ip $ip; then
          if [[ $ip == "0.0.0.0" ]]; then
              stat='bad'
          else
              stat='good'
              echo "Host: ${HOSTNAME[$i]}"
              if [[ ${HOSTNAME[$i]}  =~ "CONSOLE" ]]; then
                echo "Host: ${HOSTNAME[$i]} is not managed by ansible"
                echo "Connection information"
                echo "scp -i ~/.ssh/id_rsa ~/.ssh/id_rsa root@$ip:~/.ssh/id_rsa"
                echo "ssh -i ~/.ssh/id_rsa root@$ip"
                echo
              fi
              if [[ ${HOSTNAME[$i]}  =~ "MASTER" ]]; then
  echo '    #KUBE_MASTER_HOSTNAME:
        ansible_host: #KUBE_MASTER_MAIN_IP
        ansible_ssh_user: "root"
        ansible_ssh_private_key_file: "~/.ssh/id_rsa"
        ansible_become: true
        ansible_become_user: "root"' | sed 's/#KUBE_MASTER_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_MASTER_MAIN_IP/'$ip'/g' >> /tmp/kube_master.yml
              fi
              if [[ ${HOSTNAME[$i]}  =~ "NODE" ]]; then
  echo '    #KUBE_NODE_HOSTNAME:
        ansible_host: #KUBE_NODE_MAIN_IP
        ansible_ssh_user: "root"
        ansible_ssh_private_key_file: "~/.ssh/id_rsa"
        ansible_become: true
        ansible_become_user: "root"' | sed 's/#KUBE_NODE_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_NODE_MAIN_IP/'$ip'/g' >> /tmp/kube_node.yml
              fi
          fi
      else
          stat='bad';
      fi

      echo "Insertion into $inventory result ${HOSTNAME[$i]} = $stat"
      ((i=i+1))
  done

  # substitute all
  if [[ -f "$file_inventory_master" ]]; then
    cp -f inventory-ansible.tmpl $inventory
    cat -s $file_inventory_master >> $inventory
    cat -s $file_inventory_node >> $inventory
    remove_file $file_inventory_master $file_inventory_node
  fi
}

# first inventory on pub ips
create_inventory $NODE_MAIN_IP "inventory-public.yml"
# second on private ips
create_inventory $NODE_INTERNAL_IP "inventory-private.yml"

echo
echo "End of script"
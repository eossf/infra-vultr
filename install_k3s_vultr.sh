#!/bin/bash

# default value
DEFAULTNODELIST="CONSOLE01 MASTER01 MASTER02 MASTER03 NODE01 NODE02 NODE03"

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

# --- params ---
nodelist="$1"
vultrapikey="$2"
k3stoken="$3"
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
if [[ $k3stoken == "" ]] ; then
	k3stoken=`env | grep "K3S_TOKEN" | cut -d"=" -f2`
  if [[ $k3stoken == "" ]] ; then
    echo "Please enter the K3S_TOKEN parameter or exported env var"
    exit;
  fi
fi
VULTR_API_KEY=$vultrapikey
K3S_TOKEN=$k3stoken

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
sleep $((30+(number_master+number_node)*10))
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
    netfile="ifcfg-$ITF"
    echo "Capture itf name : $netfile"
    cp -f net-centos8.tmpl $netfile
    echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
    sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' $netfile
    sed -i 's/#ITF#/'$ITF'/g' $netfile
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" "./$netfile" root@"$NODE_MAIN_IP:/etc/sysconfig/network-scripts/$netfile"
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
    netfile="10-$ITF.yaml"
    echo "Capture itf name :$netfile"
    cp -f net-ubuntu.tmpl $netfile
    echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
    sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' $netfile
    sed -i 's/#ITF#/'$ITF'/g' $netfile
    sed -i 's/#MAC#/'$MAC'/g' $netfile
    scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" "./$netfile" root@"$NODE_MAIN_IP:/etc/netplan/$netfile"
    ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "netplan apply" 
  fi
done

echo "Prepare files for Ansible ..."
echo " ----------------------------"

# get info back for ansible provisionning
NODES=`curl "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
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

function removefile()
{
  if [ -f "kube_master.yml" ]; then
    rm kube_master.yml
  fi
  if [ -f "kube_node.yml" ];
    rm kube_node.yml
  fi
}

echo "Print inventory.yml"
echo " ----------------------------"
i=0
for ip in $NODE_MAIN_IP
do
    echo "Public ip:$ip"
    if valid_ip $ip; then
        if [[ $ip == "0.0.0.0" ]]; then
            stat='bad'
        else
            stat='good'
            echo "Host:${HOSTNAME[$i]}"
            if [[ ${HOSTNAME[$i]}  =~ "CONSOLE" ]]; then
              echo "Host: ${HOSTNAME[$i]} is not managed by ansible"
            fi
            if [[ ${HOSTNAME[$i]}  =~ "MASTER" ]]; then
echo '    #KUBE_MASTER_HOSTNAME:
      ansible_host: #KUBE_MASTER_MAIN_IP
      ansible_ssh_user: "root"
      ansible_ssh_private_key_file: "~/.ssh/id_rsa"
      ansible_become: true
      ansible_become_user: "root"' | sed 's/#KUBE_MASTER_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_MASTER_MAIN_IP/'$ip'/g' >> kube_master.yml
            fi
            if [[ ${HOSTNAME[$i]}  =~ "NODE" ]]; then
echo '    #KUBE_NODE_HOSTNAME:
      ansible_host: #KUBE_NODE_MAIN_IP
      ansible_ssh_user: "root"
      ansible_ssh_private_key_file: "~/.ssh/id_rsa"
      ansible_become: true
      ansible_become_user: "root"' | sed 's/#KUBE_NODE_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_NODE_MAIN_IP/'$ip'/g' >> kube_node.yml
            fi
        fi
    else
        stat='bad';
    fi

    echo "Result inventory for host = $stat"
    ((i=i+1))
done

# subsitute all
if [[ -f "kube_master" ]]; then
  cp -f inventory-ansible.tmpl inventory.yml
  cat -s kube_master.yml >> inventory.yml
  cat -s kube_node.yml >> inventory.yml
  removefile
fi

echo
echo "End of script"
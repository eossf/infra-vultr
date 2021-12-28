#!/bin/bash

tmpapi="$1"
if [[ $tmpapi == "" ]] ; then
	tmpapi=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $tmpapi == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi

cp -f inventory-k3s.yml inventory.yml
echo "" > kube_master.yml
echo "" > kube_node.yml

VULTR_API_KEY=$tmpapi

function valid_ip()
{
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# get info back for ansible provisionning
NODES=`curl "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODE_LABEL=`echo $NODES | jq '.instances[].label' | tr -d '"'`
NODE_MAIN_IP=`echo $NODES | jq '.instances[].main_ip' | tr -d '"'`
NODE_INTERNAL_IP=`echo $NODES | jq '.instances[].internal_ip' | tr -d '"'`

HOSTNAME=()
i=0
for t in ${NODE_LABEL[@]}; do
  HOSTNAME[$i]=$t
  ((i=i+1))
done

i=0
for ip in $NODE_MAIN_IP
do
    if valid_ip $ip; then 
        if [[ $ip == "0.0.0.0" ]]; then
            stat='bad'
        else
            stat='good'
            echo ${HOSTNAME[$i]}
            if [[ ${HOSTNAME[$i]}  =~ "MASTER" ]]; then
echo '
            #KUBE_MASTER_HOSTNAME:
              ansible_host: #KUBE_MASTER_MAIN_IP
              ansible_ssh_user: "root"
              ansible_ssh_private_key_file: "/home/metairie/.ssh/id_rsa"
              ansible_become: true
              ansible_become_user: "root"
' | sed 's/#KUBE_MASTER_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_MASTER_MAIN_IP/'$ip'/g' >> kube_master.yml
            fi
            if [[ ${HOSTNAME[$i]}  =~ "NODE" ]]; then
echo '
            #KUBE_NODE_HOSTNAME:
              ansible_host: #KUBE_NODE_MAIN_IP
              ansible_ssh_user: "root"
              ansible_ssh_private_key_file: "/home/metairie/.ssh/id_rsa"
              ansible_become: true
              ansible_become_user: "root"
' | sed 's/#KUBE_NODE_HOSTNAME/'${HOSTNAME[$i]}'/g' | sed 's/#KUBE_NODE_MAIN_IP/'$ip'/g' >> kube_node.yml
            fi
        fi
    else
        stat='bad';
    fi

    ((i=i+1))
done

# subsitute all
echo '
        kube_master:
          hosts:
' >> inventory.yml
cat kube_master.yml >> inventory.yml

echo '
        kube_node:
          hosts:
' >> inventory.yml
cat kube_node.yml >> inventory.yml

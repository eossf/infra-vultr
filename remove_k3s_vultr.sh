#!/bin/bash

tmpapi="$1"
if [[ $tmpapi == "" ]] ; then
	tmpapi=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $tmpapi == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi

VULTR_API_KEY=$tmpapi

# get info back for ansible provisionning
NODES=`curl -s "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.instances[].id' | tr -d '"'`
for node in $NODES
do
  NODE_INSTANCE=`curl -s "https://api.vultr.com/v2/instances/$node" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}"`
  NODE_LABEL=`echo $NODE_INSTANCE | jq '.instance.label' | tr -d '"'`
  echo "Found node: $NODE_LABEL"
  
  delete=0
  if [[ $NODE_LABEL  =~ "MASTER" ]]; then
    deleted=1
  fi
  if [[ $NODE_LABEL  =~ "WORKER" ]]; then
    deleted=1
  fi
  if [[ $NODE_LABEL  =~ "NODE" ]]; then
    deleted=1
  fi
  if [[ $deleted -eq 1 ]]; then
    echo "Delete node: "$NODE_LABEL
    curl -s "https://api.vultr.com/v2/instances/$node" -X DELETE -H "Authorization: Bearer ${VULTR_API_KEY}"
  else
    echo "** not changed  **"
  fi
done
#!/bin/bash

# --- params ---
nodelist="$1"
vultrapikey="$2"
if [[ $nodelist == "" ]] ; then
  deleteall=1
  echo "Delete all: on"
else
  deleteall=0
  echo "Delete all: off"
fi
if [[ $vultrapikey == "" ]] ; then
	vultrapikey=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $vultrapikey == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi

VULTR_API_KEY=$vultrapikey

NODES_LIST=`curl -s "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODES_LABEL=`echo $NODES_LIST | jq '.instances[].label' | tr -d '"'`
NODES_INSTANCE=`echo $NODES_LIST | jq '.instances[].id' | tr -d '"'`
for node in $NODES_INSTANCE; do
  delete=1
  NODE_INSTANCE=`curl -s "https://api.vultr.com/v2/instances/$node" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}"`
  INSTANCE_LABEL=`echo $NODE_INSTANCE | jq '.instance.label' | tr -d '"'`
  if [[ $deleteall -eq 0 ]]; then
    delete=0
    for locallabel in ${nodelist[@]}; do
      if [[ $INSTANCE_LABEL == $locallabel ]]; then
        delete=1
      fi
    done
  fi
  if [[ $delete -eq 1 ]]; then
    echo "$INSTANCE_LABEL : deleted"
    curl -s "https://api.vultr.com/v2/instances/$node" -X DELETE -H "Authorization: Bearer ${VULTR_API_KEY}"
  else 
    echo "$INSTANCE_LABEL : ** nothing to do **"
  fi
done

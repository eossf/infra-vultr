#!/bin/bash

# --- params ---
MASTER_IP="$1"
CONSOLE="$2"
if [[ $MASTER_IP == "" ]] ; then
  MASTER_IP="192.168.0.4"
  echo "Default IP: "$MASTER_IP
fi
if [[ $CONSOLE == "" ]] ; then
	CONSOLE="CONSOLE01"
    echo "Default console name: "$CONSOLE
fi

CONSOLE=`echo "$CONSOLE" | tr '[:upper:]' '[:lower:]'`

# create a kubeconfig file for CONSOLE01
kubectl -n kube-system create serviceaccount $CONSOLE-cluster-admin

echo "apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $CONSOLE-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $CONSOLE-cluster-admin
  namespace: kube-system
" | kubectl apply -f -

export USER_TOKEN_NAME=$(kubectl -n kube-system get serviceaccount ${CONSOLE}-cluster-admin -o=jsonpath='{.secrets[0].name}')
export USER_TOKEN_VALUE=$(kubectl -n kube-system get secret/${USER_TOKEN_NAME} -o=go-template='{{.data.token}}' | base64 --decode)
export CURRENT_CONTEXT=$(kubectl config current-context)
export CURRENT_CLUSTER=$(kubectl config view --raw -o=go-template='{{range .contexts}}{{if eq .name "'''${CURRENT_CONTEXT}'''"}}{{ index .context "cluster" }}{{end}}{{end}}')
export CLUSTER_CA=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}"{{with index .cluster "certificate-authority-data" }}{{.}}{{end}}"{{ end }}{{ end }}')
export CLUSTER_SERVER=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}{{ .cluster.server }}{{end}}{{ end }}')

echo "apiVersion: v1
kind: Config
current-context: ${CURRENT_CONTEXT}
contexts:
- name: ${CURRENT_CONTEXT}
  context:
    cluster: ${CURRENT_CONTEXT}
    user: $CONSOLE-cluster-admin
    namespace: kube-system
clusters:
- name: ${CURRENT_CONTEXT}
  cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_SERVER}
users:
- name: $CONSOLE-cluster-admin
  user:
    token: ${USER_TOKEN_VALUE}
" > $CONSOLE-cluster-admin-config

# open port 6443 
ufw allow 6443

# 127.0.0.1 by MASTER01 ip
sed -i 's/127.0.0.1/'${MASTER_IP}'/g' "$CONSOLE-cluster-admin-config"

cat $CONSOLE-cluster-admin-config 
echo "Access the cluster : kubectl --kubeconfig $CONSOLE-cluster-admin-config get all --all-namespaces"

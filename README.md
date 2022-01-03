# K3s ansible on Vultr

## Create machine "console01" in VULTR infra
### script creating the console
````
# WARNING you need jq (apt install jq)
./install_infra_vultr.sh "CONSOLE01"
````
### copy id_rsa in the console01
````
scp -i ~/.ssh/id_rsa ~/.ssh/id_rsa root@PUB_IP_CONSOLE01:~/.ssh/id_rsa
````

## Create infrastructure VULTR
### script creating the masters and nodes
Connect to the CONSOLE01
````
ssh -i ~/.ssh/id_rsa root@PUB_IP_CONSOLE01
````

Then clone and install the infra:
````
git clone git@github.com:eossf/infra-vultr.git
cd infra-vultr
apt -y install jq
export  VULTR_API_KEY="YYYY"
./install_infra_vultr.sh "MASTER01 NODE01"
````
## Install ansible 
Still on the console01
````
cd ~/infra-vultr/ansible
./install_ansible.sh
````
### install role k3s
````
ansible-galaxy install xanmanning.k3s
````
## deploy k3s cluster
````
cd ~/infra-vultr
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory-private.yml cluster.yml
````

### Kubeconfig
Still connected to the CONSOLE01 , copy the file create-kubeconfig.sh to the MASTER01
````
cd ~/infra-vultr
scp kub/create-kubeconfig.sh MASTER01:~/create-kubeconfig.sh
````

Then, switch to the MASTER01, launch:
````
chmod 775 ./create-kubeconfig.sh
./create-kubeconfig.sh LOCAL_IP_MASTER01 "CONSOLE01"
# by default : ./create-kubeconfig.sh 192.168.0.4 "CONSOLE01"
````

Exit and retrieve the file from CONSOLE01
## Install kubectl 
return to the CONSOLE01:
````
cd ~/infra-vultr/kub
./install_kubectl.sh
cd ~
mkdir .kube
scp root@MASTER01:~/console01-cluster-admin-config ~/.kube/config 
````

### Test kubectl
see script helper.sh for having completion and aliases to kubectl

````
kubectl get all --all-namespaces
NAMESPACE     NAME                                         READY   STATUS      RESTARTS   AGE
kube-system   pod/local-path-provisioner-9789bdbfb-24fkw   1/1     Running     0          21m
kube-system   pod/metrics-server-6486d89755-vspcd          1/1     Running     0          21m
kube-system   pod/helm-install-traefik-crd-42j8s           0/1     Completed   0          21m
kube-system   pod/coredns-84c56f7bfb-5hks6                 1/1     Running     0          21m
kube-system   pod/helm-install-traefik-vp5nl               0/1     Completed   2          21m
kube-system   pod/svclb-traefik-r64qz                      2/2     Running     0          20m
kube-system   pod/traefik-5dd8b78bfc-wx5pm                 1/1     Running     0          20m
kube-system   pod/svclb-traefik-rztww                      2/2     Running     0          4m5s

NAMESPACE     NAME                     TYPE           CLUSTER-IP      EXTERNAL-IP                    PORT(S)                      AGE
default       service/kubernetes       ClusterIP      10.43.0.1       <none>                         443/TCP                      21m
kube-system   service/kube-dns         ClusterIP      10.43.0.10      <none>                         53/UDP,53/TCP,9153/TCP       21m
kube-system   service/metrics-server   ClusterIP      10.43.4.139     <none>                         443/TCP                      21m
kube-system   service/traefik          LoadBalancer   10.43.102.153   45.63.115.169,95.179.208.131   80:31486/TCP,443:32116/TCP   20m

NAMESPACE     NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   daemonset.apps/svclb-traefik   2         2         2       2            2           <none>          21m

NAMESPACE     NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/local-path-provisioner   1/1     1            1           21m
kube-system   deployment.apps/metrics-server           1/1     1            1           21m
kube-system   deployment.apps/coredns                  1/1     1            1           21m
kube-system   deployment.apps/traefik                  1/1     1            1           20m

NAMESPACE     NAME                                               DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/local-path-provisioner-9789bdbfb   1         1         1       21m
kube-system   replicaset.apps/metrics-server-6486d89755          1         1         1       21m
kube-system   replicaset.apps/coredns-84c56f7bfb                 1         1         1       21m
kube-system   replicaset.apps/traefik-5dd8b78bfc                 1         1         1       20m

NAMESPACE     NAME                                 COMPLETIONS   DURATION   AGE
kube-system   job.batch/helm-install-traefik-crd   1/1           20s        21m
kube-system   job.batch/helm-install-traefik       1/1           39s        21m
````

## Install Helm
Still on the CONSOLE01:
````
cd ~/infra-vultr/helm
./install_helm.sh
````

## Install Docker
Still on the CONSOLE01:
````
cd ~/infra-vultr/container
./install_docker.sh
````

## remove infra (destroy machines)
Keep Console01
````
./remove_infra_vultr.sh "MASTER01 NODE01"

# or remove all 
./remove_infra_vultr.sh
````
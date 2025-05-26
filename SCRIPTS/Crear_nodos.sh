#!/bin/bash

# ESTE SCRIPT PARA LAS TRES MAQUINAS

negrita='\e[1m'

verde='\e[32m'

azul='\e[34m'

NC='\e[0m'

# Comprobar si se ejecuta como root

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${rojo}Este script debe ejecutarse como root.${NC}"
  exit 1
fi

echo -e "${azul}-------------------------------REQUISITOS PREVIOS--------------------------------${NC}"
apt update && apt upgrade -y
apt install -y curl apt-transport-https git wget software-properties-common lsb-release ca-certificates socat

echo -e "${azul}-------------------------------DESACTIVAR SWAP-----------------------------------${NC}"
swapoff -a
sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab

echo -e "${azul}----------------------------CARGA MODULOS Y CONFIGURA SYSCTL---------------------------${NC}"
modprobe overlay
modprobe br_netfilter

cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo -e "${azul}---------------------------------INSTALAR CONTAINERD-------------------------------${NC}"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update && apt-get install -y containerd.io

containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

echo -e "${azul}--------------------------------INSTALAR KUBERNETES-----------------------------------${NC}"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubeadm=1.30.1-1.1 kubelet=1.30.1-1.1 kubectl=1.30.1-1.1
apt-mark hold kubelet kubeadm kubectl

echo -e "${azul}--------------------------------AÑADIR HOST MAESTRO-------------------------------${NC}"
read -p "¿Que ip tiene el nodo maestro? " ip_maestro
echo "$ip_maestro k8scp" >> /etc/hosts

read -p "¿QUÉ NODO SERÁS, master O worker? " nodo

#NODO MASTER

if [[ $nodo == "master" ]]
then

	echo -e "${azul}------------------------------INICIAR EL CLUSTER CON KUBEADM----------------------------------${NC}"
	read -p "¿rango ip? ej:192.168.0.0/16" ip
	kubeadm init --pod-network-cidr=$ip --control-plane-endpoint=k8scp:6443

fi
#NODO WORKER
if [[ $nodo == "worker" ]]
then

	echo -e "${azul}--------------------------------------UNIR EL WORKER AL CLUSTER----------------------------------------${NC}"
	
	echo -e "${negrita}PUEDES CREAR EL COMANDO EJECUTANDO EN EL MASTER 'kubeadm token create --print-join-command'${NC}"
	
	read -p "token del cluster: " token
	
	read -p "hash del cluster: " hash
	
	kubeadm join k8scp:6443 --token $token --discovery-token-ca-cert-hash sha256:$hash
fi
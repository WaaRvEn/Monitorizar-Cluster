#!/bin/bash

negrita='\e[1m'

verde='\e[32m'

azul='\e[34m'

rojo='\e[31m'

NC='\e[0m'

#Comprobar si se ejecuta como usuario

if [[ "$EUID" -eq 0 ]]; then
  echo -e "${rojo}Este script debe ejecutarse como un usuario.${NC}"
  exit 1
fi

echo -e "${azul}------------------------------CONFIGURAR KUBECTL E INSTALAR AUTOCOMPLETADO-----------------------------------${NC}"

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo apt-get install bash-completion -y

source <(kubectl completion bash)

echo 'source <(kubectl completion bash)' >> ~/.bashrc # persistir autocompletado

echo -e "${azul}------------------------------------------INSTALAR HELM-------------------------------------------${NC}"

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update

sudo apt-get install helm -y

echo -e "${azul}---------------------------INSTALAR CILIUM, CNI QUE CONECTARA LOS PODS ENTRE SI-----------------------------${NC}"

helm repo add cilium https://helm.cilium.io/

helm repo update

helm template cilium cilium/cilium --version 1.16.1 \
--namespace kube-system > cilium.yaml

kubectl apply -f cilium.yaml

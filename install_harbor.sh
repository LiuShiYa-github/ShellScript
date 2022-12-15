#!/bin/bash
#########################################
# File Name: install_harbor.sh
# Version: v1.0
# Author:shiya.liu
# Note: Please modify script variables for multiple external network cards $network_name
# Official website: https://goharbor.io/docs/2.6.0/
#########################################
network_name=$(ls /etc/sysconfig/network-scripts/ifcfg-*|grep -v lo|awk -F '/etc/sysconfig/network-scripts/ifcfg-' '{print $2}')
network_ip=$(ifconfig "$network_name" | awk 'NR==2{print $2}')
function check_install_docker-compose() {
  if [ "$(docker-compose --version|grep -c version)" -eq 0 ]; then
    echo "docker-compose  is not installed"
    echo "docker-compose  installation will begin"
    curl -L "https://github.com/docker/compose/releases/download/1.27.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    cp docker-compose /usr/local/bin/
    chmod +x /usr/local/bin/docker-compose
  fi
}

function check_network_port() {
  if [ "$(netstat -lntp |grep -c ':80 ')" -ge 1 ]; then
    echo "port 80 is occupied, and the installer exits"
    exit 1
  fi
  if [ "$(netstat -lntp |grep -c '127.0.0.1:1514')" -ge 1 ]; then
    echo "port 127.0.0.1:1514 is occupied, and the installer exits"
    exit 1
  fi
}

function get_offline_packge() {
    wget https://github.com/goharbor/harbor/releases/download/v2.6.2/harbor-offline-installer-v2.6.2.tgz
    tar xf harbor-offline-installer-v2.6.2.tgz
    rm -rf harbor-offline-installer-v2.6.2.tgz
}

function make_cert() {
    mkdir -p ./data/cert
    openssl genrsa -out ./data/cert/server.key 2048
    #echo -e "\n\n\n\n\n\n\n\n\n"|openssl req -new -key ./data/cert/server.key -out ./data/cert/server.csr
    openssl req -new -subj "/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=yourdomain.com" -key ./data/cert/server.key -out ./data/cert/server.csr
    cp ./data/cert/server.key ./data/cert/server.key.org
    openssl x509 -req -days 365 -in ./data/cert/server.csr -signkey ./data/cert/server.key -out ./data/cert/server.crt
    chmod a+x ./data/cert/*
}

function change_config() {
    cp harbor/harbor.yml.tmpl harbor/harbor.yml
    sed -i "s#hostname: reg.mydomain.com#hostname: $network_ip#g" harbor/harbor.yml
    sed -i "s#certificate: /your/certificate/path#certificate: $(pwd)/data/cert/server.crt#g" harbor/harbor.yml
    sed -i "s#private_key: /your/private/key/path#private_key: $(pwd)/data/cert/server.key#g" harbor/harbor.yml
    ./harbor/install.sh --with-notary --with-trivy --with-chartmuseum
}

function output_info() {
  echo "Account name: admin"
  echo "password: Harbor12345"
  echo "Please enter the address on the browser to log in: https://$network_ip"
}

function mian() {
  check_install_docker-compose
  check_network_port
  get_offline_packge
  make_cert
  change_config
  output_info
}
mian

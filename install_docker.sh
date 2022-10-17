#!/bin/bash
#########################################
# File Name: install_docker.sh
# Version: v1.0
# Author:shiya.liu
#########################################
DOCKER_ROOT=/home/docker_data
function check_docker_install(){
    if [ "$(docker --version 2> /dev/null   |grep -c 'Docker version')" -eq 0 ]
    then
        echo "Docker is not installed in the current system, and will be installed soon---"
        return 100
    else
        echo "Docker has been installed in the current system"
        return 200
    fi
}

function uninstall_docker(){
    if [[ $(docker ps -a -q|wc -l) -eq 0 ]]; then
        echo "There is no Docker container in the current environment"
    else
        docker stop "$(docker ps -a -q)"
    fi

    if [[ $(docker images -a -q|wc -l) -eq 0 ]]; then
        echo "There is no Docker image in the current environment"
    else
        docker rmi "$(docker images -a -q)"
    fi
    systemctl stop docker
    rm -rf /etc/docker
    rm -rf /etc/systemd/system/docker.service
    if [[ -d "/home/docker_data" ]]; then
        rm -rf /home/docker_data
    elif [[ -d "/var/lib/docker" ]]; then
        rm -rf /var/lib/docker
    fi
    rm -rf /usr/bin/containerd /usr/bin/containerd-shim /usr/bin/ctr /usr/bin/docker /usr/bin/dockerd /usr/bin/docker-init /usr/bin/docker-proxy /usr/bin/runc
    # install brctl
    wget https://mirrors.edge.kernel.org/pub/linux/utils/net/bridge-utils/bridge-utils-1.6.tar.xz --no-check-certificate
    tar -xvf bridge-utils-1.6.tar.xz
    rm -rf bridge-utils-1.6.tar.xz
    cd bridge-utils-1.6 || exit 
    autoconf
    ./configure
    make
    make install
    cp brctl/brctl /usr/bin/
    cd ../
    rm -rf bridge-utils-1.6

    ifconfig docker0 down
    brctl delbr docker0
    if [[ $(df -Th|awk  '{print $7}'|grep -c 'docker') != 0 ]]; then
        umount /var/run/docker/netns/default
    fi
    rm -rf /var/run/docker
}

function install_docker(){
    wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.6.tgz
    tar -zvxf docker-19.03.6.tgz
    cp docker/* /usr/bin/
    rm -rf docker-19.03.6.tgz ./docker
    mkdir -p ${DOCKER_ROOT}

    cat >/etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF
    mkdir /etc/docker/
    cat >/etc/docker/daemon.json<< EOF
{
    "data-root": "${DOCKER_ROOT}",
    "log-driver": "json-file",
    "log-opts": {"max-size": "500m", "max-file": "3"},
    "registry-mirrors": ["https://yo3sdl2l.mirror.aliyuncs.com","https://registry.docker-cn.com","http://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"]
}
EOF
    chmod +x /etc/systemd/system/docker.service
    systemctl daemon-reload
    systemctl start docker
    systemctl stop docker
    systemctl restart  docker
    systemctl enable docker.service
    echo -e "\033[32m Docker software version: $(docker --version) \033[0m" 
}

function install_docker_compose(){
    curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "\033[32m docker-compose software version: $(docker-compose --version) \033[0m"
}

function main(){
    check_docker_install
    RESULT=$?
    if [ $RESULT == 100 ]; then
        install_docker
        install_docker_compose
    elif [ $RESULT == 200 ]; then
        uninstall_docker
        install_docker
        if [[ "$(docker-compose --version 2> /dev/null   |grep -c 'docker-compose version')" -eq 0 ]]; then
            install_docker_compose
        fi
    else
        echo "Unknown exception occurred, please check the program，status_cdeo:$RESULT"
    fi
}
main

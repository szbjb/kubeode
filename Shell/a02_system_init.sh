#!/bin/bash
# cd $(dirname $0) >/dev/null
#调试变量
cd /usr/local/kubeode/Shell/
source /usr/local/kubeode/Shell/cluster-ips.conf
_os_init_online() {
    time ansible-playbook /usr/local/kubeode/playbooks/A01_os_init.yml

}
#在线docker初始化
_docker_init_online() {
    os_release=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)
    ansible-playbook \
        -e "docker_version=27.3.1 cri_dockerd_version=0.3.15" \
        --extra-vars "install_method=online ansible_distribution_major_version=${os_release}" \
        /usr/local/kubeode/playbooks/A02_k8s_setup_docker.yml
}

#离线docker初始化
_docker_init_offline() {
    os_release=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)
    ansible-playbook \
        -e "docker_version=27.3.1 cri_dockerd_version=0.3.15" \
        --extra-vars "install_method=offline ansible_distribution_major_version=${os_release} download_type=offline" \
        /usr/local/kubeode/playbooks/A02_k8s_setup_docker.yml
}

#ssh集群免密处理
_init_ssh() {
    sed "/search/d" /etc/resolv.conf -i
    #集群免密登录处理(不重要)
    #清除本地ssh环境
    \rm -f ~/.ssh/id_dsa
    #创建秘钥对
    ssh-keygen -t dsa -f /root/.ssh/id_dsa -N ""
    #配置执行节点免密登录集群个节点
    SSHD_PORT=${SSHD_PORT}
    password=${ROOT_PASSWORD}
    for ip in $( egrep  "^[0-9]"  /etc/ansible/hosts |awk '{print  $1}' | sort | uniq | xargs); do
        sshpass -p "$password" ssh-copy-id -i /root/.ssh/id_dsa.pub -p ${SSHD_PORT} -o StrictHostKeyChecking=no root@$ip
    done
    #配置集群之间免密
    SSHD_PORT=${SSHD_PORT}
    password=${ROOT_PASSWORD}
    IP_LIST=${CLUSTER_IPS}
    cat >/tmp/ssh_pass.sh <<EOF
\rm -f ~/.ssh/id_dsa
ssh-keygen -t dsa -f /root/.ssh/id_dsa -N ""
    for ip in ${IP_LIST}; do
        sshpass -p "$password" ssh-copy-id -i /root/.ssh/id_dsa.pub -p ${SSHD_PORT} -o StrictHostKeyChecking=no root@\$ip
    done
EOF
    time ansible all -m script -a "chdir=/tmp  /tmp/ssh_pass.sh"
    #更改集群主机名由ip小至大递增修改（默认执行机为node01）
    LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)
    [[ -n "$LOCAL_IP" ]] || LOCAL_IP=$(hostname -I | xargs -n 1 | head -n 1)
    hostname_list=$(ansible all -m ping | egrep SUCCESS | awk '{print  $1}' | sort -t "." -k4 -n | egrep -v $LOCAL_IP | xargs)
    hostnamectl set-hostname node01
    i=1
    for var in ${hostname_list}; do
        i=$(expr $i + 1)
        [[ "$i" -lt 10 ]] && sshpass -p $password ssh root@${var} -p${SSHD_PORT} -o StrictHostKeyChecking=no "hostnamectl set-hostname  node0${i}"
        [[ "$i" -ge 10 ]] && sshpass -p $password ssh root@${var} -p${SSHD_PORT} -o StrictHostKeyChecking=no "hostnamectl set-hostname  node${i}"
    done
    echo "i: $i"
    #检查
    time ansible all -m ping
    #写入 /etc/hosts
    sed /node/d /etc/hosts -i
    sleep 0.1
    echo   "${LOCAL_IP} node01" >> /etc/hosts
    #集群hosts文件更新
    time ansible all -m lineinfile -a "path=/etc/hosts regexp='node' state=absent"
    #优化dns 去除search
    time ansible all -m shell -a "egrep  "^search"  /etc/resolv.conf &&  sed  's/search/#search/g'  /etc/resolv.conf   -i;cat /etc/resolv.conf"
    #私有镜像仓库hosts解析  增加kubeode.down.local到hosts
    time ansible all -m shell -a "sed /registry.kubeode.down.local/d /etc/hosts -i; sleep 0.2; echo '${LOCAL_IP}   kubeode.registry.local ghcr.io k8s.gcr.io quay.io registry-1.docker.io registry.k8s.io registry.kubeode.down.local kubeode.down.local' >> /etc/hosts"
}

#!/bin/bash

# 定义全局 Kubernetes 版本号变量
KUBERNETES_VERSION="v1.31"
LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1 )
rpm_list="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl  python3-libselinux python3-jmespath"
rpm_list_7="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl libselinux-python python3-jmespath"
rpm_list_8="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl python3-libselinux python3-jmespath"
rpm_list_9="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl python3-libselinux python3-jmespath"
_setup_python_http_server() {
    setenforce 0
    # 4.4.关闭防火墙
    systemctl disable --now firewalld && systemctl is-enabled firewalld
    systemctl is-status firewalld
#这里加个逻辑判断 如果链接正常就不写入服务重启
 curl -s http://kubeode.down.local:10086/offline
        if [ $? -eq 0 ]; then
            echo "离线源已正常"
     else
    cat >/etc/systemd/system/kubeode_local_http.service <<EOF
[Unit]
Description=Kubeode Local C HTTP File Server
After=network.target

[Service]
ExecStart=/usr/local/kubeode/Shell/simple_http_server 10086 /usr/local/kubeode/package/
WorkingDirectory=/usr/local/kubeode/package/
Restart=always
RestartSec=5
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kubeode_local_http.service
    systemctl restart kubeode_local_http.service
    sleep 3 
    systemctl is-active kubeode_local_http.service && {
        sed /kubeode.down.loca/d /etc/hosts -i
        sleep 0.2
        echo "${LOCAL_IP}   kubeode.down.local" >>/etc/hosts
    }
    fi
    while true; do
        curl -s http://kubeode.down.local:10086/offline
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 3
    done
}

# 检测 CentOS 版本
_detect_centos_version() {
    if [ -f /etc/os-release ]; then
        local version_id
        version_id=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)
        echo "$version_id"
    else
        echo "无法检测到 /etc/os-release 文件。"
        exit 1
    fi
}

_setup_centos_9_repo() {
    echo "配置 CentOS 9 离线 YUM 源..."
    cat >/etc/yum.repos.d/kubeode_local.repo <<EOF
[kubeode_local]
name=Kubeode Local Repository
baseurl=http://kubeode.down.local:10086/offline/centos_9_repo/
enabled=1
gpgcheck=0
EOF
    _install_common_tools_9
}

_setup_centos_8_repo() {
    echo "配置 CentOS 8 离线 YUM 源..."
    cat >/etc/yum.repos.d/kubeode_local.repo <<EOF
[kubeode_local]
name=Kubeode Local Repository
baseurl=http://kubeode.down.local:10086/offline/centos_8_repo/
enabled=1
gpgcheck=0
EOF
    _install_common_tools_8
}

_setup_centos_7_repo() {
    echo "配置 CentOS 7 离线 YUM 源..."
    cat >/etc/yum.repos.d/kubeode_local.repo <<EOF
[kubeode_local]
name=Kubeode Local Repository
baseurl=http://kubeode.down.local:10086/offline/centos_7_repo/
enabled=1
gpgcheck=0
EOF
    _install_common_tools_7
}

_install_common_tools_7() {
    # 清理缓存并生成新的缓存
    yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_local" makecache
    
    # 安装常用工具
    yum    install -y  --disablerepo="*" --enablerepo="kubeode_local" $rpm_list_7  
}

_install_common_tools_8() {
    # 清理缓存并生成新的缓存
    yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_local" makecache
    
    # 安装常用工具
    yum    install -y  --disablerepo="*" --enablerepo="kubeode_local" $rpm_list_8  
}
_install_common_tools_9() {
    # 清理缓存并生成新的缓存
    yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_local" makecache
    
    # 安装常用工具
    yum    install -y  --disablerepo="*" --enablerepo="kubeode_local" $rpm_list_9      
}

# 打印所有函数信息
_print_functions_info() {
    echo "Available functions in this script:"
    declare -F | awk '{print $3}' | grep '^_'
}


_setup_offline_repos_main() {
    
    _setup_python_http_server
#判断操作系统版本选择不同函数执行
    _print_functions_info
    local centos_version
    centos_version=$(_detect_centos_version)

    case $centos_version in
    7)
        _setup_centos_7_repo
        ;;
    8 | 20)
        _setup_centos_8_repo "$centos_version"
        ;;
    9 | 24 | 3 )
        _setup_centos_9_repo "$centos_version"
        ;;
    *)
        echo "不支持的 系统版本 版本：$centos_version"
        exit 1
        ;;
    esac

}

# _setup_offline_repos_main

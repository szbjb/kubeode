#!/bin/bash

# 定义全局 Kubernetes 版本号变量
KUBERNETES_VERSION="v1.31"

# 下载文件并重试最多三次
_download_with_retry() {
    local url=$1
    local output=$2
    local retries=3
    local count=0

    while [ $count -lt $retries ]; do
        curl -o "$output" "$url" && return 0
        count=$((count + 1))
        echo "下载失败，重试第 $count 次..."
    done

    echo "下载失败超过 $retries 次，脚本中断。"
    exit 1
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

# 配置 CentOS 7 的 YUM 源
_setup_centos7_repo() {
    echo "配置 CentOS 7 的 YUM 源..."

    # 检查是否已存在 kubeode_kubernetes 源
    if [ -f /etc/yum.repos.d/kubeode_kubernetes.repo ]; then
        echo "kubeode_kubernetes 源已存在，跳过配置。"
        return
    fi

    # 删除旧的 kubeode repo 文件，保留其他自定义的 repo 文件
    rm -fv /etc/yum.repos.d/kubeode_*.repo
    rm -fv /etc/yum.repos.d/CentOS-*.repo

    # 下载并重命名 CentOS Base 源
    _download_with_retry "https://mirrors.aliyun.com/repo/Centos-7.repo" "/etc/yum.repos.d/kubeode_centos.repo"
    sed -i 's/\[base\]/\[kubeode_base\]/g' /etc/yum.repos.d/kubeode_centos.repo
    sed -i 's/\[extras\]/\[kubeode_extras\]/g' /etc/yum.repos.d/kubeode_centos.repo
    sed -i 's/\[updates\]/\[kubeode_updates\]/g' /etc/yum.repos.d/kubeode_centos.repo

    # 下载并重命名 EPEL 源
    _download_with_retry "https://mirrors.aliyun.com/repo/epel-7.repo" "/etc/yum.repos.d/kubeode_epel.repo"
    sed -i 's/\[epel\]/\[kubeode_epel\]/g' /etc/yum.repos.d/kubeode_epel.repo

    # 配置 Kubernetes 源
    cat <<EOF | tee /etc/yum.repos.d/kubeode_kubernetes.repo
[kubeode_kubernetes]
name=Kubeode Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
#exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    # 清理缓存并生成新的缓存
    #yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_base,kubeode_extras,kubeode_updates,kubeode_epel,kubeode_kubernetes" makecache
    yum --disablerepo="*" --enablerepo="kubeode_base,kubeode_extras,kubeode_updates,kubeode_epel,kubeode_kubernetes" \
        install lvm2 bash-c*  nfs-utils cryptsetup iscsi-initiator-utils open-iscsi jq wget sshpass ansible ipset ipvsadm curl tar   sysstat -y   
}

# 配置 CentOS 8 和 CentOS 9 的 YUM 源
_setup_centos8_and_9_repo() {
    local centos_version=$1
    echo "配置 CentOS $centos_version 的 YUM 源..."

    # 检查是否已存在 kubeode_kubernetes 源
    if [ -f /etc/yum.repos.d/kubeode_kubernetes.repo ]; then
        echo "kubeode_kubernetes 源已存在，跳过配置。"
        return
    fi
    yum install epel-release -y

    # 删除旧的 kubeode repo 文件，保留其他自定义的 repo 文件
    rm -fv /etc/yum.repos.d/kubeode_*.repo
#临时删除autoconf包

    # 配置 Kubernetes 源
    cat <<EOF | tee /etc/yum.repos.d/kubeode_kubernetes.repo
[kubeode_kubernetes]
name=Kubeode Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
#exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    # 清理缓存并生成新的缓存
    yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_kubernetes" makecache
    #安装常用工具
    yum --enablerepo="kubeode_kubernetes" \
        install nfs-utils cryptsetup iscsi-initiator-utils open-iscsi  python3-libselinux  python3-jmespath  jq wget sshpass ansible ipset ipvsadm curl tar   sysstat -y   
}

# 打印所有函数信息
_print_functions_info() {
    echo "Available functions in this script:"
    declare -F | awk '{print $3}' | grep '^_'
}

# 主程序入口
_setup_repos_main() {
    _print_functions_info
    local centos_version
    centos_version=$(_detect_centos_version)

    case $centos_version in
    7)
        _setup_centos7_repo
        ;;
    8 | 9 | 20 | 24 | 3 )
        _setup_centos8_and_9_repo "$centos_version"
        ;;
    *)
        echo "不支持的 CentOS 版本：$centos_version"
        exit 1
        ;;
    esac
}

# 执行主程序
# _setup_repos_main

#!bin/bash
set +x

# # CentOS 7
# yum install -y jq mktemp sort printf
# yum install -y iscsi-initiator-utils
# systemctl enable --now iscsid.service

# yum install -y nfs-utils
# yum install -y cryptsetup
_env ()  {
    KUBERNETES_VERSION="v1.31"
    rpm_list="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion yum-utils  jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl  python3-libselinux python3-jmespath"
    rpm_list_openEuler="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion  jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl  python3-libselinux python3-jmespath"
    rpm_list_uos="nfs-utils cryptsetup iscsi-initiator-utils open-iscsi bash-completion  jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl  python3-libselinux python3-jmespath"
    system=$(grep  -E  PRETTY_NAME /etc/os-release |awk  -F  '='  '{print  $NF}'|sed  's/ /_/g'|sed  's/(//g'|sed  's/)//g'|sed  's/"//g'|sed  's/\//_/g')
    rpm_path="rpm_${system}"
    version_id=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)
    #打印变量
    echo "KUBERNETES_VERSION: $KUBERNETES_VERSION"
    echo "rpm_list: $rpm_list"
    echo "system: $system"
    echo "rpm_path: $rpm_path"
    echo "version_id: $version_id"
}

_load_k8s_repo ()  {
    cat <<EOF | tee /etc/yum.repos.d/kubeode_kubernetes.repo
[kubeode_kubernetes]
name=Kubeode Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF
    yum clean all
    yum makecache
}

_load_centos9_repo ()  {
yum install epel-release -y
}

_load_centos8_repo ()  {
yum install -y https://mirrors.aliyun.com/epel/epel-release-latest-8.noarch.rpm
}

_load_centos7_repo ()  {
    # 删除旧的 kubeode repo 文件，保留其他自定义的 repo 文件
    rm -fv /etc/yum.repos.d/*.repo

    # 下载并重命名 CentOS Base 源
    curl    https://mirrors.aliyun.com/repo/Centos-7.repo  > /etc/yum.repos.d/kubeode_centos.repo
    sed -i 's/\[base\]/\[kubeode_base\]/g' /etc/yum.repos.d/kubeode_centos.repo
    sed -i 's/\[extras\]/\[kubeode_extras\]/g' /etc/yum.repos.d/kubeode_centos.repo
    sed -i 's/\[updates\]/\[kubeode_updates\]/g' /etc/yum.repos.d/kubeode_centos.repo

    # 下载并重命名 EPEL 源
    curl  https://mirrors.aliyun.com/repo/epel-7.repo  > /etc/yum.repos.d/kubeode_epel.repo 
    sed -i 's/\[epel\]/\[kubeode_epel\]/g' /etc/yum.repos.d/kubeode_epel.repo
    yum clean all
    yum makecache
}   



_down_rpm ()  {
    cd /root
    mkdir -pv ./${rpm_path}
    for var in ${rpm_list}; do
        if ! yum -y install --downloadonly --downloaddir=./${rpm_path}/ ${var} 2>> ./${rpm_path}/error.log; then
            echo "Failed to download ${var}" >> ./${rpm_path}/error.log
            break
        fi
    done

    # 打印错误日志
    if [ -s ./${rpm_path}/error.log ]; then
        echo "以下软件包下载失败，详情见错误日志："
        cat ./${rpm_path}/error.log
    
    fi

cp -avr  ./${rpm_path}  /root/${rpm_path}.bak 
cd /root/${rpm_path}.bak
createrepo ./
}

_create_repo ()  {
    # 建立元数据
    yum install -y createrepo
    cd  /root/${rpm_path}/
    createrepo ./
cd /root/${rpm_path}.bak
createrepo ./
}   

#测试安装

_test_local_repo ()  {
cd   /root/${rpm_path}; pwd
# 配置离线yum源
tee /etc/yum.repos.d/kubeode_local.repo > /dev/null << EOF
[kubeode_local]
name=Local Repository
baseurl=file://$(pwd)
enabled=1
gpgcheck=0
EOF
    yum clean all
    yum --disablerepo="*" --enablerepo="kubeode_local" makecache
yum --disablerepo="*" --enablerepo="kubeode_local" install  -y  ${rpm_list}
}


_pack_rpm ()  {
yum install  -y tar  sshpass
cd /root/;
tar czvf  ${rpm_path}.tar.gz  ./${rpm_path}
}

_main ()  {
    _env    
    case $version_id in
        7)
            _load_centos7_repo;_load_k8s_repo;_down_rpm;_create_repo
            ;;
        8 )
            _load_centos8_repo;_load_k8s_repo;_down_rpm;_create_repo 
            ;;
        9 )
            _load_centos9_repo;_load_k8s_repo;_down_rpm;_create_repo
            ;;
        3 )
            _load_centos9_repo;_load_k8s_repo;_down_rpm;_create_repo
            ;;
        20 )
            export rpm_list=${rpm_list_uos}
            _load_k8s_repo;_down_rpm;_create_repo
            ;;
        24 )
            export rpm_list=${rpm_list_openEuler}
            _load_k8s_repo;_down_rpm;_create_repo
            ;;
        *)
            echo "不支持的 系统版本 版本：$centos_version"
            exit 1
            ;;
    esac

    #测试
       _test_local_repo
}

_main   











 _centos8_down_rpm () {
   ip=192.168.100.80
   password=123
   sshpass -p "${password}" scp -o StrictHostKeyChecking=no /data/auth_down_rpm/down_rpm.sh root@${ip}:/root/down_rpm.sh
   sshpass -p "${password}" ssh -o StrictHostKeyChecking=no root@${ip} "bash /root/down_rpm.sh"
   down_file=$(sshpass -p "${password}" ssh -o StrictHostKeyChecking=no root@${ip} "ls -d /root/*_repo" | xargs | awk '{print $NF}')
   sshpass -p "${password}" scp  -r   -o StrictHostKeyChecking=no root@${ip}:${down_file}  /data/auth_down_rpm/
   ls  -l ${down_file} |wc -l
#    sshpass -p "${password}" ssh -o StrictHostKeyChecking=no root@${ip} "init 0"


}

#!/bin/bash
cd /usr/local/kubeode/Shell/
pwd

#调试变量
#获取VIP地址
rm -fv ./{cluster-ips.conf,k8s-config.conf,ntp-node.conf,selected-nodes.conf}
_get_vip_ip() {
    # 获取本机的网络信息
    LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)


    # 获取网络接口地址和子网信息
    use_ip=$(ip addr | grep -Eo "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/([0-9]+)" | grep -F $LOCAL_IP | awk '{print $2}' | head -n 1)

    # 获取网段和网关信息
    network=$(echo $use_ip | cut -d'/' -f1) # 获取IP地址部分
    netmask=$(echo $use_ip | cut -d'/' -f2) # 获取子网掩码部分

    # 获取网络前三个字节
    network_prefix=$(echo $network | awk -F'.' '{print $1"."$2"."$3}')

    # 打印计算出的网段和子网信息
    echo "本机 IP: $network"
    echo "子网掩码: $netmask"
    echo "网络前缀: $network_prefix"

    # 生成可用的 IP 地址范围（假设网段从 .1 到 .254）
    available_ips=()
    for i in {1..254}; do
        available_ips+=("$network_prefix.$i")
    done

    # 尝试 3 次查找未占用的 IP 地址
    attempt=1
    while [ $attempt -le 3 ]; do
        echo "尝试第 $attempt 次查找未占用的 IP 地址..."

        # 随机选择 5 个 IP 地址进行 ping 测试
        pingable_ips=()
        echo "开始 ping 测试："
        for i in $(shuf -e "${available_ips[@]}" -n 5); do
            echo "正在 ping 测试 $i..."
            if ping -c 1 -W 1 $i &>/dev/null; then
                echo "$i 是可用的 (已占用)"
                pingable_ips+=($i)
            else
                echo "$i 是不可用的 (未占用)"
            fi
        done

        # 获取未被占用的 IP 地址
        unused_ips=()
        for ip in "${available_ips[@]}"; do
            if [[ ! " ${pingable_ips[@]} " =~ " ${ip} " ]]; then
                unused_ips+=($ip)
            fi
        done

        # 检查是否找到 2 个未被占用的 IP 地址
        if [ ${#unused_ips[@]} -ge 2 ]; then
            # 随机选择 2 个未被占用的 IP 地址
            selected_ips=$(shuf -n 2 -e "${unused_ips[@]}")

            # 将选中的 IP 地址赋值给变量
            kube_vip_ip=$(echo "$selected_ips" | head -n 1)
            nginx_vip_ip=$(echo "$selected_ips" | tail -n 1)

            echo "选中的未被占用的 IP 地址��："
            echo "kube_vip_ip: $kube_vip_ip"
            echo "nginx_vip_ip: $nginx_vip_ip"
            return 0 # 成功找到 2 个 IP 地址，退出函数
        else
            echo "未占用的 IP 地址不足 2 个，继续尝试..."
            attempt=$((attempt + 1))
        fi
    done

    # 如果 3 次都没找到足够的未占用 IP 地址，则抛出异常并退出
    echo "错误：未能找到 2 个未被占用的 IP 地址，退出..."
    exit 1
}

#初始化集群配置
_init_cluster_config() {
    # 创建ansible配置目录
    mkdir -pv /etc/ansible/

    # 配置SSH主机密钥检查为false
    # sed -i 's/#host_key_checking = False/host_key_checking = False/g' /etc/ansible/ansible.cfg
    # 获取本机IP地址
    LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)
       

    # 获取已存在的集群IP列表(排除本机IP)
    OLD_IP_LIST=$(egrep "^[0-9]" /etc/ansible/hosts | awk '{print  $1}' | sort | uniq | egrep -v $LOCAL_IP | xargs)

    # 如果LOCAL_IP为空,使用第一个IP地址
    [[ -n "$LOCAL_IP" ]] || LOCAL_IP=$(hostname -I | xargs -n 1 | head -n 1)

    # 从ansible hosts文件中获取已存在的root密码
    old_password=$(egrep  ansible_ssh_pass  /etc/ansible/hosts |awk -F =   '{print $NF}'|sed  "s/^'//g"|sed "s/'$//g")

    # 导入集群配置并显示
    ./k8s-ip-config -i "${LOCAL_IP} ${OLD_IP_LIST}" -p "${old_password}" -s 22 && source  /usr/local/kubeode/Shell/cluster-ips.conf
    cat /usr/local/kubeode/Shell/cluster-ips.conf
}

#生成集群节点配置
_generate_cluster_nodes_config() {
    # 从配置文件中获取集群IP列表并排序
    source /usr/local/kubeode/Shell/cluster-ips.conf
    cluster_ips_all=$(echo $CLUSTER_IPS | tr ' ' '\n' | sort -t '.' -k1,1n -k2,2n -k3,3n -k4,4n)

    # 将本机IP移到列表的最前面
    sorted_ips=($LOCAL_IP)
    for ip in $cluster_ips_all; do
        if [ "$ip" != "$LOCAL_IP" ]; then
            sorted_ips+=($ip)
        fi
    done
    # 将排序后的IP列表转换为单行字符串
    cluster_ips=$(echo ${sorted_ips[@]} | tr ' ' '\n' | xargs)
    #按列表取前三个
    cluster_ips_master=$(echo $cluster_ips | awk '{print $1,$2,$3}')
    # 打印排序后的IP列表
    echo "排序后的IP列表：$cluster_ips"
    echo "master节点：$cluster_ips_master"
    echo "worker节点：$cluster_ips"

    ./multi-select-dialog \
        --list1 "$cluster_ips" \
        --list2 "$cluster_ips" \
        --preselect1 "$cluster_ips_master" \
        --preselect2 "$cluster_ips" \
        --primary-var "MY_PRIMARY_NODE" \
        --backup-var "MY_WORKER_NODE" \
        --title "选择kubernetes集群节点" \
        --output "./selected-nodes.conf" \
        --primary-label "control-plane节点" \
        --backup-label "worker节点"
}

#选中k8s集群存储节点
_select_storage_node() {

    ./multi-select-dialog \
        --list1 "$cluster_ips" \
        --list2 "$cluster_ips" \
        --preselect1 "$cluster_ips_master" \
        --preselect2 "$cluster_ips_master" \
        --primary-var "MY_INGRESS_NODE" \
        --backup-var "MY_STORAGE_NODE" \
        --title "选择ingress节点~k8s集群sc存储节点" \
        --output "./selected-nodes-storage.conf" \
        --primary-label "ingress节点" \
        --backup-label "sc存储节点"
}

#选中ntp server节点
_select_ntp_server_node() {
    LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)

    source /usr/local/kubeode/Shell/cluster-ips.conf
    cluster_ips_all=$(echo $CLUSTER_IPS | tr ' ' '\n' | sort -t '.' -k1,1n -k2,2n -k3,3n -k4,4n | xargs)
    ./k8s-node-single-select \
        --ip-list "$cluster_ips_all" \
        --title "选择NTP时间同步server节点" \
        --prompt "请选择ntp server节点:      tab键切换，到确认键回车确认 " \
        --default "$LOCAL_IP" \
        --output "./ntp-node.conf"
}

#生成k8s配置
_generate_k8s_config() {
    # 先获取VIP地址
    OLD_VIRTUAL_IPADDRESS=$(egrep HAClusterVIP /etc/ansible/hosts | awk '{print $NF}' |egrep  [0-9])
    # 添加判断逻辑
    [ -z "$OLD_VIRTUAL_IPADDRESS" ] && _get_vip_ip || kube_vip_ip=$OLD_VIRTUAL_IPADDRESS

    # 先获取ingres域名地址
    OLD_DOMAIN_NAME=$(egrep IngressDomain /etc/ansible/hosts | awk '{print  $NF}')
    DOMAIN_DEFAULT="kubeode.com"
    DOMAIN_NAME=${OLD_DOMAIN_NAME:-$DOMAIN_DEFAULT}
    # 添加判断逻辑
    # 使用k8s-tui工具生成配置
    ./k8s-tui \
        --runtime "containerd:/var/lib/containerd docker:/var/lib/docker  crio:/var/lib/containers  " \
        --default-runtime "docker" \
        --storage-solution "minio:/var/lib/minio openebs:/var/openebs nfs:/var/lib/nfs" \
        --default-storage "openebs" \
        --pod-cidr "10.244.0.0/16" \
        --service-cidr "10.96.0.0/12" \
        --vip "${kube_vip_ip}" \
        --domain "${DOMAIN_NAME}" \
        --output "k8s-config.conf" \
        --pod-cidr-help "Pod网络CIDR (例如: 10.244.0.0/16)" \
        --service-cidr-help "Service网络CIDR (例如: 10.96.0.0/12)" \
        --vip-help "Kubernetes VIP地址，用于API Server负载均衡" \
        --domain-help "nginx ingress 对外域名 (例如: kubeode.com)" \
        --additional-info "tab键切换，方向键选择切换，回车键确认 \\n新手请使用默认配置" \
        --info-x 60 \
        --info-y 15

    # 显示并加载生成的配置文件
    cat ./k8s-config.conf && source ./k8s-config.conf
}

#导入变量配置文件
_source_config() {
source /usr/local/kubeode/Shell/cluster-ips.conf
source ./k8s-config.conf
source ./ntp-node.conf
source ./selected-nodes.conf    
source ./selected-nodes-storage.conf  
    NTP_SERVER=${SELECTED_NODE}
    echo "NTP_SERVER: $NTP_SERVER"
}

#导入Ip到ansible
_import_ip_to_ansible() {
    tee >/etc/ansible/hosts <<EOF
# 全局变量
[all:vars]
#ansible_python_interpreter=/usr/bin/python
ansible_ssh_pass='${ROOT_PASSWORD}'
ansible_ssh_port='${SSHD_PORT}'
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_user=root
#[runtime]  $RUNTIME
#[image_storage_path]  $RUNTIME_PATH   
#[IngressDomain] $DOMAIN_NAME
#[PodCIDR]  $POD_CIDR
#[ServiceCIDR]  $SERVICE_CIDR
#[STORAGE_SOLUTION] $(echo $STORAGE_SOLUTION)
#[StoragePath] $(echo $SC_STORAGE_PATH)
#[HAClusterVIP] $KUBE_VIP
[all]
$(echo $CLUSTER_IPS | xargs -n 1) 
[kube_master]
$(echo $MY_PRIMARY_NODE | xargs -n 1 ) 
[kube_node]
$(echo $MY_WORKER_NODE | xargs -n 1 ) 
[StorageHosts]
$(echo $MY_STORAGE_NODE | xargs -n 1 ) 
[INgressHosts]
$(echo $MY_INGRESS_NODE | xargs -n 1 ) 
[ntp_server]
$(echo $NTP_SERVER | xargs -n 1 ) 
EOF
}

sleep 0.5

#集群连通性ssh检查
_check_ssh_connectivity() {
    for var in ${CLUSTER_IPS}; do
        sshpass -p "$ROOT_PASSWORD" ssh root@$var -p${SSHD_PORT} -o StrictHostKeyChecking=no "hostname -I" || {
            echo "${var} ssh连接障,安装中断，请检查$var root密码/网络连通状态。"
            exit 1
        }
    done
}

echo -e "
    _get_vip_ip                    # 获取VIP地址
    _init_cluster_config           # 初始化集群配置
    _generate_cluster_nodes_config # 生成集群节点配置
    _select_storage_node           #选中k8s集群存储节点 ingress节点
    _select_ntp_server_node        # 选中NTP server节点
    _generate_k8s_config           # 生成Kubernetes配置
    _source_config                 # 导入变量配置文件
    _import_ip_to_ansible          # 导入IP到Ansible
    _check_ssh_connectivity        # 集群连通性SSH检查
"

_init_env() {

    # _get_vip_ip                    # 获取VIP地址
    _init_cluster_config           # 初始化集群配置
    _generate_cluster_nodes_config # 生成集群节点配置
    _select_storage_node           #选中k8s集群存储节点 ingress节点
    _select_ntp_server_node        # 选中NTP server节点
    _generate_k8s_config           # 生成Kubernetes配置
    _source_config                 # 导入变量配置文件
    _import_ip_to_ansible          # 导入IP到Ansible
    _check_ssh_connectivity        # 集群连通性SSH检查
}

# _init_env
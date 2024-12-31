#!/bin/bash
LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1 )

##首次安装

_install_k8s() {
  ansible-playbook \
    -i "localhost," \
    --connection=local \
    --extra-vars "kv_version=v0.8.6" \
    /usr/local/kubeode/playbooks/A03_k8s_install.yml
    clear
    kubectl get pods,nodes -A  -o wide
}
_install_k8s_offline() {
  ansible-playbook \
    -i "localhost," \
    --connection=local \
    --extra-vars "kv_version=v0.8.6 download_type=offline" \
    /usr/local/kubeode/playbooks/A03_k8s_install.yml
    clear
    kubectl get pods,nodes -A  -o wide
}

#镜像仓库初始化 
_registry_setup() {
  ansible-playbook \
    -i "localhost," \
    --connection=local \
    /usr/local/kubeode/playbooks/A06_registry_setup.yml
}

#在线新增节点repo初始化
_add_node_repo_init() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi

  #查询当前集群使用的节点ip赋值变量
  now_cluster_ip=$(kubectl get nodes -o wide | awk '{print $6}' | egrep -v INTERNAL-IP | xargs)
  ansible $node_ip -m copy -a 'src=/usr/local/kubeode/Shell/repo/setup_online_repos.sh dest=/tmp/setup_online_repos.sh mode=0755'
  ansible $node_ip -m shell -a 'source /tmp/setup_online_repos.sh && _setup_repos_main'
}
#离线新增节点repo初始化
_add_node_repo_init_offline() {
  rpm_list=" bash-completion jq wget sshpass ansible ipset ipvsadm curl tar  sysstat  createrepo lvm2  tree conntrack iptables libseccomp  psmisc  kubelet kubeadm kubectl  python3-libselinux python3-jmespath"

  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi
#私有镜像仓库hosts解析  增加kubeode.down.local到hosts
  time ansible all -m shell -a "sed /registry.kubeode.down.local/d /etc/hosts -i; sleep 0.2; echo '${LOCAL_IP}   kubeode.registry.local ghcr.io k8s.gcr.io quay.io registry-1.docker.io registry.k8s.io registry.kubeode.down.local kubeode.down.local' >> /etc/hosts"
  #查询当前集群使用的节点ip赋值变量
  now_cluster_ip=$(kubectl get nodes -o wide | awk '{print $6}' | egrep -v INTERNAL-IP | xargs)
  ansible $node_ip -m copy -a 'src=/etc/yum.repos.d/kubeode_local.repo dest=/etc/yum.repos.d/kubeode_local.repo'
ansible all -m shell -a "yum --disablerepo=\"*\" --enablerepo=\"kubeode_local\" install  $rpm_list -y"
  ansible $node_ip -m shell -a 'yum --disablerepo="*" --enablerepo="kubeode_local" makecache'
ansible $node_ip -m shell -a  ' yum --disablerepo="*" --enablerepo="kubeode_local" \
        install   jq wget sshpass ansible ipset ipvsadm curl tar  sysstat -y   '
ansible $node_ip -m shell -a  ' yum --disablerepo="*" --enablerepo="kubeode_local" \
        install libselinux-python python3-jmespath  -y  '
ansible $node_ip -m shell -a  ' yum --disablerepo="*" --enablerepo="kubeode_local" \
        install libselinux-python python3-jmespath  -y  '
ansible $node_ip -m shell -a  ' yum --disablerepo="*" --enablerepo="kubeode_local" \
        install python3-libselinux  -y   '
}

#新增节点os初始化
_add_node_os_init() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi
  time ansible-playbook /usr/local/kubeode/playbooks/A01_os_init.yml --limit $node_ip
}

#新增节点docker初始化
_add_node_docker_init() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi
  os_release_tmp=$(ansible $node_ip -m shell -a "grep '^VERSION_ID=' /etc/os-release | awk -F'\"' '{print \$2}' | cut -d '.' -f1")
  os_release=$(echo $os_release_tmp | awk '{print  $NF}')

  # ansible-playbook \
  #   -e "docker_version=27.3.1 cri_dockerd_version=0.3.15" \
  #   --extra-vars "install_method=online ansible_distribution_major_version=${os_release}" \
  #   /usr/local/kubeode/playbooks/A02_k8s_setup_docker.yml --limit $node_ip

  ansible-playbook \
    -e "docker_version=27.3.1 cri_dockerd_version=0.3.15" \
    --extra-vars "ansible_distribution_major_version=${os_release}" \
    /usr/local/kubeode/playbooks/A02_k8s_setup_docker.yml --limit $node_ip

}

#新增节点docker 离线初始化
_add_node_docker_init_offline() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi
  os_release_tmp=$(ansible $node_ip -m shell -a "grep '^VERSION_ID=' /etc/os-release | awk -F'\"' '{print \$2}' | cut -d '.' -f1")
  os_release=$(echo $os_release_tmp | awk '{print  $NF}')

  ansible-playbook \
    -e "docker_version=27.3.1 cri_dockerd_version=0.3.15" \
    --extra-vars "install_method=offline ansible_distribution_major_version=${os_release}" \
    /usr/local/kubeode/playbooks/A02_k8s_setup_docker.yml --limit $node_ip

}

#增加控制节点
_add_control_plane() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi

  ansible-playbook /usr/local/kubeode/playbooks/A04_k8s_add_control_plane.yml \
    --limit "${node_ip}" \
    --extra-vars "\
runtime=docker \
local_ip=${LOCAL_IP} \
add_control_plane_nodes=${node_ip}
"
  clear
  kubectl get pods,nodes -A  -o wide
}

#增加node节点
_add_node() {
  local node_ip=$1

  if [ -z "$node_ip" ]; then
    echo "错误: 请提供节点IP地址作为参数"
    return 1
  fi

  ansible-playbook /usr/local/kubeode/playbooks/A05_k8s_add_node.yml \
    --extra-vars "\
runtime=docker \
local_ip=${LOCAL_IP} \
add_worker_nodes=${node_ip}
"
  clear
  kubectl get pods,nodes -A  -o wide 
} 

# 从 /etc/ansible/hosts 文件中加载全局变量
load_global_vars() {
  # 使用临时文件来存储 grep 的输出
  temp_file=$(mktemp)
  grep -E "ansible_ssh_pass|ansible_ssh_port|ansible_ssh_common_args" /etc/ansible/hosts >"$temp_file"

  while IFS= read -r line; do
    case "$line" in
    ansible_ssh_pass=*)
      GLOBAL_SSH_PASS="${line#*=}"
      ;;
    ansible_ssh_port=*)
      GLOBAL_SSH_PORT="${line#*=}"
      ;;
    ansible_ssh_common_args=*)
      GLOBAL_SSH_ARGS="${line#*=}"
      ;;
    esac
  done <"$temp_file"

  # 删除临时文件
  rm -f "$temp_file"
}

# 新增节点到/etc/ansible/hosts
_add_node_to_hosts() {
  # 加载全局变量
  load_global_vars

  # 从 cluster-ips.conf 文件中加载变量
  source /usr/local/kubeode/Shell/cluster-ips.conf

  # 定义要添加的 IP
  IFS=' ' read -r -a IP_ARRAY <<<"$CLUSTER_IPS" # 将多个 IP 地址分割成数组

  # 传入的参数（从 cluster-ips.conf 中读取）
  ansible_ssh_pass="$ROOT_PASSWORD"                     # 从配置文件中读取密码
  ansible_ssh_port="$SSHD_PORT"                         # 从配置文件中读取端口
  ansible_ssh_common_args="-o StrictHostKeyChecking=no" # 确保添加此行

  # 函数：检查并添加 IP 到指定组
  add_ip_if_not_exists() {
    local group="$1"
    local ip="$2"
    local extra_info=""

    # 检查 SSH 密码和端口是否一致
    if [[ "$ansible_ssh_pass" != "$GLOBAL_SSH_PASS" ]]; then
      extra_info+=" ansible_ssh_pass='$ansible_ssh_pass'"
    fi
    if [[ "$ansible_ssh_port" != "$GLOBAL_SSH_PORT" ]]; then
      extra_info+=" ansible_ssh_port='$ansible_ssh_port'"
    fi
    if [[ "$ansible_ssh_common_args" != "$GLOBAL_SSH_ARGS" ]]; then
      extra_info+=" ansible_ssh_common_args='$ansible_ssh_common_args'"
    fi

    # 检查指定组是否存在该 IP
    if ! sed -n "/\[$group\]/,/^\[/p" /etc/ansible/hosts | grep -q "$ip"; then
      if [[ -n "$extra_info" ]]; then
        sed -i "/\[$group\]/a $ip$extra_info" /etc/ansible/hosts
      else
        sed -i "/\[$group\]/a $ip" /etc/ansible/hosts
      fi
    fi
  }

  # 遍历 IP 数组并添加到 [all] 和 [kube_master] 部分
  for ip in "${IP_ARRAY[@]}"; do
    sed -i "/$ip/d" /etc/ansible/hosts
    add_ip_if_not_exists "all" "$ip"
    add_ip_if_not_exists "kube_master" "$ip"
  done
}

#删除节点
_delete_node() {
  NODE_IP=$(kubectl get nodes -o wide | awk '{print  $6}' | egrep -v INTERNAL-IP)
  DELETE_NODE=$(whiptail --title "删除节点" --checklist "请选择要删除的节点IP，使用空格选择多个" 20 60 10 \
    $(echo "$NODE_IP" | awk '{print $1 " " $1 " OFF"}') 3>&1 1>&2 2>&3)
  DELETE_NODE=$(echo $DELETE_NODE | sed 's/"//g')
  # 删除节点
  for var in $DELETE_NODE; do
    kubectl delete node $(kubectl get nodes -o wide | grep $var | awk '{print  $1}')
  done
  #删除etcd节点
  del_etcd_node=$(echo $DELETE_NODE | xargs | sed 's/ /|/g')
  ETCD_NODE=$(etcdctl --endpoints=https://${LOCAL_IP}:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key member list | egrep $del_etcd_node | awk '{print  $1}' | sed 's/,//g')
  if [ -n "$ETCD_NODE" ]; then
    etcdctl --endpoints=https://${LOCAL_IP}:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key member remove $ETCD_NODE
  fi
  #删除/etc/ansible/hosts节点
  for var in $DELETE_NODE; do
    sed -i "/$var/d" /etc/ansible/hosts
  done
}

# 获取当前最大主机名序号
_get_max_hostname_index() {
  max_index=$(kubectl get nodes | awk '{print $1}' | egrep -v NAME | sed 's/[^0-9]*//g' | sort -n | tail -n 1)
  echo $max_index
}

# 设置新增节点的主机名
_set_new_node_hostnames() {
  local max_index=$(_get_max_hostname_index)
  local new_index=$((max_index + 1))
  source /usr/local/kubeode/Shell/cluster-ips.conf
  sorted_ips=$(echo $CLUSTER_IPS | xargs)

  for ip in $sorted_ips; do
    # 检查节点连通性
    if ! ansible $ip -m ping; then
      whiptail --title "连接错误" --msgbox "无法连接到节点 $ip。请检查密码或网络连接。" 10 60
      exit 1
    fi

    hostname="node$(printf "%02d" $new_index)"
    echo "Setting hostname for IP $ip to $hostname"

    # 使用 Ansible 设置主机名
    ansible $ip -m shell -a "hostnamectl set-hostname  $hostname"
    ansible $ip -m shell -a "sed -i \"/$hostname/d\" /etc/hosts"
    ansible $ip -m shell -a "echo $ip   $hostname >> /etc/hosts"

    new_index=$((new_index + 1))
  done
}

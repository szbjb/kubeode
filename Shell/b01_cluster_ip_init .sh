#!/bin/bash

_get_vip_ip () {
  # 获取本机的网络信息
  LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)


  # 获取网络接口地址和子网信息
  use_ip=$(ip addr | grep -Eo "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/([0-9]+)" | grep -F $LOCAL_IP | awk '{print $2}' | head -n 1)

  # 获取网段和网关信息
  network=$(echo $use_ip | cut -d'/' -f1)   # 获取IP地址部分
  netmask=$(echo $use_ip | cut -d'/' -f2)   # 获取子网掩码部分

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

      echo "选中的未被占用的 IP 地址是："
      echo "kube_vip_ip: $kube_vip_ip"
      echo "nginx_vip_ip: $nginx_vip_ip"
      return 0  # 成功找到 2 个 IP 地址，退出函数
    else
      echo "未占用的 IP 地址不足 2 个，继续尝试..."
      attempt=$((attempt + 1))
    fi
  done

  # 如果 3 次都没找到足够的未占用 IP 地址，则抛出异常并退出
  echo "错误：未能找到 2 个未被占用的 IP 地址，退出..."
  exit 1
}

_set_cluster_info () {
  # 默认值
  DOMAIN_NAME="example.com"
  K8S_POD_CIDR="100.64.0.0/10"  # Pod 网络段
  K8S_SERVICE_CIDR="10.96.0.0/12"  # Service 网络段
  STORAGE_CLASSES_STORAGE_HOSTPATH="/data/storage"
  VIRTUAL_IPADDRESS="192.168.100.100"
  IP_LIST="192.168.100.1 192.168.100.2"
  KUBE_MASTER="192.168.100.10"
  KUBE_NODE="192.168.100.20 192.168.100.30"
  STORAGE_LIST="192.168.100.40"
  NTP_SERVER="192.168.100.50"
  password="your_password_here"
  SSHD_PORT=

  # 如果没有传递任何参数，则打印示例并退出
  if [[ "$#" -eq 0 ]]; then
    echo "No parameters passed. Please specify the parameters as follows:"
    _print_example_usage
    return 1  # 提前退出，防止写入 hosts 文件
  fi

  # 解析命令行参数
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --set)
        shift
        # 处理--set参数后面的变量和赋值
        IFS='=' read -r key value <<< "$1"
        value=${value//\"/}  # 移除双引号
        if [ -z "$value" ]; then
          # 如果值为空，打印示例命令并退出
          echo "Error: Missing value for --set $key. Please provide a valid value."
          _print_example_usage
          exit 1
        fi
        case "$key" in
          DOMAIN_NAME) export DOMAIN_NAME="$value" ;;
          K8S_POD_CIDR) export K8S_POD_CIDR="$value" ;;
          K8S_SERVICE_CIDR) export K8S_SERVICE_CIDR="$value" ;;
          STORAGE_CLASSES_STORAGE_HOSTPATH) export STORAGE_CLASSES_STORAGE_HOSTPATH="$value" ;;
          VIRTUAL_IPADDRESS) export VIRTUAL_IPADDRESS="$value" ;;
          IP_LIST) export IP_LIST="$value" ;;
          KUBE_MASTER) export KUBE_MASTER="$value" ;;
          KUBE_NODE) export KUBE_NODE="$value" ;;
          STORAGE_LIST) export STORAGE_LIST="$value" ;;
          NTP_SERVER) export NTP_SERVER="$value" ;;
          password) export password="$value" ;;
          SSHD_PORT) export SSHD_PORT="$value" ;;
          *) echo "Unknown parameter $key"; exit 1 ;;
        esac
        shift
        ;;
      *)
        echo "Unknown option $1"
        exit 1
        ;;
    esac
  done

  # 输出当前变量的值
  echo "DOMAIN_NAME: $DOMAIN_NAME"
  echo "K8S_POD_CIDR: $K8S_POD_CIDR"
  echo "K8S_SERVICE_CIDR: $K8S_SERVICE_CIDR"
  echo "STORAGE_CLASSES_STORAGE_HOSTPATH: $STORAGE_CLASSES_STORAGE_HOSTPATH"
  echo "VIRTUAL_IPADDRESS: $VIRTUAL_IPADDRESS"
  echo "IP_LIST: $IP_LIST"
  echo "KUBE_MASTER: $KUBE_MASTER"
  echo "KUBE_NODE: $KUBE_NODE"
  echo "STORAGE_LIST: $STORAGE_LIST"
  echo "NTP_SERVER: $NTP_SERVER"
  echo "password: $password"
  echo "SSHD_PORT: $SSHD_PORT"

  # 生成 Ansible hosts 文件
  cat >/etc/ansible/hosts <<EOF
#[IngressDomain] $DOMAIN_NAME
#[PodCIDR]  $K8S_POD_CIDR
#[ServiceCIDR]  $K8S_SERVICE_CIDR
#[StoragePath] $(echo $STORAGE_CLASSES_STORAGE_HOSTPATH)
#[HAClusterVIP] $VIRTUAL_IPADDRESS
[all]
$(echo $IP_LIST | xargs -n 1 | awk "{print \$0\"  ansible_ssh_pass='${password}'\"}" | awk "{print \$0\"  ansible_ssh_port=${SSHD_PORT}\"}")
[kube_master]
$(echo $KUBE_MASTER | xargs -n 1 | awk "{print \$0\"  ansible_ssh_pass='${password}'\"}" | awk "{print \$0\"  ansible_ssh_port=${SSHD_PORT}\"}")
[kube_node]
$(echo $KUBE_NODE | xargs -n 1 | awk "{print \$0\"  ansible_ssh_pass='${password}'\"}" | awk "{print \$0\"  ansible_ssh_port=${SSHD_PORT}\"}")
[StorageHosts]
$(echo $STORAGE_LIST | xargs -n 1 | awk "{print \$0\"  ansible_ssh_pass='${password}'\"}" | awk "{print \$0\"  ansible_ssh_port=${SSHD_PORT}\"}")
[ntp_server]
$(echo $NTP_SERVER | xargs -n 1 | awk "{print \$0\"  ansible_ssh_pass='${password}'\"}" | awk "{print \$0\"  ansible_ssh_port=${SSHD_PORT}\"}")
EOF
}

# 打印示例命令
_print_example_usage () {
  _get_vip_ip  
  LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)

  
  echo "Usage example for passing parameters:"
  echo -e "
  kubeode \\
  --set DOMAIN_NAME=\"mydomain.com\" \\
  --set K8S_POD_CIDR=\"100.64.0.0/10\" \\
  --set K8S_SERVICE_CIDR=\"10.96.0.0/12\" \\
  --set STORAGE_CLASSES_STORAGE_HOSTPATH=\"/data/custom_storage\" \\
  --set VIRTUAL_IPADDRESS=\"${kube_vip_ip}\" \\
  --set IP_LIST=\"${LOCAL_IP}\" \\
  --set KUBE_MASTER=\"${LOCAL_IP}\" \\
  --set KUBE_NODE=\"${LOCAL_IP}\" \\
  --set STORAGE_LIST=\"${LOCAL_IP}\" \\
  --set NTP_SERVER=\"${LOCAL_IP}\" \\
  --set password=\"123\" \\
  --set SSHD_PORT=22"
}


# 调用函数
_set_cluster_info "$@"

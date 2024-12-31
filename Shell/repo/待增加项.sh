download_etcd() {
   # 获取最新的10个版本
   versions=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 10)

   # 打印版本信息
   echo "Available versions:"
   echo "$versions"

   # 如果有传参，下载指定版本；否则下载最新版本
   if [ -n "$1" ]; then
      version=$1
   else
      version=$(echo "$versions" | head -n 1)
   fi

   echo "Downloading etcd version: $version"

   # 下载指定版本
   wget https://github.com/etcd-io/etcd/releases/download/$version/etcd-$version-linux-amd64.tar.gz

   # 直接解压 etcdctl 和 etcdutl 到 /usr/bin/
   tar --strip-components=1 -xvf etcd-$version-linux-amd64.tar.gz -C /usr/bin/ etcd-$version-linux-amd64/etcdctl etcd-$version-linux-amd64/etcdutl
}
download_etcd

# 调用函数，传入版本号作为参数（如果需要）
# download_etcd v3.5.9


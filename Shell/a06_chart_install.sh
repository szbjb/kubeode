#!/bin/bash 
pwd
cd /usr/local/kubeode/Shell/
source /usr/local/kubeode/Shell/cluster-ips.conf



#tui菜单多选
_tui_menu() {
    echo "1. helm chart软件包 安装"
    echo "2. helm chart软件包 卸载"
    read -p "请输入选项: " choice
    case $choice in
        1) _helm_chart_install;;
        2) _helm_chart_uninstall;;
        *) echo "无效选项";;
    esac
}

#helm chart软件包 安装
_helm_chart_install() {
    ansible-playbook \
    -i "localhost," \
    --connection=local \
    /usr/local/kubeode/playbooks/A06_helm_chart_install.yml
}


# 获取所有 master 节点并移除污点
_remove_master_taint() {
  node_list=$(kubectl  get nodes|awk   '{print  $1}'|egrep  -v  NAME|xargs)
    kubectl get nodes --selector='node-role.kubernetes.io/control-plane' -o name | xargs -I{} kubectl taint {} node-role.kubernetes.kubernetes.io/control-plane:NoSchedule-
    
    kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, taints: .spec.taints}'
    for node in $node_list; do
        kubectl taint node $node node-role.kubernetes.io/control-plane:NoSchedule-
        kubectl describe node $node | grep -i taints
    done

    echo "master节点污点已移除"
}

#nginx ingress 安装
_nginx_ingress_install() {
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade nginx-ingress --install  -n kube-system  bitnami/nginx-ingress-controller \
--create-namespace -n kube-system  \
--set "
service.type=NodePort,\
service.nodePorts.http=32080,\
defaultBackend.service.type=NodePort,\
"
}

#安装sc存储

#openEBS

# 使用裸盘安装，假设要使用的裸盘是/dev/sdb
helm install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --set openebsNDM.enabled=true \
  --set openebsNDM.sparse.path="/dev/sdb" \
  --set openebsNDM.sparse.size=10Gi \
  --set openebsNDM.sparse.count=1



helm repo add openebs https://openebs.github.io/charts
helm repo update

# 指定本地存储路径
helm install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --set openebsNDM.enabled=false \
  --set localprovisioner.basePath="/opt/openebs/local" \
  --set localprovisioner.enabled=true



_sc_storage_install_openebs() {
helm repo add openebs https://openebs.github.io/charts
kubectl  create ns openebs
mkdir -pv /sata_ssd/openebs/openebs/local
mkdir -pv  /sata_ssd/openebs/openebs
helm install storage-openebs openebs/openebs  -n openebs   --set "
localprovisioner.basePath=/sata_ssd/openebs/openebs/local
jiva.defaultStoragePath=/sata_ssd/openebs/openebs
"
#取消默认存储类
kubectl patch storageclass longhorn -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": null}}}'
#设置默认存储类
kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
kubectl  get storageclasses.storage.k8s.io
#检查
while  [ true ] ; do sleep  3;clear ; kubectl  get pods -A  -o wide|egrep   0/ ||  break ; done
}


_sc_storage_install() {
  #选择方案
  storage_solution=$(grep  STORAGE_SOLUTION  /etc/ansible/hosts |awk   '{print  $NF}')
  case $storage_solution in
    openebs) _sc_storage_install_openebs;;
    ceph) _sc_storage_install_ceph;;
    *) echo "无效选项";;
  esac

    helm upgrade sc-storage --install  \
    --create-namespace -n kube-system  \
    --set "
    service.type=NodePort,\
    service.nodePorts.http=32080,\
    defaultBackend.service.type=NodePort,\
    "
}




# 查看当前节点
kubectl get nodes

# 给节点打标签
kubectl label nodes node01 storage=minio

# 验证标签
kubectl get nodes --show-labels | grep storage

# 添加 MinIO 仓库
helm repo add minio https://charts.min.io/
helm repo update

# 创建命名空间
kubectl create namespace minio-system
# 1. 先卸载当前安装
helm uninstall minio -n minio-system

# 2. 删除现有的 PVC
kubectl delete pvc --all -n minio-system

# 3. 创建本地存储的 StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# 4. 创建 PV
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-local-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /minio/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node01  # 替换为您的节点名称
EOF

# 5. 重新安装 MinIO
helm install minio minio/minio \
  --namespace minio-system \
  --set mode=standalone \
  --set persistence.enabled=true \
  --set persistence.size=100Gi \
  --set persistence.storageClass=local-storage \
  --set resources.requests.memory=1Gi \
  --set resources.requests.cpu=500m \
  --set resources.limits.memory=2Gi \
  --set resources.limits.cpu=1 \
  --set rootUser=admin \
  --set rootPassword=Admin@123 \
  --set service.type=NodePort \
  --set api.nodePort=32000 \
  --set console.enabled=true \
  --set console.nodePort=32001 \
  --set environment.MINIO_BROWSER=on \
  --set mountPath=/data \
  --set nodeSelector."storage"="minio"


  kubectl get pv,pvc,pods -n minio-system


  # 检查 Pod 是否在正确的节点上运行
kubectl get pods -n minio-system -o wide












#集群至少4个节点
# 卸载现有单机版本
helm uninstall minio -n minio-system

# 安装分布式版本 MinIO
helm install minio minio/minio \
  --namespace minio-system \
  --set mode=distributed \  # 改为分布式模式
  --set replicas=3 \        # 设置副本数
  --set persistence.enabled=true \
  --set persistence.size=100Gi \
  --set persistence.storageClass=local-storage \
  --set resources.requests.memory=1Gi \
  --set resources.requests.cpu=500m \
  --set resources.limits.memory=2Gi \
  --set resources.limits.cpu=1 \
  --set rootUser=admin \
  --set rootPassword=Admin@123 \
  --set service.type=NodePort \
  --set api.nodePort=32000 \
  --set console.enabled=true \
  --set console.nodePort=32001 \
  --set environment.MINIO_BROWSER=on \
  --set mountPath=/data \
  --set nodeSelector."storage"="minio" \
  --set zones[0].name=zone-0 \
  --set zones[0].servers=3    # 每个区域的服务器数量


  # 扩容到 5 个节点
helm upgrade minio minio/minio \
  --namespace minio-system \
  --reuse-values \
  --set replicas=5


  # 给新节点添加存储标签
kubectl label nodes node02 storage=minio
kubectl label nodes node03 storage=minio




#ninio接入sc

# 创建 StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-sc
provisioner: minio.storage.k8s.io  # MinIO 存储提供者
parameters:
  endpoint: http://minio.minio-system.svc.cluster.local:9000  # MinIO 服务地址
  bucket: k8s-storage  # MinIO bucket 名称
  accessKeyId: admin  # MinIO 访问密钥
  secretAccessKey: Admin@123  # MinIO 访问密钥
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF





# 使用 MinIO Client (mc) 配置


# 一步步执行命令

kubectl exec -it -n minio-system $(kubectl get pods -n minio-system -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc alias set myminio http://localhost:9000 admin Admin@123

kubectl exec -it -n minio-system $(kubectl get pods -n minio-system -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc mb myminio/k8s-storage

# 验证 bucket 创建
kubectl exec -it -n minio-system $(kubectl get pods -n minio-system -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls myminio


#创建 MinIO CSI 驱动所需的密钥：

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-creds
  namespace: kube-system
type: Opaque
stringData:
  accesskey: admin
  secretkey: Admin@123
EOF


#创建 StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: minio.csi.k8s.io
parameters:
  endpoint: minio.minio-system.svc.cluster.local:9000
  bucket: k8s-storage
  secretName: minio-creds
  secretNamespace: kube-system
  useSSL: "false"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

#创建 PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-minio-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: minio-sc
---
apiVersion: v1
kind: Pod
metadata:
  name: test-minio-pod
spec:
  containers:
  - name: test-container
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date) >> /data/test.txt; sleep 5; done"]
    volumeMounts:
    - name: minio-storage
      mountPath: /data
  volumes:
  - name: minio-storage
    persistentVolumeClaim:
      claimName: test-minio-pvc
EOF


#验证
# 检查 PVC 状态
kubectl get pvc

# 检查 Pod 状态
kubectl get pods

# 如果有问题，查看详细信息
kubectl describe pvc test-minio-pvc
kubectl describe pod test-minio-pod





## 添加 MinIO CSI 驱动的 Helm 仓库
helm repo add minio-csi https://minio.github.io/csi-driver/
helm repo update

# 安装 MinIO CSI 驱动
helm install minio-csi minio-csi/csi-driver \
  --namespace kube-system \
  --set identity.name=minio.csi.k8s.io \
  --set identity.version=v1 \
  --set identity.namespace=kube-system

  # 检查 CSI 驱动 pod 是否运行
kubectl get pods -n kube-system | grep csi


cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: minio.csi.k8s.io
parameters:
  endpoint: http://minio.minio-system.svc.cluster.local:9000  # 添加 http://
  bucket: k8s-storage
  secretName: minio-creds
  secretNamespace: kube-system
  useSSL: "false"
  # 添加以下参数
  versions: "true"
  pathStyle: "true"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF


# 删除之前的测试资源
kubectl delete pvc test-minio-pvc
kubectl delete pod test-minio-pod

# 重新创建测试资源
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-minio-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: minio-sc
---
apiVersion: v1
kind: Pod
metadata:
  name: test-minio-pod
spec:
  containers:
  - name: test-container
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date) >> /data/test.txt; sleep 5; done"]
    volumeMounts:
    - name: minio-storage
      mountPath: /data
  volumes:
  - name: minio-storage
    persistentVolumeClaim:
      claimName: test-minio-pvc
EOF


# Download DirectPV plugin.
release=$(curl -sfL "https://api.github.com/repos/minio/directpv/releases/latest" | awk '/tag_name/ { print substr($2, 3, length($2)-4) }')
curl -fLo kubectl-directpv https://github.com/minio/directpv/releases/download/v${release}/kubectl-directpv_${release}_linux_amd64
#Make the binary executable.
chmod a+x kubectl-directpv
mv kubectl-directpv /usr/local/bin/kubectl-directpv
















#LonghornLonghorn
# 1. 安装 Longhorn
helm repo add longhorn https://charts.longhorn.io
helm repo update
# 安装时可以指定存储路径
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClass.enabled=true \
  --set persistence.defaultClass.reclaimPolicy=Retain

# 2. 创建 StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
  fromBackup: ""
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF


# 1. 安装 iscsi-initiator-utils
yum install -y iscsi-initiator-utils

# 2. 启动 iscsid 服务
systemctl enable iscsid
systemctl start iscsid

# 3. 安装其他依赖
yum install -y nfs-utils

# 4. 验证 iscsid 服务状态
systemctl status iscsid



apt-get update
apt-get install -y open-iscsi
apt-get install -y nfs-common
systemctl enable iscsid
systemctl start iscsid








#nfs方案
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install my-csi-driver-nfs csi-driver-nfs/csi-driver-nfs --version 4.9.0





#
sudo yum install -y nfs-utils
sudo systemctl start nfs-server
sudo systemctl enable nfs-server
sudo mkdir -p /mnt/nfs_share
sudo chown -R nfsnobody:nfsnobody /mnt/nfs_share
sudo chmod 755 /mnt/nfs_share

sudo vi /etc/exports
/mnt/nfs_share *(rw,sync,no_root_squash)
sudo exportfs -a

sudo systemctl status nfs-server




[root@node01 ~]# cat nfs-storageclass.yaml 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-sc
provisioner: nfs.csi.k8s.io
parameters:
  # NFS 服务器的 IP 地址
  server: 192.168.100.87  # 替换为您的 NFS 服务器 IP
  # NFS 共享路径
  share: /mnt/nfs_share  # 替换为您的 NFS 共享路径
reclaimPolicy: Delete
volumeBindingMode: Immediate
[root@node01 ~]# 

kubectl apply -f nfs-storageclass.yaml
kubectl patch storageclass nfs-sc -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
kubectl get storageclass




















helm install metrics-server bitnami/metrics-server --namespace kube-system \
  --set apiService.create=true \
  --set extraArgs[0]="--kubelet-insecure-tls=true" \
  --set extraArgs[1]="--kubelet-preferred-address-types=InternalIP"

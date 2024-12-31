#!/bin/bash
cat >/tmp/a03_mkfs_disk.sh <<'EOF'
#!/bin/bash
i=0
for  var in ${DATA_DISK_NAME_LIST};do
i=`expr $i + 1`
lsblk  /dev/$var
/usr/sbin/parted -s /dev/$var mklabel gpt
#格式化磁盘
mkfs.ext4  /dev/$var  -F
#创建pv
pvcreate /dev/$var     -y
pvs 
#创建vg
vgcreate data$i /dev/$var 
vgs
#创建逻辑卷
lvcreate  -l 100%FREE    -n data$i data$i  -y
lvs
#格式化逻辑卷为ext4文件系统
mkfs.ext4 /dev/data$i/data$i   -F
#挂载data  data2分区
UUID=$(blkid /dev/data$i/data$i | awk -F '"' '{print  $2}')
mkdir   -pv  /{data,data2}
[[ "$i" == "1" ]] && {
mount /dev/data$i/data$i   /data
sed  '/\/data /d'  /etc/fstab   -i
echo "UUID=${UUID} /data                ext4     defaults        0 0" >>/etc/fstab
}
[[ "$i" == "2" ]] && {
mount /dev/data$i/data$i   /data2
sed  '/\/data2 /d'  /etc/fstab   -i
echo "UUID=${UUID} /data2                ext4     defaults        0 0" >>/etc/fstab
}
#开机自启
done
pvs;vgs;lvs;lsblk;df -h |egrep data;egrep  data /etc/fstab
[[  -d /data2 ]]  ||  {
    mkdir   -pv /data/data2
    ln -sf   /data/data2  /data2
}
EOF
sleep 5

sed -i "/\/bin\/bash/ a\export  DATA_DISK_NAME_LIST='$DATA_DISK_NAME_LIST'" /tmp/a03_mkfs_disk.sh

# source  a03_mkfs_disk.sh

ansible all -m script -a "chdir=/tmp  /tmp/a03_mkfs_disk.sh"
ansible all -m shell -a "df -h |egrep  data;egrep  data  /etc/fstab;pvs|egrep  data"

#!/bin/bash
IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)
ALL_IP=$(egrep  "^[0-9]"   /etc/ansible/hosts   |awk   '{print  $1}'|sort |uniq)
NODE_IP=$(egrep  "^[0-9]"   /etc/ansible/hosts   |awk   '{print  $1}'|sort |uniq|egrep -v  ${IP})
cat > /tmp/del_disk.sh <<'EOF'
#取消自动挂载重启系统后执行 删除LVM
for  var  in $(lsblk  -l|egrep  "lvm"|egrep  -v  "root|swap|home|opt|var|tmp"|awk   '{print $1}'|awk  -F  -  '{print  $1}'|xargs ); do 
ls  -l /dev/$var/$var ;
umount  -f  /dev/$var/$var; 
lvremove /dev/$var/$var  -y;
UUID=$(blkid /dev/$var/$var | awk -F '"' '{print  $2}');
sed  "/$UUID/d"  /etc/fstab   -i;
done
#格式lvs
for  var  in $(pvs|egrep  "data*"|awk  '{print $1}'|xargs); do 
ls  -l  $var ;
mkfs.xfs  -f $var
done
#

sed  "/\/data/d"  /etc/fstab   -i;
#检查
pvs;vgs;lvs;lsblk;df -h |egrep data;egrep  data /etc/fstab
#移除pv
# pvremove  /dev/sdd   --force --force   -y
#
EOF
ansible  --version  >/dev/null && {
ansible $(echo  $NODE_IP |sed 's/ /,/g') -m script -a  "chdir=/tmp  /tmp/del_disk.sh"
ansible $(echo  $NODE_IP |sed 's/ /,/g') -m shell -a  "lsblk"
bash /tmp/del_disk.sh
}
ansible  --version  >/dev/null  ||  bash /tmp/del_disk.sh
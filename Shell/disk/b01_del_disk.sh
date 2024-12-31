#!/bin/bash
IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1)
ALL_IP=$(egrep  "^[0-9]"   /etc/ansible/hosts   |awk   '{print  $1}'|sort |uniq)
NODE_IP=$(egrep  "^[0-9]"   /etc/ansible/hosts   |awk   '{print  $1}'|sort |uniq|egrep -v  ${IP})
sed  "/\/data/d"  /etc/fstab   -i;
ansible  --version  >/dev/null && {
ansible $(echo  $NODE_IP |sed 's/ /,/g') -m shell -a  "sed  \"/\/data/d\"  /etc/fstab   -i;"
ansible $(echo  $NODE_IP |sed 's/ /,/g') -m shell -a   "init 6"
sed  "/\/data/d"  /etc/fstab   -i
init 6
}
init 6
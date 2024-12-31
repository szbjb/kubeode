#!/bin/bash
ansible all -m shell -a "rm -fv /etc/yum.repos.d/CentOS-*.repo"
ansible all -m copy -a "src=/etc/yum.repos.d/local.repo  dest=/etc/yum.repos.d/local.repo"
ansible all -m shell -a "yum clean all;yum repolist"
ansible all -m shell -a "yum install lvm2  -y"

# DiskDistributionEnvironmentCheck
USB_LIST=$(lsblk -S | egrep "usb" | awk '{print  $1}' | xargs | sed 's/ /|/g')
if [ ${USB_LIST} ]; then
    DISK_LIST=($(lsblk -l | egrep disk | egrep -v "${USB_LIST}" | awk '{print  $1}'))
else
    DISK_LIST=($(lsblk -l | egrep "disk" | awk '{print  $1}'))
fi

echo "DISK_LIST: ${DISK_LIST[*]}"

# IdentifySystemDisk,GuideDisk,DataDisck.
SYSTEM_DISK_NAME="echo"
DATA_DISK_NAME="echo"
SYSTEM_DISK_NAME_SIZE="echo"
DATA_DISK_NAME_SIZE="echo"
STATUS_OF_USE="echo"
for Disk in ${DISK_LIST[*]}; do
    sleep 0.001
    DISK_TYPE=""

    lsblk /dev/"${Disk}" -l | egrep "boot|efi|/$" >/dev/null && DISK_TYPE=SystemDisk
    if [ !${DISK_TYPE} ]; then
        lsblk /dev/"${Disk}" -l | egrep "boot|efi|/$" >/dev/null || DISK_TYPE=DataDisk
    fi
    case "${DISK_TYPE}" in
    "SystemDisk")
        DATA_SIZE=$(lsblk /dev/"${Disk}" -l | egrep disk | awk '{print $4}')
        SYSTEM_DISK_NAME="$SYSTEM_DISK_NAME $Disk"
        SYSTEM_DISK_NAME_SIZE="$SYSTEM_DISK_NAME_SIZE $Disk  $DATA_SIZE  "
        ;;
    "DataDisk")
        DATA_SIZE=$(lsblk /dev/"${Disk}" -l | egrep disk | awk '{print $4}')
        STATUS=$(
            df -h | egrep "/dev/${Disk}" >/dev/null
            echo $?
        )

        if [ "$(lsblk -l /dev/${Disk}* | egrep "${Disk}" | wc -l)" -eq 1 ]; then
            if [ "${STATUS}" -ne 0 ]; then
                STATUS_OF_USE=False
                echo ok
            else
                echo no
                STATUS_OF_USE=True
            fi
        else
            echo no
            STATUS_OF_USE=True
        fi
        DATA_DISK_NAME="$DATA_DISK_NAME $Disk"
        DATA_DISK_NAME_SIZE="$DATA_DISK_NAME_SIZE  $Disk  $DATA_SIZE  $STATUS_OF_USE"
        ;;
    esac

done
SYSTEM_DISK_NAME_LIST=$(eval "$SYSTEM_DISK_NAME")
DATA_DISK_NAME_LIST=$(eval "$DATA_DISK_NAME")

SYSTEM_DISK_NAME_LIST_SIZE=$(eval "$SYSTEM_DISK_NAME_SIZE")
DATA_DISK_NAME_LIST_SIZE=$(eval "$DATA_DISK_NAME_SIZE")

echo "
SYSTEM_DISK_NAME:  ${SYSTEM_DISK_NAME_LIST}
DATA_DISK_NAME:    ${DATA_DISK_NAME_LIST}
SYSTEM_DISK_NAME_LIST_SIZE:  ${SYSTEM_DISK_NAME_LIST_SIZE}
DATA_DISK_NAME_LIST_SIZE:   ${DATA_DISK_NAME_LIST_SIZE}
"

#存储磁盘
echo ${DATA_DISK_NAME_LIST}
#二次检查是否存在lvm
i=echo
for var in ${DATA_DISK_NAME_LIST}; do
    pvs | egrep "/dev/$var" || i="$var $i"
done
true_dsik=$(echo  $i|sed   s/echo//g)
#数量检测
DATA_STRAGETYPE_QUANTITY=$(echo ${true_dsik} |xargs  -n 1| wc -l)
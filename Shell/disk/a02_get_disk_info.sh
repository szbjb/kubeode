#!/bin/bash
DATA_STRAGETYPE_QUANTITY=$(echo ${DATA_DISK_NAME_LIST_SIZE} | egrep -o "False" | wc -l)
DATA_STRAGETYPE_QUANTITY=$(echo ${true_dsik} | xargs -n 1 | wc -l)
if [ ${DATA_STRAGETYPE_QUANTITY} -ge 2 ]; then
    echo "选择需要格式化的磁盘"
    DISTROS_SSD=$(whiptail --title "选择磁盘挂载 /data 目录" --radiolist \
        "选择/dev/* 磁盘,将挂载到 /data目录?(按下空格键选中继续)" 17 42 8 \
        $(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep False | awk '{print  $1"\"  \""$2}' | sed 's/^/"/g' | sed 's/$/"  OFF/g' | sed '1s/OFF/ON/' | xargs) \
        3>&1 1>&2 2>&3)
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -eq 0 ]; then
        echo "Your favorite distros are: $DISTROS_SSD"
    else
        echo "You chose Cancel."
        echo 调试
        exit 0
    fi
    DISTROS_SSD_SIZE=$(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep $DISTROS_SSD | awk '{print  $2}')
    echo "Your favorite distros are: $DISTROS_SSD"

    DISTROS_HHD=$(whiptail --title "选择磁盘挂载 /data2 目录" --radiolist \
        "选择/dev/* 磁盘,将挂载到 /data2目录?(按下空格键选中继续)" 17 32 8 \
        $(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep -v "${DISTROS_SSD}" | egrep False | awk '{print  $1"\"  \""$2}' | sed 's/^/"/g' | sed 's/$/"  OFF/g' | sed '1s/OFF/ON/' | xargs) \
        3>&1 1>&2 2>&3)
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -eq 0 ]; then
        echo "Your favorite distros are: $DISTROS_HHD"
    else
        echo "You chose Cancel."
        echo 调试
        exit 0
    fi
    echo "Your favorite distros are: $DISTROS_HHD"
    DISTROS_HHD_SIZE=$(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep $DISTROS_HHD | awk '{print  $2}')

    VERIFICATION_CODE=$(echo $RANDOM)
    DISK_TYPE=$(whiptail --title "data*存储磁盘文件系统分区格式选择" --radiolist "ext4/xfs?" 15 75 4 "ext4" "存储磁盘文件系统分区格式" ON "xfs" "存储磁盘文件系统分区格式" OFF 3>&1 1>&2 2>&3)
    CONFIRM=$(whiptail --title "确认磁盘挂载信息" --inputbox "设备名  文件系统   容量    VG名称(lvm)   挂载点\n/dev/$DISTROS_SSD   ${DISTROS_SSD_SIZE}      data1         /data\n/dev/$DISTROS_HHD   ${DISTROS_HHD_SIZE}      data2         /data2\n\n请输入验证码[ $VERIFICATION_CODE ],该操作不可逆,确认?" 13 60 3>&1 1>&2 2>&3)
    [ $VERIFICATION_CODE -eq $CONFIRM ] || {
        clear
        echo incorrect verification code!!
        exit 0
    }
    vg_data1=$(echo "$DISTROS_SSD   ${DISTROS_SSD_SIZE}  data1,$DISTROS_HHD   ${DISTROS_HHD_SIZE}  data2" | xargs -d , -n 1 | egrep "data1" | awk '{print  $1}')
    vg_data2=$(echo "$DISTROS_SSD   ${DISTROS_SSD_SIZE}  data1,$DISTROS_HHD   ${DISTROS_HHD_SIZE}  data2" | xargs -d , -n 1 | egrep "data2" | awk '{print  $1}')
    DATA_DISK_NAME_LIST="$vg_data1 $vg_data2"

else
    [ ${DATA_STRAGETYPE_QUANTITY} -eq 1 ] && {
        echo "选择需要格式化的磁盘"
        DISTROS_SSD=$(whiptail --title "选择磁盘挂载 /data 目录" --radiolist \
            "选择/dev/* 磁盘,将挂载到 /data目录\n(由于只有一块存储盘/data2将软链接到/data/data2)?\n(按下空格键选中继续)" 17 52 8 \
            $(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep False | awk '{print  $1"\"  \""$2}' | sed 's/^/"/g' | sed 's/$/"  OFF/g' | sed '1s/OFF/ON/' | xargs) \
            3>&1 1>&2 2>&3)
        EXIT_STATUS=$?
        if [ $EXIT_STATUS -eq 0 ]; then
            echo "Your favorite distros are: $DISTROS_SSD"
        else
            echo "You chose Cancel."
            echo 调试
            exit 0
        fi
        DISTROS_SSD_SIZE=$(echo ${DATA_DISK_NAME_LIST_SIZE} | xargs -n 3 | egrep $DISTROS_SSD | awk '{print  $2}')
        echo "Your favorite distros are: $DISTROS_SSD"
        VERIFICATION_CODE=$(echo $RANDOM)
        DISK_TYPE=$(whiptail --title "data*存储磁盘文件系统分区格式选择" --radiolist "ext4/xfs?" 15 75 4 "ext4" "存储磁盘文件系统分区格式" ON "xfs" "存储磁盘文件系统分区格式" OFF 3>&1 1>&2 2>&3)
        CONFIRM=$(whiptail --title "确认磁盘挂载信息" --inputbox "设备名  文件系统   容量    VG名称(lvm)   挂载点\n/dev/$DISTROS_SSD   ${DISK_TYPE}    ${DISTROS_SSD_SIZE}      data1        /data\n\n请输入验证码[ $VERIFICATION_CODE ],该操作不可逆,确认?" 13 60 3>&1 1>&2 2>&3)
        [ $VERIFICATION_CODE -eq $CONFIRM ] || {
            clear
            echo incorrect verification code!!
            exit 0
        }
        vg_data1=$(echo "$DISTROS_SSD   ${DISTROS_SSD_SIZE}  data1,$DISTROS_HHD   ${DISTROS_HHD_SIZE}  data2" | xargs -d , -n 1 | egrep "data1" | awk '{print  $1}')
        DATA_DISK_NAME_LIST="$vg_data1 $vg_data2"
    }

    echo "You chose No. Exit STATUS was $?."

fi

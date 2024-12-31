#!/bin/bash
set -x
basepath=$(
    cd $(dirname $0) >/dev/null
    pwd
)

echo $basepath
rm -f /usr/local/kubeode
[[ -d /usr/local/kubeode ]] || {
    ln -sf ${basepath} /usr/local/kubeode
}

chmod -R 755 /usr/local/kubeode
# 使用须知
_Terms_and_Conditions() {
    if (whiptail --title "Yes/No 使用须知" --yesno --yes-button 是 --no-button 否 "请悉知,脚本根据你的选择将会对系统做如下相关变更: \
\n1.兼容centos7/8/9,国产rpm包系企业级系统例如uos、华为欧拉、麒麟、腾讯os、银河麒麟、深度、中标麒麟、凝思等,Linux内核大于4.0。 \
\n2.请确保本机为干净环境,系统新装,集群root密码统一，无需提前修改主机名. \
\n3.默认脚本将集群主机按照ip从小到大排序自动配置主机名规则为node0x----->nodexx。 \
\n4.离线版需要下载完整版本，非git代码库的默认不带离线包。 \
\n5.在线安装版需要当前环境可以正常访问谷歌(google.com).国内加速版近期会更新. \
\n6.默认安装ansible等常用基础软件,集成 kube-api云原生高可用方案 \
\n6.nfs    openebs选择性安装到指定节��,支持网页终端和第三方如xshell等终端 \
\n7.网卡名称如果是不常见的，建议修改成规范的网卡名称， 如(eth.|en.|em.*)  \
\n8.内置ntp时间同步,默认定时任务10m一次 \
\n9.安装过程根据你的选择可能会清除/data   /var/lib/docker 等文件夹，重要资料提前备份。 \
\n10.推荐新装系统干净环境使用,支持1-多台环境灵活使用。 \
\n11.支持在线联网安装以及完全离线安装两种方式，一次性安装完成。\
" --defaultno --fb 25 90); then
        echo "You chose Yes. Exit status was $?."
    else
        echo "You chose No. Exit status was $?."
        exit 0
    fi
}

# 显示语言选择菜单
_show_language_menu() {
    TITLE="Kubeode v1.31.0 - Language Selection"
    LANG_OPTION=$(whiptail --title "$TITLE" --menu "Choose your language" --ok-button 确认 --cancel-button 退出 20 65 13 \
        "1" "中文" \
        "2" "English" 3>&1 1>&2 2>&3)

    # 检查用户是否选择了取消
    if [ $? -ne 0 ]; then
        echo "用户选择退出"
        exit 1
    fi

    echo $LANG_OPTION
}

# 显示主菜单
_show_main_menu() {
    if [ "$LANG_OPTION" = "1" ]; then
        TITLE="kubeode v1.31.0图形化安装, Version @ 2024 ($INSTALL_MODE)"
        MENU_OPTION=$(whiptail --title "$TITLE" --menu "选择操作" --ok-button 确认 --cancel-button 退出 20 65 13 \
            "1" "离线安装 Kubernetes" \
            "2" "在线安装 Kubernetes" \
            "3" "退出" 3>&1 1>&2 2>&3)
    else
        TITLE="kubeode v1.31.0 Graphical Installation, Version @ 2024 ($INSTALL_MODE)"
        MENU_OPTION=$(whiptail --title "$TITLE" --menu "Choose your option" --ok-button Confirm --cancel-button Exit 20 65 13 \
            "1" "Offline Installation Kubernetes" \
            "2" "Online Installation Kubernetes" \
            "3" "Exit" 3>&1 1>&2 2>&3)
    fi

    # 检查用户是否点击了退出按钮
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
        return 1
    fi

    # 根据选择设置安装模式
    case $MENU_OPTION in
    1)
        INSTALL_MODE="offline"
        return 0
        ;;
    2)
        INSTALL_MODE="online"
        return 0
        ;;
    3)
        return 1
        ;;
    *)
        return 1
        ;;
    esac
}

# 显示离线安装错误消息
_handle_offline_install_error() {
    if [ "$LANG_OPTION" = "1" ]; then
        whiptail --title "离线安装错误" --msgbox "当前安装包非离线版，仅支持在线安装。请选择在线安装。\n若需离线安装请到www.kubeode.com 下载离线包安装。" 10 75
    else
        whiptail --title "Offline Installation Error" --msgbox "The current installation package is not offline. Only online installation is supported. Please download the offline installation package from www.kubeode.com." 10 75
    fi
    _show_main_menu
}

# 判断离线安装包路径是否存在文件
_check_install_mode() {
    IMAGE_DIR="/usr/local/kubeode/package/offline/Images/"
    RPM_LIST_DIR="/usr/local/kubeode/package/offline/tools/"
    SCRIPT_DIR="/usr/local/kubeode/Shell/repo/"

    while true; do
        IMAGE_FILES=$(ls -1q $IMAGE_DIR | wc -l)
        RPM_LIST_FILES=$(ls -1q $RPM_LIST_DIR | wc -l)

        if [ "$INSTALL_MODE" = "offline" ]; then
            if [ "$IMAGE_FILES" -eq 0 ] || [ "$RPM_LIST_FILES" -eq 0 ]; then
                _handle_offline_install_error
                _show_main_menu
                break
            else
                echo "Offline installation mode selected"
                source "$SCRIPT_DIR/setup_offline_repos.sh"
                _setup_offline_repos_main
                break
            fi
        else
            echo "Online installation mode selected"
            source "$SCRIPT_DIR/setup_online_repos.sh"
            _setup_repos_main
            break
        fi
    done
}
# 检查网络环境
_check_network_environment() {
    # 只保留 Google 访问检查
    if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null; then
        if [ "$LANG_OPTION" = "1" ]; then
            whiptail --title "网络检查" --msgbox "无法访问 Google，在线安装需要能够访问 Google。请检查网络环境后重试。" 10 60
        else
            whiptail --title "Network Check" --msgbox "Cannot access Google. Online installation requires Google access. Please check your network environment and try again." 10 60
        fi
        return 1
    fi
    return 0
}
# 显示在线安装 Kubernetes 子菜单
_show_online_install_menu() {
    INSTALL_OPTION=$(whiptail --title "在线安装 Kubernetes" --menu "选择菜单" --ok-button 确认 --cancel-button 退出 20 65 13 \
        "1" "开始安装" \
        "2" "增加control_plane节点" \
        "3" "增加node节点" \
        "4" "删除节点" \
        "5" "退出" 3>&1 1>&2 2>&3)

    # 保存退出状态
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
        return 1
    fi
    echo "$INSTALL_OPTION"
}

# 在线安装 Kubernetes 子菜单逻辑
_handle_online_install() {
    # 检查网络环境
    _check_network_environment
    while true; do
        INSTALL_OPTION=$(_show_online_install_menu)
        [ $? -ne 0 ] && return 1

        case $INSTALL_OPTION in
        1)
            #基本环境安装
            command sshpass 2>/dev/null || yum install sshpass -y >/dev/nulll
            # 初始化环境变量
            source /usr/local/kubeode/Shell/a01_cluster_ip_init.sh
            _init_env
            #初始化节点repo
            source /usr/local/kubeode/Shell/a03_k8s_install.sh
            _add_node_repo_init all
            # 安装 Kubernetes
            source /usr/local/kubeode/Shell/a02_system_init.sh
            # ssh集群免密处理
            _init_ssh
            # 操作系统初始化
            _os_init_online all
            # docker初始化
            _docker_init_online all
            #镜像仓库初始化
            _registry_setup

            # 安装 Kubernetes 本机第一个master节点
            source /usr/local/kubeode/Shell/a03_k8s_install.sh
            _install_k8s
            #判断当前安装环境是否是集群
            source /usr/local/kubeode/Shell/cluster-ips.conf
            NODE_COUNT=$(echo $CLUSTER_IPS | xargs -n 1 | wc -l)

            if [ "$NODE_COUNT" -gt 1 ]; then
                source /usr/local/kubeode/Shell/selected-nodes.conf
                # 获取本机IP
                LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1 )

                # 过滤PRIMARY_NODE中的本机IP
                if [[ $MY_PRIMARY_NODE == *"$LOCAL_IP"* ]]; then
                    MY_PRIMARY_NODE=$(echo "$MY_PRIMARY_NODE" | tr ' ' '\n' | grep -v "^$LOCAL_IP$" | tr '\n' ' ' | sed 's/ $//')
                fi

                # 过滤WORKER_NODE中的本机IP和PRIMARY_NODE中的IP
                if [ -n "$MY_WORKER_NODE" ]; then
                    # 先过滤本机IP
                    MY_WORKER_NODE=$(echo "$MY_WORKER_NODE" | tr ' ' '\n' | grep -v "^$LOCAL_IP$" | tr '\n' ' ' | sed 's/ $//')

                    # 再过滤PRIMARY_NODE中的IP
                    for primary_ip in $MY_PRIMARY_NODE; do
                        MY_WORKER_NODE=$(echo "$MY_WORKER_NODE" | tr ' ' '\n' | grep -v "^$primary_ip$" | tr '\n' ' ' | sed 's/ $//')
                    done
                fi
                # 如果节点数量大于1，执行添加节点操作
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #增加判断如果MY_PRIMARY_NODE非空，则增加control_plane节点
                if [ -n "$MY_PRIMARY_NODE" ]; then
                    #增加control_plane节点
                    _add_control_plane $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')

                fi
                #增加判断如果MY_WORKER_NODE非空，则增加node节点
                if [ -n "$MY_WORKER_NODE" ]; then
                    #增加node节点
                    _add_node $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                fi
            else
                # 如果节点数量等于1，直接结束安装
                echo "单节点安装完成"
            fi

            source /usr/local/kubeode/Shell/selected-nodes.conf

            echo "安装 Kubernetes 结束"
            return 0
            ;;
        2)
            cd /usr/local/kubeode/Shell
            pwd
            echo "增加control_plane节点"
            >/usr/local/kubeode/Shell/cluster-ips.conf
            ./k8s-ip-config -s 22 && {
                source /usr/local/kubeode/Shell/cluster-ips.conf
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                _add_node_to_hosts
                MY_PRIMARY_NODE=$(echo $CLUSTER_IPS | xargs | sed 's/ /,/g')
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #获取当前最大主机名序号
                _get_max_hostname_index
                #设置新增节点的主机名
                _set_new_node_hostnames
                #初始化节点repo
                _add_node_repo_init $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #新增节点os初始化
                _add_node_os_init $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #新增节点docker初始化
                _add_node_docker_init $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #增加control_plane节点
                _add_control_plane $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                echo "增加control_plane节点完成"
                kubectl get nodes -o wide
                kubectl get pods -A -o wide && exit 0
            }
            return 0
            ;;
        3)
            cd /usr/local/kubeode/Shell
            echo "增加node节点"
            >/usr/local/kubeode/Shell/cluster-ips.conf
            ./k8s-ip-config -s 22 && {
                source /usr/local/kubeode/Shell/cluster-ips.conf
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                _add_node_to_hosts
                MY_WORKER_NODE=$(echo $CLUSTER_IPS | xargs | sed 's/ /,/g')
                #获取当前最大主机名序号
                _get_max_hostname_index
                #设置新增节点的主机名
                _set_new_node_hostnames
                #始化节点repo
                _add_node_repo_init $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #新增节点os初始化
                _add_node_os_init $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #新增节点docker初始化
                _add_node_docker_init $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #增加node节点
                _add_node $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                echo "增加worker节点完成"
                kubectl get nodes -o wide
                kubectl get pods -A -o wide && exit 0
            }
            ;;
        4)
            #删除节点
            source /usr/local/kubeode/Shell/a03_k8s_install.sh
            _delete_node
            echo "正在删除" && exit 0
            ;;
        5)
            return 1
            ;;
        *)
            echo "操作错误"
            return 1
            ;;
        esac
    done
}

# 显示离线安装 Kubernetes 子菜单
_show_offline_install_menu() {
    INSTALL_OPTION=$(whiptail --title "离线安装 Kubernetes" --menu "选择操作系统" --ok-button 确认 --cancel-button 退出 20 65 13 \
        "1" "开始安装" \
        "2" "增加control_plane节点" \
        "3" "增加node节点" \
        "4" "删除节点" \
        "5" "退出" 3>&1 1>&2 2>&3)

    # 保存退出状态
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
        return 1
    fi
    echo "$INSTALL_OPTION"
}

# 处理离线安装逻辑
_handle_offline_install() {
    echo "走到这里了# 处理离线安装逻辑"

    INSTALL_OPTION=$(_show_offline_install_menu)
    [ $? -ne 0 ] && return 1

    case $INSTALL_OPTION in
    1)
        #基本环境安装
        command sshpass 2>/dev/null || yum --disablerepo="*" --enablerepo="kubeode_local" sshpass -y >/dev/nulll
        # 初始化环境变量
        source /usr/local/kubeode/Shell/a01_cluster_ip_init.sh
        _init_env
        #初始化节点repo
        source /usr/local/kubeode/Shell/a03_k8s_install.sh
        _add_node_repo_init_offline all
        # 安装 Kubernetes
        source /usr/local/kubeode/Shell/a02_system_init.sh
        # ssh集群免密处理
        _init_ssh
        # 操作系统初始化
        _os_init_online all
        # docker初始化
        _docker_init_offline all
        #镜像仓库初始化
        _registry_setup
        # 安装 Kubernetes 本机第一个master节点
        source /usr/local/kubeode/Shell/a03_k8s_install.sh
        _install_k8s_offline
        #判断当前安装环境是否是集群
        source /usr/local/kubeode/Shell/cluster-ips.conf
        NODE_COUNT=$(echo $CLUSTER_IPS | xargs -n 1 | wc -l)

        if [ "$NODE_COUNT" -gt 1 ]; then
            source /usr/local/kubeode/Shell/selected-nodes.conf
            # 获取本机IP
            LOCAL_IP=$(ip -o -4 addr show up | awk '{print $2, $4}' | grep -v 'docker0' | grep -v 'lo' | head -n 1 | awk '{print $2}' | cut -d/ -f1 )

            # 过滤PRIMARY_NODE中的本机IP
            if [[ $MY_PRIMARY_NODE == *"$LOCAL_IP"* ]]; then
                MY_PRIMARY_NODE=$(echo "$MY_PRIMARY_NODE" | tr ' ' '\n' | grep -v "^$LOCAL_IP$" | tr '\n' ' ' | sed 's/ $//')
            fi

            # 过滤WORKER_NODE中的本机IP和PRIMARY_NODE中的IP
            if [ -n "$MY_WORKER_NODE" ]; then
                # 先过滤本机IP
                MY_WORKER_NODE=$(echo "$MY_WORKER_NODE" | tr ' ' '\n' | grep -v "^$LOCAL_IP$" | tr '\n' ' ' | sed 's/ $//')

                # 再过滤PRIMARY_NODE中的IP
                for primary_ip in $MY_PRIMARY_NODE; do
                    MY_WORKER_NODE=$(echo "$MY_WORKER_NODE" | tr ' ' '\n' | grep -v "^$primary_ip$" | tr '\n' ' ' | sed 's/ $//')
                done
            fi
            # 如果节点数量大于1，执行添加节点操作
            source /usr/local/kubeode/Shell/a03_k8s_install.sh
            #增加判断如果MY_PRIMARY_NODE非空，则增加control_plane节点
            if [ -n "$MY_PRIMARY_NODE" ]; then
                #增加control_plane节点
                _add_control_plane $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')

            fi
            #增加判断如果MY_WORKER_NODE非空，则增加node节点
            if [ -n "$MY_WORKER_NODE" ]; then
                #增加node节点
                _add_node $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
            fi
        else
            # 如果节点数量等于1，直接结束安装
            echo "单节点安装完成"
        fi

        source /usr/local/kubeode/Shell/selected-nodes.conf

        echo "安装 Kubernetes 结束"
        return 0
        ;;
    2)
                cd /usr/local/kubeode/Shell
            pwd
            echo "增加control_plane节点"
            >/usr/local/kubeode/Shell/cluster-ips.conf
            ./k8s-ip-config -s 22 && {
                source /usr/local/kubeode/Shell/cluster-ips.conf
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                _add_node_to_hosts
                MY_PRIMARY_NODE=$(echo $CLUSTER_IPS | xargs | sed 's/ /,/g')
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #获取当前最大主机名序号
                _get_max_hostname_index
                #设置新增节点的主机名
                _set_new_node_hostnames
                #初始化节点repo
                _add_node_repo_init_offline $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #新增节点os初始化
                _add_node_os_init $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #新增节点docker初始化
                _add_node_docker_init $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                #增加control_plane节点
                _add_control_plane $(echo $MY_PRIMARY_NODE | xargs | sed 's/ /,/g')
                echo "增加control_plane节点完成"
                kubectl get nodes -o wide
                kubectl get pods -A -o wide && exit 0
            }   
        whiptail --title "安装提示" --msgbox "增加 control_plane 节点" 10 60
        return 0
        ;;
    3)            
            cd /usr/local/kubeode/Shell
            echo "增加node节点"
            >/usr/local/kubeode/Shell/cluster-ips.conf
            ./k8s-ip-config -s 22 && {
                source /usr/local/kubeode/Shell/cluster-ips.conf
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                source /usr/local/kubeode/Shell/a03_k8s_install.sh
                #新增增加control_plane节点节点信息到/etc/ansible/hosts
                _add_node_to_hosts
                MY_WORKER_NODE=$(echo $CLUSTER_IPS | xargs | sed 's/ /,/g')
                #获取当前最大主机名序号
                _get_max_hostname_index
                #设置新增节点的主机名
                _set_new_node_hostnames
                #始化节点repo
                _add_node_repo_init_offline $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #新增节点os初始化
                _add_node_os_init $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #新增节点docker初始化
                _add_node_docker_init $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                #增加node节点
                _add_node $(echo $MY_WORKER_NODE | xargs | sed 's/ /,/g')
                echo "增加worker节点完成"
                kubectl get nodes -o wide
                kubectl get pods -A -o wide && exit 0
            }
        whiptail --title "安装提示" --msgbox "增加 node 节点" 10 60
        return 0
        ;;
    4)
        source /usr/local/kubeode/Shell/a03_k8s_install.sh
        _delete_node
        echo "删除节点完成" && exit 0
        ;;
    5)
        return 1
        ;;
    *)
        echo "操作错误"
        return 1
        ;;
    esac
}

# 卸载集群
_uninstall_cluster() {
    source /usr/local/kubeode/Shell/all_uninstall.sh 2>/dev/null
    _uninstall
    echo "集群卸载完成"
}

# 主程序入口
_main() {
    # 显示语言选择菜单
    LANG_OPTION=$(_show_language_menu)
    [ $? -ne 0 ] && exit 0

    # 使用须知
    _Terms_and_Conditions
    [ $? -ne 0 ] && exit 0

    # 显示主菜单选择在线离线模式
    _show_main_menu
    [ $? -ne 0 ] && exit 0

    # 判断离线安装包路径是否存在文件
    _check_install_mode
    [ $? -ne 0 ] && exit 0

    # 如果是在线模式，先检查网络环境
    if [ "$INSTALL_MODE" = "online" ]; then
        _check_network_environment
        [ $? -ne 0 ] && exit 0
    fi

    # 如果是离线模式，则执行离线安装逻辑
    echo "打印选择安装模式 $INSTALL_MODE"
    if [ "$INSTALL_MODE" = "offline" ]; then
        _handle_offline_install
        [ $? -ne 0 ] && echo "离线安装失败" && exit 0
    else
        _handle_online_install
        [ $? -ne 0 ] && echo "在线安装失败" && exit 0
    fi
}

_main

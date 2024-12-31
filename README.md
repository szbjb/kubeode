
![[输入图片说明](http://www.linuxtools.cn:5244)](%E6%9E%B6%E6%9E%84%E5%9B%BE_log_%E5%8F%82%E8%80%83%E8%B5%84%E6%96%99/Kubeodelogo.jpeg)

# 

### 2024新版本已发布，文档持续更新中，仓库默认为在线版，离线版需到网盘下载!!




# 什么是 Kubeode？
Kubeode是一个kubernetes（简称：k8s）本土化二进制离线部署软件，100%开源，100%问题社区支持，slogan：Kubeode一键部署k8s，助你快速落地 Kubernetes。
# Kubeode的特性
k8s集群二进制包一键化多master-HA基于内核负载高可用，支持centos7.3-7.9+kubernetes v1.23.5集群一键离线安装，一键批量增删node节点，一键集成k8s持久化方案Heketi+GlusterFS+nfs+helm3+动态存储+dns+ipvs+prometheus +grafan

# Kubeode的功能包括
1、可通过install.sh脚本一键部署k8
# Kubeode 的优势
摆脱复杂繁琐的多组件包下载，摆脱非本土化网络带来的无法部署的问题
# Kubeode 的技术栈
shell,Go
# 快速开始
## 环境准备：
| 节点名称   | 内存要求  |
|--------|-------|
| master | 最低6GB |
| node   | 最低4GB |
## 下载准备：
下载源码包：

【备用】k8s-2022-06-19.tar [Kubeode天翼云下载链接](https://cloud.189.cn/t/JRZrmiBFbeUj)
提取码：6cae

注：上述方式下载慢推荐解决方法：[二进制下载慢过程繁多的解决方案](https://gitee.com/q7104475/kubeode/blob/master/%E6%9E%B6%E6%9E%84%E5%9B%BE_log_%E5%8F%82%E8%80%83%E8%B5%84%E6%96%99/word.md) 二进制下载慢过程繁多的解决方案章节


## 安装前置检查：
### 前置操作1：清理残留

```
rm -fv  K8s/Software_package/kubernetes-server-linux-amd64.tar.a*
```

## 一键安装
以 root 用户执行如下命令一键安装 Kubeode
### 一键解压并安装
```
tar -xvf  k8s-2022-06-19.tar && cd  k8s-2022-06-19/ && sh install.sh
```
# 学习资料
## 视频指导

Kubeode_k8sV2.6.19版本部署专题：[Kubeode_k8sV2.6.19_西瓜视频](https://www.ixigua.com/7128215671556702723?wid_try=1)
IT老齐Kubeode专题：[IT老齐Kubeode专题精讲_Bilibili视频](https://www.bilibili.com/video/BV1DS4y1n7LV/?spm_id_from=333.337.search-card.all.click)

说明：IT老齐使用的版本是Kubeode_k8sV2.4.24版本

Kubeode首期视频：[Kubeode首期教程视频_2019.6.29_Bilibili视频](https://www.bilibili.com/video/av57242055/?from=search&seid=4003077921686184728&vd_source=8c375a0de2b26977fcd2fb2e63752f49)

说明：Kubeode 2019年视频，视频具有一定意义，记录产品诞生的欣喜。
## 文档指导
### Kubeode_k8sV2.4.24 部署说明

Kubeode_k8sV2.4.24 版本包名为k8s-2022-04-24.tar.gz，下述说明书已提供详细下载方法和部署图文指导，请大家放心使用。

### Kubeode_k8sV2.4.24 部署说明书地址

[Kubeode_k8sV2.4.24 部署说明书](https://gitee.com/q7104475/kubeode/blob/master/Software_package/Kubeode_k8sV2.2.24.md)

### Kubeode_k8sV2.6.19 部署说明

Kubeode_k8sV2.6.19 版本包名为k8s_kubeode_20220619.tar，下述说明书已提供详细下载方法和部署图文指导，请大家放心使用。

### Kubeode_k8sV2.6.19 部署说明书地址

[k8s_kubeode_20220619 部署说明书](https://gitee.com/q7104475/kubeode/blob/master/Software_package/Kubeode_k8sV2.6.19%20%E9%83%A8%E7%BD%B2%E8%AF%B4%E6%98%8E%E4%B9%A6.md)

# 社区支持
## 社区QQ群
QQ群号：893480182
| 支持方式   |          |                                                         | 备注                                 |
|--------------|-------------|-------------------------------------------------|------------------------------------------------|
| QQ群      | QQ群号     | 893480182                                               | 群功能： 1、社区群文件可下载离线包 2、社区长期支持k8s问题交流 |
|        | 加群备注        | kubernetes                                              |                                    |
|        | QQ群名称       | K8s(kubeode)二进制自动化部署                                    |                                    |
| 远程会议      | 软件名称        | 腾讯会议/ToDesk                                             |                                    |
|        | 求助对象     | 群主                                                      |                                    |
|        | 会议求助前置条件 | 将出问题的环境保留勿动，直接发腾讯会议/Todesk id或者会议分享链接 到qq群内或者私聊群主，快速定位。 |

README.MD 首页产品指导书已于2023/4/22 输出新版如本页面

往期指导请访问：[往期README.MD](https://gitee.com/q7104475/kubeode/blob/master/Software_package/readme_copy.md)

# k8s一键部署项目，专注更快部署k8s，欢迎star
[![zhuang kang/K8s](https://gitee.com/q7104475/K8s/widgets/widget_card.svg?colors=037efa,ffffff,ffffff,e3e9ed,666666,9b9b9b)](https://gitee.com/q7104475/K8s)





#!/bin/bash
##############################################
#Author: jerryhuangr
#Email:  vip_star_hr@163.com
#Last modified: 2018/11/15/14:42
#Filename: WarningLogingwxAlert.sh
#Revision:  0.1
#Description: 
#crontab: * * * * * WarningLogingwxAlert.sh
#Website:   www.1024.com
#License: GPL
##############################################

## jp install 
# yum -y install jq
## if yum install fail
# wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# rpm -ivh epel-release-latest-7.noarch.rpm

#微信企业号的CropID
CropID='wx80179d3a3eb675c2'
#企业号中发送告警的应用
Secret='rf8zW7iF-VECQVwKGndrHzAkEqfcnmSXmhIGUHCKH24'
GURL="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=$CropID&corpsecret=$Secret"
Gtoken=$(/usr/bin/curl -s -G $GURL |  awk -F "[\":,]" '{print $15}')
PURL="https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$Gtoken"

function body() {
    local int AppID=1
    #Appid 填写企业号中建立的报警APP的ID
    local UserID="@all"
    #此处填写报警接收用户，全部报警可留空
    local PartyID="@all"
    local TagID="@all"
    Ent=$'\n'
    Date=$(date '+%Y年%m月%d日 %H:%M:%S\n')
    Tit="BBS Server SSH Login"
    Content=`cat $TMP1`
    Msg=$Date$Ent$Content
    #Msg=$Date$Tit$Ent$(cat /tmp/message.txt|sed 's/%//g')
    #拼接msg主体文件,包含日期,主题,报警内容.并删除报警内容中的'%'号.
    #Url="http://www.zabbix.com"
    #Pic="http://cdn.aixifan.com/dotnet/20130418/umeditor/dialogs/emotion/images/ac/35.gif"
    #Pic="http://cdn.aixifan.com/dotnet/20130418/umeditor/dialogs/emotion/images/ac2/24.gif"
    printf '{\n'
    printf '\t"touser": "'"$UserID"\"",\n"
    printf '\t"toparty": "'"$PartyID"\"",\n"
    printf '\t"totag": "'"$TagID"\"",\n"
    printf '\t"msgtype": "news",\n'
    printf '\t"agentid": "'" $AppID "\"",\n"
    printf '\t"news": {\n'
    printf '\t"articles": [\n'
    printf '{\n'
    printf '\t\t"title": "'"$Tit"\","\n"
    printf '\t\t"description": "'"$Msg"\","\n"
    printf '\t\t"url": "'"$Url"\","\n"
    printf '\t\t"picurl": "'"$Pic"\","\n"
    printf '\t}\n'
    printf '\t]\n'
    printf '\t}\n'
    printf '}\n'
}

if [[ -n ${SSH_CLIENT%% *} ]];then
    eval `/usr/bin/curl -s "http://ip.taobao.com/service/getIpInfo.php?ip=${SSH_CLIENT%% *}" | jq . | awk -F':|[ ]+|"' '$3~/^(country|area|region|city|isp)$/{print $3"="$7}'`
    message="登入者IP地址：${SSH_CLIENT%% *}\n\
IP归属地：${country}_${area}_${region}_${city}_${isp}\n\
被登录服务器IP：$(curl -s ip.cip.cc)"
    TMP1=`mktemp`
    echo $message > $TMP1
    curl -l -H "Content-type: application/json" -X POST -d "$(body )" $PURL
    rm -f $TMP1 
fi








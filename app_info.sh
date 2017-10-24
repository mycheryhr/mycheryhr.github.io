#!/bin/bash
#Author: Jerryhuang
#Date: 2017-10-24
#Versions: 1.0.0

welcome_show(){
    echo -e "\033[31m***************************************************\033[0m" 
    echo -e "\033[31m*            Welcom to ksgame server.             *\033[0m" 
    echo -e "\033[31m*     This is an important production server.     *\033[0m" 
    echo -e "\033[31m*              Please be careful !                *\033[0m" 
    echo -e "\033[31m***************************************************\033[0m" 
}

Check(){
    type iostat >/dev/null 2>&1 || (yum -y install sysstat >/dev/null 2>&1)
    export PS1='\u@\[\e[0;31m\]<\H|\w>\[\e[m\]:\$ ' && clear
    welcome_show
    echo -e ""
    echo -e "\033[31m******************** APP INFO. ********************\033[0m" 
    #ls -l /data/www/ |grep "^d" |grep -v bak |awk '{print $9}' 
    echo -e "\033[31m`ls -l /data/www |grep -v bak |grep ^d |awk '{{printf "%s   ",$9}}' |sort -n'`\033[0m"
}

Check

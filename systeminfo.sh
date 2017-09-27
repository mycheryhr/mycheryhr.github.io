#!/bin/bash
#Author: Jerryhuang
#Date: 2017-09-19
#Versions: 1.0.0

### display colorful string
Color_str(){
    [ $# -ne 2   ] && {
        echo "Illegal function call"
        echo "$FUNCNAME [red|green|blue|yello|pink] str"
        exit 1
    }

    case "$1" in
        red)
            echo -e "\033[31m$2\033[0m"
            ;;
        green)
            echo -e "\033[32m$2\033[0m"
            ;;
        blue)
            echo -e "\033[33m$2\033[0m"
            ;;
        yello)
            echo -e "\033[34m$2\033[0m"
            ;;
        pink)
            echo -e "\033[35m$2\033[0m"
            ;;
        *)
            echo "$2"
            ;;
    esac
}

Load_check(){
    local Cpu_idle=`iostat -c|awk 'NF{print $NF}'|tail -n1`
    local Cpu_load=`awk 'BEGIN{printf "%.1f", 100-"'$Cpu_idle'"}'`
    local Sys_load=`uptime|awk -F"[:]" '{gsub(/^ |,/,"",$NF);print $NF}'`
    local Sys_load_cur=`echo "$Sys_load"|awk '{print $1}'`
    local Mem_total=`free -m|awk '/Mem:/{print $2}'`
    local Mem_free=`free -m|awk '/Mem:/{print $4}'`
    local Mem_free_per=`awk 'BEGIN{printf "%.1f", "'$Mem_free'"/"'$Mem_total'"*100}'`
    local Disk_root=`df -h|awk '$NF=="/"{print $(NF-1)+0}'`
    local Disk_usr_local=`df -h|awk '$NF~"/data"{print $(NF-1)+0}'`

    local tt=`awk 'BEGIN{if("'$Cpu_load'"-70<0){print 0}else{print 1}}'`
    if [ "$tt" -eq 0 ]; then
        local Cpu_load_color='green'
    else
        local Cpu_load_color='red'
    fi

    local tt=`awk 'BEGIN{if("'$Sys_load_cur'"-0.8<0){print 0}else{print 1}}'`
    if [ "$tt" -eq 0 ]; then
        local Sys_load_color='green'
    else
        local Sys_load_color='red'
    fi

    local tt=`awk 'BEGIN{if("'$Mem_free_per'"-10>0){print 0}else{print 1}}'`
    if [ "$tt" -eq 0 ]; then
        local Mem_free_per_color='green'
    else
        local Mem_free_per_color='red'
    fi

    local tt=`awk 'BEGIN{if("'$Disk_root'"-90<0){print 0}else{print 1}}'`
    if [ "$tt" -eq 0 ]; then
        local Disk_root_color='green'
    else
        local Disk_root_color='red'
    fi

    local tt=`awk 'BEGIN{if("'$Disk_usr_local'"-90<0){print 0}else{print 1}}'`
    if [ "$tt" -eq 0 ]; then
        local Disk_usr_local_color='green'
    else
        local Disk_usr_local_color='red'
    fi

    OLD_IFS="$IFS"
    IFS='______________________________________________________________'
    printf "%-10s%12s%25s | " "Load" "Cpu_load:" \
        `Color_str "$Cpu_load_color" "$Cpu_load%"`
    printf "%12s%25s\n" "Sys_load:" \
        `Color_str "$Sys_load_color" "$Sys_load"`
    printf "%-10s%12s%25s | " "Memory" "total:" `Color_str green "${Mem_total}MB"`
    printf "%12s%25s\n" "free:" \
        `Color_str "$Mem_free_per_color" "$Mem_free_per%"`
    printf "%-10s%12s%25s | " "Disk" "/:" \
        `Color_str "$Disk_root_color" "$Disk_root%"`
    printf "%12s%25s\n" "/data:" \
        `Color_str "$Disk_usr_local_color" "$Disk_usr_local%"`
    IFS="$OLD_IFS"
}

### 分区是否只读检测
Disk_read_only_check(){
    local Tmp_file=`mktemp`
    local Path1='/'
    local Path2='/data'
    local Test_file='read-only.test'

    # '/' read-only check
    # 用能否在对应分区创建文件来检测
    touch "$Path1""$Test_file" &>$Tmp_file
    if `grep -q "Read-only file system" "$Tmp_file"`; then
        local Check_result="YES"
        local Check_result_color='red'
    else
        local Check_result="NO"
        local Check_result_color='green'
    fi
    printf "%-10s%12s%25s | " "Read-only" "/:" \
        `Color_str "$Check_result_color" "$Check_result"`

    # '/usr/local' read-only check
    touch "$Path2""$Test_file" &>$Tmp_file
    if `grep -q "Read-only file system" "$Tmp_file"`; then
        local Check_result="YES"
        local Check_result_color='red'
    else
        local Check_result="NO"
        local Check_result_color='green'
    fi
    printf "%12s%25s\n" "/data:" \
        `Color_str "$Check_result_color" "$Check_result"`
    rm $Tmp_file -f &> /dev/null
}

Network_check(){
    local Eth_interface=`ls /etc/sysconfig/network-scripts/ifcfg-eth[0]|\
        grep -oP "eth\d"`
    for Interface in $Eth_interface
    do
        local Interface_link=`ethtool $Interface|awk '/Link/{print $NF}'`
        local Interface_duplex=`ethtool $Interface|awk '/Duplex/{print $NF}'`
        local Interface_speed=`ethtool $Interface|awk '/Speed/{print $NF}'`

        [ -z "$Interface_link" ] && Interface_link='unknow'
        [ -z "$Interface_duplex" ] && Interface_duplex='unknow'
        [ -z "$Interface_speed" ] && Interface_speed='unknow'

        if [ "$Interface_link" = "yes" ]; then
            Link_color='green'
        else
            Link_color='red'
        fi

        if [[ "$Interface_speed" =~ "100" ]]; then
            Speed_color='green'
        else
            Speed_color='red'
        fi

        if [[ "$Interface_duplex" = "Full" || "$Interface_duplex" = "full" ]]; then
            Duplex_color='green'
        else
            Duplex_color='red'
        fi

        if [ "$Interface_duplex" = "unknow" ]; then
            printf "%-11s  link:%-23s  speed:%-25s  mode:%-18s\n" \
                "$Interface" \
                "`Color_str "$Link_color" $Interface_link`" \
                "`Color_str "$Speed_color" $Interface_speed`" \
                "`Color_str "$Duplex_color" $Interface_duplex`"
        else
            printf "%-11s  link:%-23s  speed:%-27s  mode:%-18s\n" \
                "$Interface" \
                "`Color_str "$Link_color" $Interface_link`" \
                "`Color_str "$Speed_color" $Interface_speed`" \
                "`Color_str "$Duplex_color" $Interface_duplex`"
        fi
    done
}

Show_result(){
    if [ "$#" -ne 2 ]; then
        echo "Illegal function call"
        echo "$FUNCNAME Action statuscode"
        exit 1
    fi

    local Action="$1"
    local Status_code="$2"
    local Format="%-60s [ %s ]\n"

    if [ $Status_code -eq 0 ]; then
        local Result=' OK '
        local Color='green'
    elif [ $Status_code -eq 1 ];then
        local Result='FAIL'
        local Color='red'
    elif [ $Status_code -eq 2 ];then
        local Result='unknow'
        local Color='yellow'
    fi

    OLD_IFS="$IFS"
    IFS='______________________________________________________________'
    printf "$Format" "$Action" "`Color_str $Color $Result`"
    IFS="$OLD_IFS"
}


### 防火墙检测
Iptable_check(){
    iptables -L -n|grep -q "Chain INPUT (policy DROP)"
    local Ret_num="$?"
    Show_result "Iptable" "$Ret_num"
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

io_test() {
    (LANG=C dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

Sys_check(){
    cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    tram=$( free -m | awk '/Mem/ {print $2}' )
    uram=$( free -m | awk '/Mem/ {print $3}' )
    swap=$( free -m | awk '/Swap/ {print $2}' )
    uswap=$( free -m | awk '/Swap/ {print $3}' )
    up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )
    #load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    opsy=$( get_opsy )
    arch=$( uname -m )
    lbit=$( getconf LONG_BIT )
    kern=$( uname -r )
    ipv6=$( wget -qO- -t1 -T2 ipv6.icanhazip.com )
    disk_size1=($( LANG=C df -ahPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
    disk_size2=($( LANG=C df -ahPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
    disk_total_size=$( calc_disk ${disk_size1[@]} )
    disk_used_size=$( calc_disk ${disk_size2[@]} )
    
    site=`hostname`
    NET_CARD=`ip addr |awk -F ": " '{print $2}'| grep -vE "^$|docker|lo|ve"`
    for i in $NET_CARD; do 
        LAN_IP=`ifconfig $i|grep inet|grep -v inet6| awk '{print $2}'`;
    done
    WAN_IP=`wget -qO - ifconfig.co`

    printf "%-25s %-40s\n"  "hostname"                "`Color_str "green" "$site"`"
    printf "%-25s %-40s\n"  "WAN_IP"                  "`Color_str "green" "$WAN_IP"`"
    printf "%-25s %-40s\n"  "LAN_IP"                  "`Color_str "green" "$LAN_IP"`"
    printf "%-25s %-40s\n"  "CPU model"               "`Color_str "green" "$cname"`"
    printf "%-25s %-40s\n"  "Number of cores"         "`Color_str "green" "$cores"`"
    printf "%-25s %-40s\n"  "CPU frequency"           "`Color_str "green" "$freq MHz"`"
    printf "%-25s %-40s\n"  "Total size of Disk"      "`Color_str "green" "$disk_total_size GB ($disk_used_size GB Used)"`"
    printf "%-25s %-40s\n"  "Total amount of Mem"     "`Color_str "green" "$tram MB ($uram MB Used)"`"
    printf "%-25s %-40s\n"  "Total amount of Swap"    "`Color_str "green" "$swap MB ($uswap MB Used)"`"
    printf "%-25s %-40s\n"  "System uptime"           "`Color_str "green" "$up"`"
    #printf "%-25s %-40s\n"  "Load average"            "`Color_str "green" "$load"`"
    printf "%-25s %-40s\n"  "OS"                      "`Color_str "green" "$opsy"`"
    printf "%-25s %-40s\n"  "Arch"                    "`Color_str "green" "$arch ($lbit Bit)"`"
    printf "%-25s %-40s\n"  "Kernel"                  "`Color_str "green" "$kern"`"
}

Io_check(){
    io1=$( io_test )
    printf "%-25s %-40s\n"  "I/O speed(1st run)"   "`Color_str "green" "$io1"`"
    io2=$( io_test )
    printf "%-25s %-40s\n"  "I/O speed(2nd run)"   "`Color_str "green" "$io2"`"
    io3=$( io_test )
    printf "%-25s %-40s\n"  "I/O speed(3rd run)"   "`Color_str "green" "$io3"`"
    ioraw1=$( echo $io1 | awk 'NR==1 {print $1}' )
    [ "`echo $io1 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
    ioraw2=$( echo $io2 | awk 'NR==1 {print $1}' )
    [ "`echo $io2 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
    ioraw3=$( echo $io3 | awk 'NR==1 {print $1}' )
    [ "`echo $io3 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
    ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
    ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
    printf "%-25s %-40s\n"   "Average I/O speed"    "`Color_str "green" "$ioavg"MB/s`"
}

Check(){
echo '-------------------------- Hardware Info. ----------------------------'
Load_check 
Disk_read_only_check 
#echo '-------------------------- Network  Info.  ---------------------------'
#Network_check 
echo '-------------------------- Iptable Info.  ----------------------------'
Iptable_check
echo '-------------------------- System Info.   ----------------------------'
Sys_check
#echo '-------------------------- I/O Info.      ----------------------------'
#Io_check
}

Check

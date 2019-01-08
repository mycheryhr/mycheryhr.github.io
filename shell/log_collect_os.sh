#!/bin/bash
LOG=/tmp/log_collect



CURRENT_SCRIPT=$(basename $0)
CSFILE=${CURRENT_SCRIPT}.txt

VAR_OPTION_WAIT_TRACE=0

wait_trace_on() {
	if (( $VAR_OPTION_WAIT_TRACE )); then
		OPT=$1
		case $OPT in
		-t) TEE=0; shift ;;
		*) TEE=1 ;;
		esac
		LOGGING="$@"
		WT_START=$(date +%T:%N)
		if (( $TEE )); then
			printf "%s" "    <$WT_START> $LOGGING  " | tee -a ${LOG}/${CSFILE}
		else
			printf "%s" "    <$WT_START> $LOGGING  "
		fi
	fi
}

wait_trace_off() {
	if (( $VAR_OPTION_WAIT_TRACE )); then
	OPT=$1
		case $OPT in
		-t) TEE=0 ;;
		*) TEE=1 ;;
		esac
		WT_END=$(date +%T:%N)
		if (( $TEE )); then
			echo "<$WT_END>" | tee -a ${LOG}/${CSFILE}
		else
			echo "<$WT_END>"
		fi
	fi
}


# Input: logfilename command
log_cmd() {
	EXIT_STATUS=0
	LOGFILE=$LOG/$1
	shift
	CMDLINE_ORIG="$@"
	CMDBIN=$(echo $CMDLINE_ORIG | awk '{print $1}')
	CMD=$(\which $CMDBIN 2>/dev/null | awk '{print $1}')
	echo "#==[ Command ]======================================#" >> $LOGFILE
	if [ -x "$CMD" ]; then
		CMDLINE=$(echo $CMDLINE_ORIG  | sed -e "s!${CMDBIN}!${CMD}!")
		echo "# $CMDLINE" >> $LOGFILE
		wait_trace_on "$CMDLINE"
		echo "$CMDLINE" | bash  >> $LOGFILE 2>&1
		EXIT_STATUS=$?
		wait_trace_off
	else
		if type $CMDBIN  2>/dev/null |grep builtin >/dev/null 2>&1 ;then
			CMDLINE=$(echo $CMDLINE_ORIG )
                	echo "# $CMDLINE" >> $LOGFILE
                	wait_trace_on "$CMDLINE"
			echo "$CMDLINE" | bash  >> $LOGFILE 2>&1
                	EXIT_STATUS=$?
                	wait_trace_off
		else

			echo "# $CMDLINE_ORIG" >> $LOGFILE
			echo "ERROR: Command not found or not executible" >> $LOGFILE
			EXIT_STATUS=1
		fi
	fi
	echo >> $LOGFILE
	return $EXIT_STATUS
}

# Input: logfilename "text"
log_write() {
	LOGFILE=$LOG/$1
	shift
	echo "$@" >> $LOGFILE
}

printlog() {
	CSLOGFILE=$LOG/${CSFILE}
	printf "  %-45s" "$@" | tee -a $CSLOGFILE
}


echolog() {
	CSLOGFILE=$LOG/${CSFILE}
	echo "$@" | tee -a $CSLOGFILE
}

timed_progress() {
	CSLOGFILE=$LOG/${CSFILE}
	printf "." | tee -a $CSLOGFILE
}

conf_files() {
	LOGFILE=$LOG/$1
	shift
	for CONF in $@
	do
		echo "#==[ Configuration File ]===========================#" >> $LOGFILE
		if [ -f $CONF ]; then
			echo "# $CONF" >> $LOGFILE
			wait_trace_on "$CONF"
			cat $CONF 2>> $LOG/$CSFILE | sed -e 's/\r//g' >> $LOGFILE 2>> $LOG/$CSFILE
			echo >> $LOGFILE
			wait_trace_off
		else
			echo "# $CONF - File not found" >> $LOGFILE
		fi
		echo >> $LOGFILE
	done
}

log_files() {
	LOGFILE=$LOG/$1
	shift
	LOGLINES=$1
	shift
	for CONF in $@
	do
		BAD_FILE=$(echo "$CONF" | egrep "\.tbz$|\.bz2$|\.gz$|\.zip$|\.xz$")
		if [ -n "$BAD_FILE" ]; then
			continue
		fi
		echo "#==[ Log File ]=====================================#" >> $LOGFILE
		CONF=$(echo $CONF | sed -e "s/%7B%20%7D%7B%20%7D/ /g")
		if [ -f "$CONF" ]; then
			wait_trace_on "$CONF"
			if [ $LOGLINES -eq 0 ]; then
				echo "# $CONF" >> $LOGFILE
				sed -e 's/\r//g' "$CONF" >> $LOGFILE
			else
				echo "# $CONF - Last $LOGLINES Lines" >> $LOGFILE
				tail -$LOGLINES "$CONF" | sed -e 's/\r//g' >> $LOGFILE
			fi
			echo >> $LOGFILE
			wait_trace_off
		else
			echo "# $CONF - File not found" >> $LOGFILE
		fi
		echo >> $LOGFILE
	done
}

ping_addr() {
	OF=$1
	ADDR_STRING="$2"
	ADDR_PING=$3
	if [ -n "$ADDR_PING" ]; then
		if log_cmd $OF "ping -n -c1 -W1 $ADDR_PING"; then
			log_write $OF "# Connectivity Test, $ADDR_STRING $ADDR_PING: Success"
		else
			log_write $OF "# Connectivity Test, $ADDR_STRING $ADDR_PING: Failure"
		fi
	else
		log_write $OF "# Connectivity Test, $ADDR_STRING: Missing"
	fi
	log_write $OF
}


# Input: logfilename rpm
# Assumes the rpm is installed and $LOG/$RPMFILE has been created
rpm_verify() {
	RPMPATH=$LOG/$RPMFILE
	LOGFILE=$LOG/$1
	INPUT_RPM=$2
	echo "#==[ Verification ]=================================#" >> $LOGFILE
	if rpm -q $INPUT_RPM &>/dev/null
	then
		for RPM in $(rpm -q $INPUT_RPM)
		do
			echo "# rpm -V $RPM" >> $LOGFILE
			wait_trace_on "rpm -V $RPM"
			rpm -V $RPM >> $LOGFILE 2>&1
			ERR=$?
			wait_trace_off
			if [ $ERR -gt 0 ]; then
				echo "# Verification Status: Differences Found" >> $LOGFILE
			else
				echo "# Verification Status: Passed" >> $LOGFILE
			fi
			echo >> $LOGFILE
		done
		#cat $RPMPATH | grep "^$INPUT_RPM " >> $LOGFILE
		#echo >> $LOGFILE
		return 0
	else
		echo "# RPM Not Installed: $INPUT_RPM" >> $LOGFILE
		echo >> $LOGFILE
		return 1
	fi
}

boot_info() {
	printlog "Boot Files..."
	OF=boot.txt
	log_cmd $OF "uname -a"
	if rpm -q grub &> /dev/null; then
		conf_files $OF /etc/grub.conf /boot/grub/menu.lst /boot/grub/device.map
	fi
	if rpm -q grub2 &> /dev/null; then
		conf_files $OF /etc/default/grub  /boot/grub2/device.map  /boot/grub2/grub.cfg
	fi

	log_cmd $OF 'last -xF | egrep "reboot|shutdown|runlevel|system"'

	conf_files $OF /proc/cmdline /etc/sysconfig/kernel  /etc/rc.d/rc.local /etc/rc.d/boot.local 

	log_cmd $OF 'ls -lR --time-style=long-iso /boot/'
	conf_files $OF /var/log/boot.log /var/log/dmesg 
	log_cmd $OF 'dmesg'
	echolog Done
}


ssh_info() {
	printlog "SSH..."
	OF=ssh.txt
	if rpm_verify $OF openssh
	then
		if (( os_ver >= 7 ))
		then
			log_cmd $OF "systemctl status sshd.service"
		else
			log_cmd $OF "chkconfig sshd --list"
		fi
		conf_files $OF /etc/ssh/sshd_config /etc/ssh/ssh_config /etc/pam.d/sshd
		log_cmd $OF 'netstat -nlp | grep sshd'
		echolog Done
	else
		echolog Skipped
	fi
}

pam_info() {
	printlog "PAM..."
	OF=pam.txt
	rpm_verify $OF pam
	conf_files $OF /etc/nsswitch.conf /etc/hosts
	conf_files $OF /etc/passwd
	log_cmd $OF 'getent passwd'
	conf_files $OF /etc/group
	log_cmd $OF 'getent group'
	conf_files $OF /etc/sudoers
	 log_cmd $OF 'loginctl --no-pager list-sessions'
	log_write $OF "#==[ Files in /etc/security ]=======================#"
	test -d /etc/security && FILES="$(find -L /etc/security/ -type f -name \*conf)" || FILES=""
	conf_files $OF $FILES
	log_write $OF "#==[ Files in /etc/pam.d ]==========================#"
	test -d /etc/pam.d && FILES="$(find -L /etc/pam.d/ -type f)" || FILES=""
	conf_files $OF $FILES
	echolog Done
}

environment_info() {
	printlog "Environment..."
	OF=env.txt
	log_cmd $OF 'ulimit -a'

	if (( os_ver >= 7 ))
	then
		log_cmd $OF "systemctl status sysctl"
	else
		log_cmd $OF "chkconfig boot.sysctl"
	fi
	conf_files $OF /etc/sysctl.conf /boot/sysctl.conf-* /lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /usr/local/lib/sysctl.d/*.conf /etc/sysctl.d/*.conf /run/sysctl.d/*.conf
	


	log_cmd $OF 'sysctl -a'
	log_cmd $OF 'getconf -a'
	log_cmd $OF 'ipcs -l'
	log_cmd $OF 'ipcs -a'
	log_cmd $OF 'env'
	
	conf_files $OF /etc/profile /etc/profile.local /etc/profile.d/*
	conf_files $OF /etc/bash.bashrc /etc/csh\.* /root/.bash_history 
	sed -i -e 's/\r//g' $LOG/$OF
	echolog Done
}

cron_info() {
	printlog "CRON..."
	OF=cron.txt
	if rpm_verify $OF cronie
	then
		if (( os_ver >= 7 ))
		then
			log_cmd $OF "systemctl status crond.service"
		else
			log_cmd $OF "chkconfig crond --list"
		fi
		conf_files $OF /var/spool/cron/allow /var/spool/cron/deny
		log_write $OF "### Individual User Cron Jobs ###"
		test -d /var/spool/cron/tabs && FILES=$(find -L /var/spool/cron/tabs/ -type f) || FILES=""
		conf_files $OF $FILES
		CRONS="cron.d cron.hourly cron.daily cron.weekly cron.monthly"
		log_write $OF "### System Cron Job File List ###"
		for CRONDIR in $CRONS
		do
			log_cmd $OF "find -L /etc/${CRONDIR}/ -type f"
		done
		log_write $OF "### System Cron Job File Content ###"
		conf_files $OF /etc/crontab
		for CRONDIR in $CRONS
		do
			FILES=$(find -L /etc/${CRONDIR}/ -type f)
			conf_files $OF $FILES
		done
		echolog Done
	else
		echolog Skipped
	fi
}

chkconfig_info() {
        printlog "System Daemons..."
        OF=chkconfig.txt
        log_cmd $OF 'chkconfig --list'
        LOGFILE=$LOG/$OF
        log_write $OF
        log_cmd $OF 'ls -lR --time-style=long-iso /etc/init.d/'
        log_cmd $OF 'ls -lR --time-style=long-iso /etc/xinetd.d/'
        FILES=$(find /etc/xinetd.d/ -type f)
        conf_files $OF $FILES
        echolog Done
}

systemd_info() {
	printlog "SystemD..."
	OF=systemd.txt
	rpm_verify $OF systemd
	log_cmd $OF 'hostnamectl status'
	log_cmd $OF 'systemctl --failed'
	log_cmd $OF 'busctl --no-pager --system list'
	log_cmd $OF 'timedatectl --no-pager status'
	log_cmd $OF 'systemd-analyze --no-pager blame'
	log_cmd $OF 'systemd-cgtop --batch --iterations=1'
	log_cmd $OF 'systemd-cgls --no-pager --all --full'
	FILES=''
	[[ -d /etc/systemd ]] && FILES=$(find -L /etc/systemd -maxdepth 1 -type f)
	log_cmd $OF 'systemctl --no-pager show'
	conf_files $OF $FILES
	log_cmd $OF 'systemctl --no-pager --all list-units'
	log_cmd $OF 'systemctl --no-pager --all list-sockets'
	log_cmd $OF 'systemctl --no-pager list-unit-files'
	for i in $(systemctl --no-pager --all list-units | egrep -v '^UNIT |^LOAD |^ACTIVE |^SUB |^To |^[[:digit:]]* ' | awk '{print $1}')
	do
		if [[ -z "$i" ]]
		then
			break
		else
			log_cmd $OF "systemctl show '$i'"
		fi
	done
	log_cmd $OF 'ls -alR /etc/systemd/'
	log_cmd $OF 'ls -alR /usr/lib/systemd/'
	echolog Done
}
open_files() {
        printlog "Open Files..."
        OF=open-files.txt
        if rpm_verify $OF lsof
        then    
                log_cmd $OF "lsof -b +M -n -l"
                echolog Done 
        else            
                echolog Skipped
        fi              
}
lvm_info() {
	printlog "LVM..."
	OF=lvm.txt
	if rpm_verify $OF lvm2
	then
		VGBIN="vgs"
		LVBIN="lvs"
		if (( os_ver >= 7)); then
			log_cmd $OF "systemctl status 'lvm2-activation-early.service'"
			FILES="/etc/lvm/lvm.conf"
			log_cmd $OF 'pvs'
		else
			log_cmd $OF 'chkconfig boot.device-mapper'
			log_cmd $OF 'chkconfig boot.lvm'
			log_cmd $OF 'chkconfig boot.md'
			log_cmd $OF 'chkconfig boot.evms'
			FILES="/etc/lvm/lvm.conf /etc/sysconfig/lvm /etc/lvm/.cache"
			log_cmd $OF 'pvscan'
		fi
		log_cmd $OF "vgs"
		log_cmd $OF "lvs"
		conf_files $OF $FILES
		log_cmd $OF 'dmsetup ls --tree'
		log_cmd $OF 'dmsetup table'
		log_cmd $OF 'dmsetup info'
		log_cmd $OF 'ls -l --time-style=long-iso /etc/lvm/backup/'
		conf_files $OF /etc/lvm/backup/*
		log_cmd $OF 'ls -l --time-style=long-iso /etc/lvm/archive/'
		conf_files $OF /etc/lvm/archive/*
		log_write $OF
		log_write $OF "###[ Detail Scans ]###########################################################################"
		log_write $OF
		log_cmd $OF 'pvdisplay -vv'
		log_cmd $OF 'vgdisplay -vv'
		log_cmd $OF 'lvdisplay -vv'
		log_cmd $OF 'pvs -vvvv'
		log_cmd $OF 'pvscan -vvv'
		log_cmd $OF "$VGBIN -vvvv"
		log_cmd $OF "$LVBIN -vvvv"
		echolog Done
	else
		echolog Skipped
	fi
}

runtime_check() {
	# This is a minimum required function, do not exclude
	printlog "runtime check..."
	OF=runtime_check.txt

	log_cmd $OF 'cat /etc/centos-release'
	log_cmd $OF 'uptime'
	log_cmd $OF 'vmstat 1 4'
	log_cmd $OF 'free -k'
	log_cmd $OF 'df -h'
	log_cmd $OF 'df -i'


	for MODULE in $(cat /proc/modules | awk '{print $1}')
	do
		LIST_MODULE=0
		modinfo -l $MODULE &>/dev/null
		if [ $? -gt 0 ]; then
			log_write $OF "$(printf "%-25s %-25s %-25s" module=$MODULE ERROR "Module info unavailable")"
		else
			wait_trace_on "modinfo -l $MODULE"
			LIC=$(modinfo -l $MODULE | head -1)
			SUP=$(modinfo -F supported $MODULE | head -1)
			test -z "$LIC" && LIC=None
			test -z "$SUP" && SUP=no
			GPLTEST=$(echo $LIC | grep GPL)
			test -z "$GPLTEST" && ((LIST_MODULE++))
			test "$SUP" != "yes" && ((LIST_MODULE++))
			test $LIST_MODULE -gt 0 && log_write $OF "$(printf "%-25s %-25s %-25s" "module=$MODULE" "license=$LIC" "supported=$SUP")"
			LIST_MODULES_ANY=$((LIST_MODULES_ANY + LIST_MODULE))
			wait_trace_off
		fi
	done

	PSPTMP=$(mktemp $LOG/psout.XXXXXXXX)
	PSTMP=$(basename $PSPTMP)

	log_cmd $PSTMP 'ps axwwo user,pid,ppid,%cpu,%mem,vsz,rss,stat,time,cmd'

	log_write $OF "#==[ Checking Health of Processes ]=================#"
	log_write $OF "# egrep \" D| Z\" $PSPTMP"
	log_write $OF "$(grep -v ^# "$PSPTMP" | egrep " D| Z")"

	TOPTMP=$(mktemp $LOG/top.XXXXXXXX)
	log_write $OF
	log_write $OF "#==[ Summary ]======================================#"
	log_write $OF "# Top 10 CPU Processes"
	ps axwwo %cpu,pid,user,cmd | sort -k 1 -r -n | head -11 | sed -e '/^%/d' > $TOPTMP
	log_write $OF "%CPU   PID USER     CMD"
	log_write $OF "$(< $TOPTMP)"
	log_write $OF

	log_write $OF "#==[ Summary ]======================================#"
	log_write $OF "# Top 10 Memory Processes"
	ps axwwo %mem,pid,user,cmd | sort -k 1 -r -n | head -11 | sed -e '/^%/d' > $TOPTMP
	log_write $OF "%MEM   PID USER     CMD"
	log_write $OF "$(< $TOPTMP)"
	log_write $OF
	rm -f $TOPTMP

	

	MCE_LOG='/var/log/mcelog'
	FILES=$MCE_LOG
	if [[ -s $MCE_LOG ]]; then
		log_cmd $OF "ls -l --time-style=long-iso $MCE_LOG"
		test $ADD_OPTION_LOGS -gt 0 && log_files $OF 0 $FILES || log_files $OF $VAR_OPTION_LINE_COUNT $FILES
	fi

	cat $PSPTMP >> $LOG/$OF
	rm $PSPTMP

	echolog Done
}
memory_info() {
	printlog "Memory Details..."
	OF=memory.txt
	log_cmd $OF "vmstat 1 4"
	log_cmd $OF "free -k"
	conf_files $OF /proc/meminfo /proc/vmstat
	log_cmd $OF 'sysctl -a 2>/dev/null | grep ^vm'
	[ -d /sys/kernel/mm/transparent_hugepage/ ] && FILES=$(find /sys/kernel/mm/transparent_hugepage/ -type f) || FILES=''
	conf_files $OF /proc/buddyinfo /proc/slabinfo /proc/zoneinfo $FILES
	if rpm -q numactl &>/dev/null; then
		log_cmd $OF 'numactl --hardware'
		log_cmd $OF 'numastat'
	fi
	if [ -x /usr/bin/pmap ]; then
		for I in $(ps axo pid)
		do
			log_cmd $OF "pmap $I"
		done
	fi
	echolog Done
}

net_info() {
	printlog "Networking..."
	OF=network.txt
	rpm_verify $OF sysconfig
	if (( os_ver >= 7 ))
	then
		log_cmd $OF "systemctl status network.service"
		log_cmd $OF "systemctl status nscd.service"
	else
		log_cmd $OF "chkconfig network --list"
		log_cmd $OF "chkconfig nscd --list"
	fi
	log_cmd $OF 'ifconfig -a'
	log_cmd $OF "ip addr"
	log_cmd $OF "ip route"
	log_cmd $OF "ip -s link"
	conf_files $OF /proc/sys/net/ipv4/ip_forward /etc/HOSTNAME /etc/services
	log_cmd $OF 'hostname'
	IPADDRS=$(ip addr | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
	for IPADDR in $IPADDRS
	do
		ping_addr $OF 'Local Interface' $IPADDR
	done

	IPADDR=$(route -n | awk '$1 == "0.0.0.0" {print $2}')
	ping_addr $OF 'Default Route' $IPADDR

	test -e /etc/resolv.conf && IPADDRS=$(grep ^nameserver /etc/resolv.conf | cut -d' ' -f2) || IPADDRS=""
	for IPADDR in $IPADDRS
	do
		ping_addr $OF 'DNS Server' $IPADDR
	done

	log_cmd $OF 'route'
	log_cmd $OF 'route -n'
	log_cmd $OF 'netstat -as'
	log_cmd $OF 'netstat -nlp'
	log_cmd $OF 'netstat -nr'
	log_cmd $OF 'netstat -i'
	log_cmd $OF 'arp -v'
	for NIC in /sys/class/net/*
	do
		if [[ -e ${NIC}/type ]]; then
			[[ "`cat ${NIC}/type`" = 772 ]] && continue
			NIC="${NIC##*/}"
			log_cmd $OF "ethtool $NIC"
			log_cmd $OF "ethtool -k $NIC"
			log_cmd $OF "ethtool -i $NIC"
			log_cmd $OF "ethtool -S $NIC"
			log_cmd $OF "mii-tool -v $NIC"
		fi
	done
	log_cmd $OF "nscd -g"
	conf_files $OF /etc/hosts /etc/host.conf /etc/resolv.conf /etc/nsswitch.conf /etc/nscd.conf /etc/hosts.allow /etc/hosts.deny
	for TABLE in filter nat mangle raw
	do
		if grep iptable_$TABLE /proc/modules &>/dev/null
		then
			log_cmd $OF "iptables -t $TABLE -nvL"
			log_cmd $OF "iptables-save -t $TABLE"
		else
			log_write $OF "# NOTE: The iptable_$TABLE module is not loaded, skipping check"
			log_write $OF
		fi
	done
	test -d /etc/sysconfig/network && FILES=$(find -L /etc/sysconfig/network/ -maxdepth 1 -type f) || FILES=""
	conf_files $OF /etc/sysconfig/proxy $FILES 
	sed -i -e 's/.*_PASSWORD[[:space:]]*=.*/*REMOVED BY SUPPORTCONFIG*/g' $LOG/$OF
	conf_files $OF $FILES
	if [ -d /proc/net/bonding ]; then
		FILES=$(find /proc/net/bonding/ -type f)
		conf_files $OF $FILES 
	fi
	FILES=$(grep logfile /etc/nscd.conf 2> /dev/null | grep -v ^# | awk '{print $2}' | tail -1)
	test -n "$FILES" || FILES="/var/log/nscd.log"
	log_files $OF 0 $FILES
	echolog Done
}

disk_info() {
	printlog "Disk I/O..."
	OF=fs-diskio.txt
	log_cmd $OF 'fdisk -l 2>/dev/null | grep Disk'
	conf_files $OF /proc/partitions /etc/fstab
	log_cmd $OF "mount"
	conf_files $OF /proc/mounts /etc/mtab


	log_cmd $OF 'ls -lR --time-style=long-iso /dev/disk/'
	log_cmd $OF 'ls -l --time-style=long-iso /sys/block/'


	log_cmd $OF 'iostat -x 1 4'
	log_cmd $OF 'sg_map -i -x'
	if [ -d /sys/block ]; then
		SCSI_DISKS=$(find /sys/block/ -maxdepth 1 | grep sd\.)
	else
		SCSI_DISKS=""
	fi

	if [ -n "$SCSI_DISKS" ]; then
		log_write $OF "#==[ SCSI Detailed Info ]===========================#"
		log_write $OF "#---------------------------------------------------#"
		log_cmd $OF 'lsscsi'
		log_cmd $OF 'lsscsi -H'
		[[ -x /bin/lsblk ]] && log_cmd $OF "lsblk -o 'NAME,KNAME,MAJ:MIN,FSTYPE,LABEL,RO,RM,MODEL,SIZE,OWNER,GROUP,MODE,ALIGNMENT,MIN-IO,OPT-IO,PHY-SEC,LOG-SEC,ROTA,SCHED,MOUNTPOINT'"
		if log_cmd $OF 'scsiinfo -l'
		then
			FILES=$(scsiinfo -l)
			for DEVICE in $FILES
			do
				log_cmd $OF "scsiinfo -i $DEVICE"
			done
		fi
		log_cmd $OF 'lsscsi -v'
		test -d /proc/scsi && SCSI_DIRS=$(find /proc/scsi/ -type d) || SCSI_DIRS=""
		for SDIR in $SCSI_DIRS
		do
			test "$SDIR" = "/proc/scsi" -o "$SDIR" = "/proc/scsi/sg" -o "$SDIR" = "/proc/scsi/mptspi" && continue
			FILES=$(find ${SDIR}/ -maxdepth 1 -type f 2>/dev/null)
			conf_files $OF $FILES
		done
	fi

	echolog Done
}
crash_info() {
	printlog "Crash Info..."
	# Call fslist_info first to search for core files
	OF=crash.txt
	KDUMP_CONFIG_FILE="/etc/kdump.conf"
	DUMPDIR=`grep ^path $KDUMP_CONFIG_FILE | cut -d' '  -f2-`

	rpm_verify $OF kexec-tools
	log_cmd $OF "uname -r"
	if (( os_ver >= 7 ))
	then
		log_cmd $OF "systemctl status kdump.service"
	else
		log_cmd $OF "chkconfig kdump --list"
	fi
	if [ -d $DUMPDIR ]; then
		log_cmd $OF "find -L ${DUMPDIR}/"
		rsync -avq  --exclude='*vmcore' ${DUMPDIR}/   ${LOG}/
	else
		log_entry $OF conf "KDUMP_SAVEDIR not found: ${DUMPDIR}"
	fi
	echolog Done
}


messages_file() {
	# This is a minimum required function, do not exclude
	printlog "System Logs..."
	OF=messages.txt
	MSG_COMPRESS="\.gz"
	FILES="$(ls -1 /var/log/secure-*${MSG_COMPRESS} 2>/dev/null) $(ls -1 /var/log/messages-*${MSG_COMPRESS} 2>/dev/null)"
	FILES="$(find /var/log/ -name "secure-*${MSG_COMPRESS}" -mtime -30 2>/dev/null) $(find /var/log/ -name "messages-*${MSG_COMPRESS}"  -mtime 30 2>/dev/null)"
	log_files $OF 0 /var/log/secure  /var/log/messages
	for CMPLOG in $FILES
	do
		FILE=$CMPLOG
	
		cp $CMPLOG ${LOG}
	done
	echolog Done
}


##main
if [ ! -f /etc/centos-release ] ;then 
	echo "not centos system,exit."
fi

space=$(df -hm / | tail -n 1  |awk '{print $(NF-2) }')

[ $space -gt 20 ] || ( echo "no enough space at /" && exit 1 )


if [ `whoami` != "root" ];then
	echo " only root can run me"
	exit 1
fi 

os_ver=$(cat /etc/centos-release |awk '{print $(NF-1)}'|awk -F '.' '{print $1}')

mkdir -p $LOG

boot_info
ssh_info
pam_info
environment_info
if [ $os_ver -eq 6 ] ;then
	chkconfig_info	
else
	systemd_info
fi
open_files
lvm_info
cron_info
net_info
disk_info
runtime_check
memory_info
crash_info
messages_file


echo "========================================================"
echo "creating tar ball ....."
TARBALL=$(hostname)_$(date +%F-%H%M).tgz

cd $LOG
cd ..
wait_trace_on -t "tar zvcf ${TARBALL} ${LOG}/*"
tar zvcf ${TARBALL}  ${LOG}/* >/dev/null 2>&1
LOGSIZE=$(ls -lh ${TARBALL} | awk '{print $5}')
wait_trace_off -t
wait_trace_on -t "md5sum $TARBALL"
md5sum $TARBALL | awk '{print $1}' > ${TARBALL}.md5
LOGMD5=$(cat ${TARBALL}.md5)
wait_trace_off -t

[ -f $TARBALL ] && echo "the log is saved at $(pwd)/$TARBALL,please send it to support engineer."


rm -rf $LOG




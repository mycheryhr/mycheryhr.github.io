#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

#Install wget
yum install wget -y
cd /usr/local/src

#Install yum source
#wget rpms.famillecollet.com/enterprise/6/remi/x86_64/remi-release-6.5-1.el6.remi.noarch.rpm
#wget http://mirrors.hustunique.com/epel/6/i386/epel-release-6-8.noarch.rpm
#yum localinstall epel-release-6-8.noarch.rpm  -y
#sed -i 's/mirrorlist=https/mirrorlist=http/g' /etc/yum.repos.d/epel.repo
#rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
#yum localinstall remi-release-6.5-1.el6.remi.noarch.rpm -y
#yum makecache

#Install Development Environment#
yum groupinstall "Development tools" -y
yum install wget curl screen goaccess openssh-clients vim gcc gcc-c++ glibc vim-enhanced unzip net-snmp net-snmp-libs perl-CPAN net-snmp-utils unrar lsof sysstat nmap ntpdate tcpdump htop GeoIP openssl openssl-devel iftop sysstat istop sar -y

#Disabled Selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

#Install Tsar Tools
cd /usr/local/src
wget -O tsar.zip http://mirrors.ppd.com/software/tools/tsar-master.zip --no-check-certificate
unzip tsar.zip
cd tsar-master/
make
make install

#Sync Time
echo '*/5 * * * * /usr/sbin/ntpdate pool.ntp.org > /dev/null 2>&1' > /var/spool/cron/root

#Modefy The Sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf`date +%Y-%m-%d_%H-%M-%S`
cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.tcp_max_tw_buckets = 20000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 262144
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_fin_timeout = 1
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 1024 65535
net.nf_conntrack_max = 655350
net.netfilter.nf_conntrack_max = 655350
net.netfilter.nf_conntrack_tcp_timeout_established = 180
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
vm.swappiness = 0
EOF
/sbin/sysctl -p

#For Vim Syntax
echo "syntax on" >> /root/.vimrc
echo "set nohlsearch" >> /root/.vimrc

#SSH Config
sed -i '/^#Port/s/#Port 22/Port 23245/g' /etc/ssh/sshd_config
sed -i '/^#UseDNS/s/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config

#set privileges
#chmod 600 /etc/passwd
#chmod 600 /etc/shadow
#chmod 600 /etc/group
#chmod 600 /etc/gshadow

#password length limit
sed -i 's/PASS_MIN_LEN\([\t ]*\)5/PASS_MIN_LEN\18/' /etc/login.defs

#set user
cp /etc/passwd /etc/passwd.sav
cp /etc/group /etc/group.sav
for a in adm lp sync news uucp operator games gopher mailnull nscd rpc;
do /usr/sbin/userdel $a -f; done

#set the file limit
echo "ulimit -SHn 102400" >> /etc/rc.local
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF


#set the control-alt-delete to guard against the misuse
sed -i 's#exec /sbin/shutdown -r now#\#exec /sbin/shutdown -r now#' /etc/init/control-alt-delete.conf

#disable the ipv6
cat > /etc/modprobe.d/ipv6.conf << EOF
alias net-pf-10 off
options ipv6 disable=1
EOF


#Restart sshd and config for the Firewall
cat > /etc/sysconfig/iptables << EOF
# Firewall configuration written by system-config-firewall
# Manual customization of this file is not recommended.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 23245 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

service sshd restart
service iptables restart

#set histsize
sed -i 's/HISTSIZE=1000/HISTSIZE=500/' /etc/profile
source /etc/profile
echo 'export  HISTTIMEFORMAT="`whoami` : %F %T :"' >> /root/.bash_profile

#config snmp
cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf`date +%Y-%m-%d_%H-%M-%S`
cat > /etc/snmp/snmpd.conf << EOF
com2sec notConfigUser  127.0.0.1       public
com2sec notConfigUser  192.168.100.250      public
com2sec notConfigUser  192.168.200.250       public
group   notConfigGroup v1           notConfigUser
group   notConfigGroup v2c           notConfigUser
view    systemview    included   .1.3.6.1.2.1.1
view    systemview    included   .1.3.6.1.2.1.25.1.1
access  notConfigGroup ""      any       noauth    exact  all none none
view all    included  .1                               80
syslocation Unknown (edit /etc/snmp/snmpd.conf)
syscontact Root <root@localhost> (configure /etc/snmp/snmp.local.conf)
dontLogTCPWrappersConnects yes
EOF

#services for start

chkconfig --add snmpd
chkconfig snmpd on
service snmpd start
service snmpd restart
chkconfig --del ip6tables
chkconfig ip6tables off

#update 
yum update -y
cat << EOF
+-------------------------------------------------+
| optimizer is done |
| it's recommond to restart this server ! |
+-------------------------------------------------+
EOF
#reboot

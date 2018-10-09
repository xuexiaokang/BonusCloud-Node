#!/bin/sh
# BxC-Node operation script for AM380 merlin firmware
# by sean.ley (ley@bonuscloud.io)

# load path environment in dbus databse
# eval `dbus export bxc`

BXC_DIR="/koolshare/bxc"
BXC_CONF="$BXC_DIR/bxc.config"
BXC_NETWORK="/koolshare/bin/bxc-network"
BXC_WORKER="/koolshare/bin/bxc-worker"
BXC_WORKER_PORT="8901"
BXC_SERVER="http://101.236.37.92"
BXC_TOOL="/koolshare/scripts/bxc-tool.sh"
BXC_PKG="bxc.tar.gz"

BXC_SSL_CA="/tmp/etc/bxc-network/ca.crt"
BXC_SSL_CRT="/tmp/etc/bxc-network/client.crt"
BXC_SSL_KEY="/tmp/etc/bxc-network/client.key"

BXC_BOUND_URL="https://117.48.224.43/idb/dev"
BXC_UPDATE_URL="https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/bxc.tar.gz"
BXC_INSTALL_PKG="bxc-x86.zip"
BXC_INSTALL_URL="http://qnw.oss-cn-shanghai.aliyuncs.com/bxc-x86.zip"


# source /koolshare/scripts/base.sh
# source $BXC_CONF
LOG_LEVEL="debug"

logdebug(){
  if [ "$LOG_LEVEL"x == "debug"x ];then
    #logger -c "INFO: $1" -t bonuscloud-node > logdebug.txt 2>&1
    echo "INFO: $1"
  fi
}

logerr(){
  if [ "$LOG_LEVEL"x == "error"x ] || [ "$LOG_LEVEL"x == "debug"x ];then
    #logger -c "ERROR: $1" -t bonuscloud-node > logerr.txt 2>&1
    echo "INFO: $1"
  fi
}

init(){
        rm -f /tmp/log-bxc > /dev/null 2>&1
        mkdir -p /opt/sbin/
        mkdir -p /opt/bin/
        ln -s /sbin/ifconfig /opt/sbin/ifconfig
	ln -s /sbin/route /opt/sbin/route
	ln -s /sbin/ip /opt/sbin/ip
	ln -s /bin/netstat /opt/bin/netstat
        #opkg_install
        opkg install liblzo libcurl libopenssl libstdcpp libltdl kmod-tun
        #pkg_install
        ipv6_enable
        vpn_env
}

vpn_env(){
        # vpn config file
        if [ ! -s $BXC_SSL_CA ];then
                if [ -s /koolshare/bxc/ca.crt ];then
                        logdebug "/koolshare/bxc/ca.crt exist, copy to $BXC_SSL_CA"
                        mkdir -p /tmp/etc/bxc-network
                        cp -f /koolshare/bxc/ca.crt $BXC_SSL_CA > /dev/null 2>&1
                else
                        logerr "ca.crt file not exist, please uninstall app and unbound device, reinstall and bound again."
                        exit 1
                fi
        fi

        if [ ! -s $BXC_SSL_CRT ];then
                if [ -s /koolshare/bxc/client.crt ];then
                        logdebug "/koolshare/bxc/client.crt exist, copy to $BXC_SSL_CRT"
                        mkdir -p /tmp/etc/bxc-network
                        cp -f /koolshare/bxc/client.crt $BXC_SSL_CRT > /dev/null 2>&1
                else
                        logerr "client.crt file not exist, please uninstall app and unbound device, reinstall and bound again."
                        exit 1
                fi
        fi

        if [ ! -s $BXC_SSL_KEY ];then
                if [ -s /koolshare/bxc/client.key ];then
                        logdebug "/koolshare/bxc/client.key exist, copy to $BXC_SSL_KEY"
                        mkdir -p /tmp/etc/bxc-network
                        cp -f /koolshare/bxc/client.key $BXC_SSL_KEY > /dev/null 2>&1
                else
                        logerr "client.key file not exist, please uninstall app and unbound device, reinstall and bound again."
                        exit 1
                fi
        fi

        # module
        modprobe tun > /dev/null 2>&1
        mod_exist=`lsmod | grep "tun" > /dev/null 2>&1;echo $?`
        if [ $mod_exist -eq 0 ];then
                logdebug "modprobe tun success"
        else
                logerr "modprobe tun failed, exit."
                exit 1
        fi

        # device
        if [ ! -e /dev/net/tun ];then
                logdebug "/dev/net/tun not exist, mkdir -p /dev/net/ && mknod /dev/net/tun c 10 200"
                mkdir -p /dev/net/ && mknod /dev/net/tun c 10 200
                if [ ! -e /dev/net/tun ];then
                        logerr "/dev/net/tun create failed, exit."
                        exit 1
                fi
        fi

        # /dev/shm permition
        if [ -d /dev/shm ];then
                logdebug "/dev/shm exist, chmod -R 777 /dev/shm/"
                chmod -R 777 /dev/shm/
        else
                logerr "device /dev/shm not exist, exit."
                exit 1
        fi

        # user nobody
        user_exist=`grep -e "^nobody:" /etc/passwd > /dev/null 2>&1;echo $?`
        if [ $user_exist -ne 0 ];then
                logdebug "append /etc/passwd 'nobody:x:65534:65534:nobody:/dev/null:/dev/null'"
                echo "nobody:x:65534:65534:nobody:/dev/null:/dev/null" >> /etc/passwd
        else
                logdebug "nobody exist /etc/passwd: `grep -e '^nobody:' /etc/passwd`"
        fi
        group_exist=`grep -e "^nobody:" /etc/group > /dev/null 2>&1;echo $?`
        if [ $group_exist -ne 0 ];then
                logdebug "append /etc/group 'nobody:x:65534:'"
                echo "nobody:x:65534:" >> /etc/group
        else
                logdebug "nobody exist /etc/group: `grep -e '^nobody:' /etc/group`"
        fi
}

ipv6_enable() {
        # enable ifconfig ipv6
        IPV6=`cat /proc/sys/net/ipv6/conf/all/disable_ipv6`
        logdebug "/proc/sys/net/ipv6/conf/all/disable_ipv6 value is $IPV6"
        if [ $IPV6 -ne 0 ];then
                logdebug "echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6"
                echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
        fi

        # check ip6tables
        ip6tables_exist=`which ip6tables > /dev/null 2>&1;echo $?`
        if [ $ip6tables_exist -ne 0 ];then
                logerr "ip6tables not exist, exit"
                exit 1
        fi

        # acl tcp 8901
        acl_exist=`ip6tables -C INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
                ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1
                check_exist=`ip6tables -C INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
                else
                        logdebug "success add: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0"
                fi
        else
                logdebug "acl exist: ip6tables -I INPUT -p tcp --dport 8901 -j ACCEPT -i tun0 "
        fi

        acl_exist=`ip6tables -C OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
                ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1
                check_exist=`ip6tables -C OUTPUT -p tcp --sport 8901 -j ACCEPT > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
                else
                        logdebug "success add: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
                fi
        else
                logdebug "acl exist: ip6tables -I OUTPUT -p tcp --sport 8901 -j ACCEPT"
        fi

        # acl icmpv6
        acl_exist=`ip6tables -C INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
                ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1
                check_exist=`ip6tables -C INPUT -p icmpv6 -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
                else
                        logdebug "success add: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
                fi
        else
                logdebug "acl exist: ip6tables -I INPUT -p icmpv6 -j ACCEPT -i tun0"
        fi

        acl_exist=`ip6tables -C OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
                ip6tables -I OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1
                check_exist=`ip6tables -C OUTPUT -p icmpv6 -j ACCEPT > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
                else
                        logdebug "success add: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
                fi
        else
                logdebug "acl exist: ip6tables -I OUTPUT -p icmpv6 -j ACCEPT"
        fi

        # acl udp
        acl_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
                ip6tables -I INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1
                check_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i tun0 > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
                else
                        logdebug "success add: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
                fi
        else
                logdebug "acl exist: ip6tables -I INPUT -p udp -j ACCEPT -i tun0"
        fi

        acl_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
                ip6tables -I INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1
                check_exist=`ip6tables -C INPUT -p udp -j ACCEPT -i lo > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
                else
                        logdebug "success add: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
                fi
        else
                logdebug "acl exist: ip6tables -I INPUT -p udp -j ACCEPT -i lo"
        fi

        acl_exist=`ip6tables -C OUTPUT -p udp -j ACCEPT > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: ip6tables -I OUTPUT -p udp -j ACCEPT"
                ip6tables -I OUTPUT -p udp -j ACCEPT > /dev/null 2>&1
                check_exist=`ip6tables -C OUTPUT -p udp -j ACCEPT > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: ip6tables -I OUTPUT -p udp -j ACCEPT"
                else
                        logdebug "success add: ip6tables -I OUTPUT -p udp -j ACCEPT"
                fi
        else
                logdebug "acl exist: ip6tables -I OUTPUT -p udp -j ACCEPT"
        fi

        # ipv4 acl tcp 80,443
        acl_exist=`iptables -C INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
                iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1
                check_exist=`iptables -C INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
                else
                        logdebug "success add: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
                fi
        else
                logdebug "acl exist: iptables -I INPUT -p tcp --match multiport --sports 80,443,8080 -j ACCEPT"
        fi

        acl_exist=`iptables -C OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
        if [ $acl_exist -ne 0 ];then
                logdebug "add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
                iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1
                check_exist=`iptables -C OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT > /dev/null 2>&1;echo $?`
                if [ $check_exist -ne 0 ];then
                        logerr "failed add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
                else
                        logdebug "success add: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
                fi
        else
                logdebug "acl exist: iptables -I OUTPUT -p tcp --match multiport --dports 80,443,8080 -j ACCEPT"
        fi
}

opkg_install() {
        opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
        if [ $opkg_exist -ne 0 ];then
                logdebug "opkg not found, install opkg: /koolshare/scripts/bxc-tool.sh"
                mkdir -p /tmp/opt && ln -s /tmp/opt /opt > /dev/null 2>&1
                chmod +x /koolshare/scripts/bxc-tool.sh > /dev/null 2>&1
                /koolshare/scripts/bxc-tool.sh > /dev/null 2>&1
        fi

        opkg_exist=`which opkg > /dev/null 2>&1;echo $?`
        if [ $opkg_exist -ne 0 ];then
                logerr "opkg install failed, exit"
                exit 1
        else
                logdebug "opkg install success"
        fi
}

pkg_install() {
        for pkg in `cat /koolshare/bxc/lib/install_order`
        do
                pkg_prefix=`echo "$pkg" | awk -F_ '{print $1}'`

                # 本地安装
                pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
                if [ $pkg_exist -ne 0 ];then
                        logdebug "$pkg not exist, install with local file /koolshare/bxc/lib/$pkg"
                        /opt/bin/opkg install "/koolshare/bxc/lib/$pkg" > /dev/null 2>&1
                else
                        logdebug "$pkg exist"
                        continue
                fi

                # 网络安装
                pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
                if [ $pkg_exist -ne 0 ];then
                        logdebug "$pkg loacal install failed, remote install with opkg..."
                        opkg update > /dev/null 2>&1
                        opkg install "$pkg_prefix" > /dev/null 2>&1
                fi

                # 检测
                pkg_exist=`opkg list-installed | grep "$pkg_prefix" > /dev/null 2>&1;echo $?`
                if [ $pkg_exist -ne 0 ];then
                        logerr "$pkg install failed, exit"
                        exit 1
                else
                        logdebug "$pkg install success"
                fi
        done
}


status_bxc(){
        network_status=`ps | grep "bxc-network" | grep -v grep > /dev/null 2>&1; echo $?`
        worker_status=`ps | egrep "bxc-worker|bxcworker" | grep -v grep > /dev/null 2>&1; echo $?`

        if [ $network_status == 0 ] && [ $worker_status == 0 ];then
                #dbus set bxc_status="running"
                logdebug "BxC-Node status is running: bxc-network status $network_status, bxc-worker status $worker_status"
        else
                #dbus set bxc_status="stoped"
                logdebug "BxC-Node status is stoped: bxc-network status $network_status, bxc-worker status $worker_status"
        fi
}

start_bxc(){
        status_bxc
        if [ $network_status -ne 0 ];then
                logdebug "bxc-network start..."
                chmod +x $BXC_NETWORK && $BXC_NETWORK > network.log 2>&1 &
                sleep 3
        fi
        if [ $worker_status -ne 0 ];then
                logdebug "bxc-worker start..."
                port_used=`netstat -lanp | grep "LISTEN" | grep ":$BXC_WORKER_PORT" > /dev/null 2>&1; echo $?`
                if [ $port_used -eq 0 ];then
                        logerr "bxc-worker listen port $BXC_WORKER_PORT already in use, please release and retry."
                else
                        chmod +x $BXC_WORKER && $BXC_WORKER > worker.log 2>&1 &
                        sleep 3
                fi
        fi
        sleep 2
        status_bxc
        if [ $network_status -ne 0 ] || [ $worker_status -ne 0 ];then
                logdebug "BxC-Node start failed."
                stop_bxc
        fi
}
stop_bxc(){
	logdebug "BxC-Node stop with command: ps | grep -v grep | egrep 'bxc-network|bxc-worker|bxcworker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1 "
	ps | grep -v grep | egrep 'bxc-network|bxc-worker|bxcworker' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1
	sleep 3
	status_bxc
}
#绑定bxc邀请码
bound_bxc(){
	# 添加验证码用户输入
	echo -n "Enter your fcode:"
	read bcode
	echo -n "Which net device?"
	ls /sys/class/net|grep eth|awk '{print }'
	read whichDevice
	echo -n "Your net device:"
	echo $whichDevice
	mac=$(ifconfig $whichDevice|grep HWaddr|awk '{print $5}')
	echo -n "Start to bound?(y/N)"
	read startBound
	if [ "$startBound"x == "y"x ];then
		echo "Start Bound"
	else
		echo "End!"
		exit 1
	fi

	if [ -z "$bcode" ]; then 
    	        echo "[ERROR] Your fcode is empty"
		exit 1
	elif [ -z "$mac" ];then
		echo "[ERROR] Your mac is empty"
		exit 1
	else
		echo "[INFO] Your fcode:$bcode"
		echo "[INFO] Your machine mac:$mac"
	fi
	
	mkdir -p /tmp/etc/bxc-network
	curl -k -m 5 -H "Content-Type: application/json" -d "{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}" -w "\nstatus_code:"%{http_code}"\n" $BXC_BOUND_URL > /koolshare/bxc/curl.res
	logdebug "curl -k -H \"Content-Type: application/json\" -d \"{\"fcode\":\"$bcode\", \"mac_address\":\"$mac\"}\" -w \"\nstatus_code:\"%{http_code}\"\n\" $BXC_BOUND_URL"
	curl_code=`grep 'status_code' /koolshare/bxc/curl.res | awk -F: '{print $2}'`
	if [ -z $curl_code ];then
                #dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
                logerr 'bonud server has no response code, exit'
                exit 1
	elif [ "$curl_code"x == "200"x ];then
                echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"key\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_KEY
                echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"cert\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CRT
                echo -e `cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep "\"Cert\",\"ca\"" | awk -F\" '{print $6}' | sed 's/"//g'` > $BXC_SSL_CA
                if [ ! -s $BXC_SSL_KEY ];then
                        #dbus set bxc_bound_status="获取key文件失败"
                        logerr 'no client key file'
                        exit 1
                elif [ ! -s $BXC_SSL_CRT ];then
                        #dbus set bxc_bound_status="获取crt文件失败"
                        logerr 'no client crt file'
                        exit 1
                elif [ ! -s $BXC_SSL_CA ];then
                        #dbus set bxc_bound_status="获取ca文件失败"
                        logerr 'no client ca file'
                        exit 1
                else
                        #dbus set bxc_bound_status="success"
                        #dbus set bxc_bcode="$bcode"
                        logdebug "bound success!"
                fi
	else
                cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' > /dev/null
                if [ $? -eq 0 ];then
                        fail_detail=`cat /koolshare/bxc/curl.res | /koolshare/scripts/bxc-json.sh | egrep '\["details"\]' | awk -F\" '{print $(NF-1)}'`
                        if [ "$fail_detail"x == "fcode used"x ];then
                                        #dbus set bxc_bound_status="邀请码已被使用"
                        logerr 'fcode used'
                                        elif [ "$fail_detail"x == "dev used"x ];then
                                                        #dbus set bxc_bound_status="设备已被绑定"
                        logerr 'device used'
                                        elif [ "$fail_detail"x == "fcode invalid"x ];then
                                                        #dbus set bxc_bound_status="无效的邀请码"
                        logerr 'fcode invalid'
                        #else
                                        #dbus set bxc_bound_status="$fail_detail"
                        fi
                        logerr "bound failed with server response: $fail_detail"
                        exit 1
                else
                        #dbus set bxc_bound_status="服务端没有响应绑定请求，请稍候再试"
                        logerr "Server response code: $curl_code, please check /koolshare/bxc/curl.res"
                        exit 1
                fi
	fi

	# 备份绑定信息（邀请码 + 证书文件）
	cp -f /tmp/etc/bxc-network/* /koolshare/bxc/
	chmod 600 /tmp/etc/bxc-network/*
	echo $bcode > /koolshare/bxc/bcode

	# 清理临时文件
	# rm -f /koolshare/bxc/curl.res
}
booton_bxc(){
        # 开启开机自启动
        if [ ! -L "/koolshare/init.d/S97bxc.sh" ]; then
        ln -sf /koolshare/scripts/bxc.sh /koolshare/init.d/S97bxc.sh
    fi
    [ ! -L "/koolshare/init.d/S97bxc.sh" ] && logerr "BxC-Node start onboot enable failed"
    #dbus set bxc_onboot="yes"
}
bootoff_bxc(){
        # 关闭开机自启动
    rm -f /koolshare/init.d/S97bxc.sh
    [ -L "/koolshare/init.d/S97bxc.sh" ] && logerr "BxC-Node start onboot disable failed"
    #dbus set bxc_onboot="no"
}
log_err(){
        if [ -f $BXC_CONF ];then
                sed -i '/^LOG_LEVEL=/d' $BXC_CONF > /dev/null 2>&1
                echo "LOG_LEVEL=\"error\"" >> $BXC_CONF
                #dbus set bxc_log_level="error"
        else
                logerr "$BXC_CONF not found, exit."
                exit 1
        fi
}
log_debug(){
        if [ -f $BXC_CONF ];then
                sed -i '/^LOG_LEVEL=/d' $BXC_CONF > /dev/null 2>&1
                echo "LOG_LEVEL=\"debug\"" >> $BXC_CONF
                #dbus set bxc_log_level="debug"
        else
                logerr "$BXC_CONF not found, exit."
                exit 1
        fi
}
cron_add(){
        cron_exist=`cru l | grep "/koolshare/scripts/bxc-mon.sh" > /dev/null 2>&1;echo $?`
        if [ $cron_exist -ne 0 ];then
                cru a BxcMon "*/10 * * * * /koolshare/scripts/bxc-mon.sh > /dev/null 2>&1"
        fi
}
cron_del(){
        cron_exist=`cru l | grep "/koolshare/scripts/bxc-mon.sh" > /dev/null 2>&1;echo $?`
        if [ $cron_exist -eq 0 ];then
                cru d BxcMon "*/10 * * * * /koolshare/scripts/bxc-mon.sh > /dev/null 2>&1"
        fi
}
install_bxc(){
        echo "Dowanlod package..."
        cd /tmp/ && rm -fr /tmp/bxc*
        wget $BXC_INSTALL_URL > /dev/null 2>&1
        if [ -s $BXC_INSTALL_PKG ];then
                unzip $BXC_INSTALL_PKG
                mv bxc-x86 /koolshare/
                chmod a+x /koolshare/scripts/bxc*
                chmod a+x /koolshare/bin/bxc*

                CUR_VERSION=`cat $BXC_DIR/version`
                #dbus set bxc_local_version="$CUR_VERSION"
                #dbus set softcenter_module_bxc_version="$CUR_VERSION"
                echo "Version infomation update:$CUR_VERSION"
                source $BXC_CONF
                #dbus set bxc_log_level="$LOG_LEVEL"

                rm -rf /tmp/bxc* >/dev/null 2>&1
        else
                echo "Dowanlod install package failed: wget $BXC_INSTALL_URL"
                exit 1
        fi
}
update_bxc(){
        stop_bxc

        logdebug "Dowanlod update package..."
        cd /tmp/ && rm -fr /tmp/bxc*
        wget -q -t 3 -O $BXC_PKG $BXC_UPDATE_URL > /dev/null 2>&1
        if [ -s $BXC_PKG ];then
                tar -zxf $BXC_PKG
                logdebug "Copy update files..."
                cp -rf /tmp/bxc/scripts/* /koolshare/scripts/
                cp -rf /tmp/bxc/bin/* /koolshare/bin/
                cp -rf /tmp/bxc/webs/* /koolshare/webs/
                cp -rf /tmp/bxc/res/* /koolshare/res/
                cp -rf /tmp/bxc/bxc/* /koolshare/bxc/
                cp -rf /tmp/bxc/install.sh /koolshare/scripts/bxc_install.sh
                cp -rf /tmp/bxc/uninstall.sh /koolshare/scripts/uninstall_bxc.sh
                chmod a+x /koolshare/scripts/bxc*
                chmod a+x /koolshare/bin/bxc*

                CUR_VERSION=`cat $BXC_DIR/version`
                #dbus set bxc_local_version="$CUR_VERSION"
                #dbus set softcenter_module_bxc_version="$CUR_VERSION"
                logdebug "Version infomation update:$CUR_VERSION"
                source $BXC_CONF
                #dbus set bxc_log_level="$LOG_LEVEL"

                rm -rf /tmp/bxc* >/dev/null 2>&1
        else
                logerr "Dowanlod update package failed: wget -q -t 3 -O $BXC_PKG $BXC_UPDATE_URL"
                exit 1
        fi
}

if [ -z "$1" ];then
        ACTION=``
else
        ACTION=$1
fi

logdebug "bxc-cmd.sh $ACTION"

case $ACTION in
init)
        init
        ;;
install)
        install_bxc
        ;;
start)
        #init
        #cron_add
        start_bxc
        ;;
stop)
        stop_bxc
        #cron_del
        ;;
restart)
        stop_bxc
        start_bxc
        ;;
status)
        status_bxc
        ;;
bound)
        bound_bxc
        ;;
booton)
        booton_bxc
        ;;
bootoff)
        bootoff_bxc
        ;;
debuglog)
        log_debug
        ;;
errorlog)
        log_err
        ;;
cronon)
        #cron_add
        ;;
cronoff)
        #cron_del
        ;;
update)
        update_bxc
        ;;
*)
        exit 1
    ;;
esac
#dbus set bxc_option=""
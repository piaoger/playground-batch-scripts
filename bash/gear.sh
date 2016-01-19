__GEAR_SH="GEAR_SH"

# add some path
export PATH=$PATH:/usr/bin:/usr/local/bin

DEV_NULL="/dev/null"

HOST_IP=`/sbin/ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
LAN_IP=`echo $HOST_IP | grep -E '^10.|^172.|^192.'`
WAN_IP=`echo $HOST_IP | grep -v -E '^10.|^172.|^192.'`

# int import(file)
# 0, succ
# 1, fail
function import()
{
	local file=${1:?"no file"}

	file=$(dirname $0)/$file
	if [ -f $file ] && [ -r $file ]; then
		. $file
	fi
}

# int is_sub_str(sub, str)
# 0, is sub string
# 1, not
function is_sub_str()
{
	local ret=1
	if [ $# -ge 2 ]; then
		local sub=$1
		local str=$2
		if [ -n $(echo "$str" | grep "$sub") ]; then
			return 0
		fi
	fi
	return 1
}

function add_num_sp()
{
	local rt=""
	if [ $# -ge 1 ]; then
		local num=$[$1]
		while [ $num -ge 1000 ]; do
			if [ -n "$rt" ]; then
				rt=$(printf "%03d,$rt" $((num%1000)))
			else
				rt=$(printf "%03d" $((num%1000)))
			fi
				num=$((num/1000))
		done
		if [ -n "$rt" ]; then
			rt=$(printf "%d,$rt" $num)
		else
			rt=$(printf "%d" $num)
		fi
	fi
	echo $rt
}

# void log(str)
# void log(log_file, str)
# default log_file is ~/log.txt
# e.g. log "shut" "pls check"
function log()
{
	local log_file=${1:?"no log str"}
	local log_str=$2

	# fix params
	if [ -z $log_str ]; then
		log_str=$log_file
		log_file="$HOME/log.txt"
	fi

	local now_time=`date '+%Y-%m-%d %H:%M:%S'`
	echo "$now_time: $log_str" >> "$log_file"
}

# void alarm(mobile, str)
# e.g. alarm "shut" "pls check"
function alarm()
{
	local mobile=${1:?"no mobile"}
	local str=$2
	local now_time=`date '+%Y-%m-%d %H:%M:%S'`
	
	alarm msg $mobile "$now_time: $str"
}

function make_tmp_file()
{
    local name=${1:-"rand"}
	local magic=`date +%s`
	echo "/tmp/__${magic}__${name}"
}

function make_rand_file()
{
	make_tmp_file "$*"
}

# int get_proc_num(cmd)
function get_proc_num()
{
	local cmd=${1:?"no cmd"}
	#local ps="ps -efww | grep '$cmd' | grep -v grep | wc -l"
	# e.g. ./a.out /bin/a.out a.out
	local ps="ps -e -o cmd | awk '{print \$1}' | grep -E '/${cmd}$|^${cmd}$' | grep -v grep | wc -l"
	local n=$(eval "$ps")
	echo "${n}"
}

# int check_proc(cmd, [num = 0], [max = num])
# default process num is 0
# 0, succ
# 1, fail
# 2, too few
# 3, too much
function check_proc_num()
{
	local cmd=${1:?"no cmd"}
	local num=$((${2:-0}))
	local max=$((${3:-num}))
	#local ps="ps -e -o cmd | awk '{print \$1}' | grep -E '/${cmd}$|^${cmd}$' | grep -v grep | wc -l"
	#local n=$(eval "$ps")
	local n=$(get_proc_num "${cmd}")

	# echo "cmd = $ps, num = $n, expect = [$num, $max]"

	if [ $n -lt $num ]; then
		return 2
	elif [ $n -gt $max ]; then
		return 3
	fi
	
	return 0
}

# int wait_proc_num(cmd, [num = 0], [max = num], [timeout = 5])
# if set timeout to 0, check one time
# 0, succ
# 1, fail
# 2, timeout
function wait_proc_num()
{
	local cmd=${1:?"no cmd"}
	local num=$((${2:-0}))
	local max=$((${3:-num}))
	local timeout=$((${4:-5}))
	local tm=0
	local rt=0

	# while [ $tm -le $timeout ]; do
	while [ 1 ]; do
		check_proc_num "$cmd" "$num" "$max"
		rt=$?
		if [ $rt -eq 0 ]; then
			return 0
		fi
		if [ ${tm} -ge ${timeout} ]; then
			return 2
		else 
			sleep 1
			tm=$(($tm+1))
		fi
	done

	return 1
}

# int check_proc_net(proc, [recv = 0], [send = 0]
# 0, no packet loss
# 1, fail
# 2, has packet lost
function check_proc_net()
{
	local proc=${1:?"no proc"}
	local recv=$((${2:-0}))
	local send=$((${3:-0}))
	local cmd="netstat -lpn | grep -E '/${proc}' | awk 'BEGIN{cnt=0}; {if((\$1==\"udp\")&&(\$2>${recv}||\$3>${send})) cnt++;} END{print cnt}'"
	# local ps="ps -e -o cmd | awk '{print \$1}' | grep -E '/${cmd}$|^${cmd}$' | grep -v grep | wc -l"
	local n=$(eval "${cmd}")
	echo "cmd = ${cmd}, num = $n"
	if [ ${n} -ge 0 ]; then
		return 2
	fi
	return 0
}

# int function start_proc(cmd)
# int function start_proc(home, cmd)
# 0, succ
# 1, fail
function start_proc()
{
	local home=""
	local cmd=""

	if [ $# -eq 1 ]; then
		cmd="$1"
	elif [ $# -eq 2 ]; then
		home="$1"
		cmd="$2"
	else
		return 2	
	fi

	local pcmd=$(echo ${cmd} | awk '{print $1}') # "vi test.sh" to "vi"
	echo "|${cmd}|${pcmd}|"

	# keep context
	local tpwd=$(pwd)

	cd ${home} > "${DEV_NULL}" 2>&1

	if [ "${pcmd:0:1}" == "/" ] || [ "${pcmd:0:2}" == "./" ]; then # with path
		echo "$cmd" | sh
	elif [ -x ${pcmd} ]; then # exist and can execute
		echo "./$cmd" | sh
	else                         # not found, try to find in path, like vi
		echo "$cmd" | sh
	fi

	# restore context
	cd ${tpwd} > "${DEV_NULL}" 2>&1
}

# int start_proc_num (home, cmd, [num = 1], [max = num], [timeout = 3])
function start_proc_num() 
{
	if [ $# -lt 2 ]; then
		return 2
	fi

	local home=${1}
	local cmd=${2}
	local num=$((${3:-1}))
	local max=$((${4:-num}))
	local timeo=$((${5:-3}))
	local ret=0

	echo "home = |$home|, cmd = |$cmd|, timeo = |${timeo}|"

	check_proc_num "$cmd" $num $max
	ret=$?
	if [ $ret -ne 0 ]; then # check fail
		echo "check_proc_num($home, $cmd, $num, $max) = $ret"
		killall $cmd > "${DEV_NULL}" 2>&1
		wait_proc_num "$cmd" 0 0 "${timeo}"
		ret=$?
		if [ ${ret} -ne 0 ]; then
			killall -9 $cmd > "${DEV_NULL}" 2>&1
			sleep "${timeo}"
		fi
		start_proc "${home}" "${cmd}"
	fi

	return 0
}

# start_proc_net(home, cmd, [recv = 0], [send = 0]
function start_proc_net()
{
	if [ $# -lt 2 ]; then
		return 2
	fi

	local home=$1
	local cmd=$2
	local recv=$((${3:-0}))
	local send=$((${4:-0}))
	local ret=0

	check_proc_net $cmd $recv $send
	ret=$?
	if [ ${ret} -ne 0 ]; then
		echo "check_proc_net($home, $cmd, $recv, $send) = $ret"
		killall $cmd > "${DEV_NULL}" 2>&1
		wait_proc_num $cmd 0
		ret=$?
		if [ ${ret} -ne 0 ]; then
			killall -9 $cmd > "${DEV_NULL}" 2>&1
		fi
		start_proc "${home}" "${cmd}"
	fi
}

# int ta_start_proc(home, [cmd...])
function ta_start_proc()
{
	local home=${1}
	local readonly plf="/usr/local/agenttools/agent/processlist"

	if [ ! -f "${plf}" ]; then
		return 1
	fi

	local cmd=""
	local num=1
	local max=${num}
	while read line; do
		# echo "${line}"
		cmd=$(echo ${line} | awk -F',' '{print $1}')
		num=$(echo ${line} | awk -F',' '{print $2}')
		max=$(echo ${line} | awk -F',' '{print $3}')
		# echo "|${cmd}|${num}|${max}|"
		if [ -z "${num}" ]; then
			num=1
		fi
		if [ -z "${max}" ]; then
			max=${num}
		fi
		echo "|${cmd}|${num}|${max}|"
		start_proc_num "${home}" "${cmd}" "${num}" "${max}"
	done < "${plf}"

	return 0
} 

# int ftp_put_file(host, port, user, passwd, src, dst)
# deprecated, replace by ssh
# 0, succ
# 1, fail
function ftp_put_file() 
{
	if [ $# -lt 6 ]; then
		echo "invalid params"
		return 1
	fi
		
	local host=$1
	local port=$2
	local user=$3
	local passwd=$4
	local src=$5
	local dst=$6

	{
		echo user $user $passwd
		echo bin
		echo put $src $dst
		echo bye
	} | ftp -in $host $port

	return 0
}

# int ssh_put(host, port, user, passwd, src, dst, [limit = 10], [timeout = 86400])
# may be you can put file or get file
# limit, default 10M
# 0, succ
# 1, fail
function ssh_put()
{
	if [ $# -lt 6 ]; then
		echo "invalid params"
	fi

	local host=$1
	local port=$2
	local user=$3
	local passwd=$4
	local src=$5
	local dst=$6
	local limit=$((${7:-10} * 1000)) # default 10M/s
	local timeout=$((${8:-86400})) # default 1 day

	# set timeout to 1 day that enought to send any file
	expect -c "
		set timeout $timeout;
		set flag 0
		spawn rsync -aq --bwlimit=$limit $src $user@$host:$dst; 
		expect {
			\"*assword\" { 
				send $passwd\r; 
			}
			\"yes\/no)?\" { 
				set flag 1; 
				send yes\r;
			}
			eof { 
				exit 0; 
			}
		}
		if { \$flag == 1 } {
			expect {
				\"*assword\" { 
					send $passwd\r; 
				}
			}
		}
		expect {
			\"*assword*\" { 
				puts \"INVALID PASSWD, host = $host, user = $user, passwd = \'$passwd\'\";
				exit 1
			}
			eof {
				exit 0
			}
		}
	"
	return 0
}

# int ssh_get(host, port, user, passwd, src, dst, [limit = 100M], [timeout = 86400])
# may be you can put file or get file
# limit, default 10M
# 0, succ
# 1, fail
function ssh_get()
{
	if [ $# -lt 6 ]; then
		echo "invalid params"
		return 1
	fi

	local host=$1
	local port=$2
	local user=$3
	local passwd=$4
	local src=$5
	local dst=$6
	local limit=$((${7:-100} * 1000)) # default 100M/s
	local timeout=$((${8:-86400})) # default 1 day

	# set timeout to 1 day that enought to send any file
	# may be not need passwd
	expect -c "
		set timeout $timeout;
		set flag 0
		spawn rsync -aq --bwlimit=$limit $user@$host:$src $dst; 
		expect {
			\"*assword\" { 
				send $passwd\r; 
			}
			\"yes\/no)?\" { 
				set flag 1; 
				send yes\r;
			}
			eof { 
				exit 0; 
			}
		}
		if { \$flag == 1 } {
			expect {
				\"*assword\" { 
					send $passwd\r; 
				}
			}
		}
		expect {
			\"*assword*\" { 
				puts \"INVALID PASSWD, host = $host, user = $user, passwd = $passwd\";
				exit 1
			}
			eof {
				exit 0
			}
		}
	"
	ret=$?
	if [ $ret -ne 0 ]; then
		return 5
	fi

	return 0
}

# int exec_script(host, port, user, passwd, script, [timeout = 86400])
# 0, succ
# 1, fail
# 2, invalid params
# 3, fail
# 4, invalid script
# 5, login fail
# 6, put file fail
# 7, timeout
# 8, remote execute script fail
function exec_script()
{
	if [ $# -lt 5 ]; then
		return 2
	fi

	local host=$1
	local port=$2
	local user=$3
	local passwd=$4
	local script=$5
	local timeout=$((${6:-86400})) # default 1 day
    local rscp=$(make_rand_file `basename $script`)
	local ret=0

	if [ ! -f $script ]; then
		return 4
	fi

	echo "script = ${script}, remote_script = ${rscp}"
	ssh_put $host $port $user $passwd $script $rscp 

	expect -c "
		set timeout $timeout
		set flag 0
		spawn ssh $user@$host;
		expect {
			\"*assword*\" { send $passwd\r; } 
			\"yes\/no)?\" { 
				set flag 1; 
				send yes\r;
			}
			\"Welcome\" { }
		}
		if { \$flag == 1 } {
			expect {
				\"*assword\" { 
					send $passwd\r; 
				}
			}
		}
		expect {
			\"*assword*\" { 
				puts \"INVALID PASSWD, host = $host, user = $user, passwd = $passwd\";
				exit 1 
			}
			\"#\ \" {} \"$\ \" {} \">\ \" {}
		}
		send $rscp\r;
		expect {
			\"#\ \" {} \"$\ \" {} \">\ \" {}
		}
		send \"rm -f $rscp\r\"
		send exit\r;
		expect eof {
			exit 0
		}
	"
	ret=$?
	if [ $ret -ne 0 ]; then
		return 5
	fi

	return 0
}

# int exec_cmd(host, port, user, passwd, cmd, [timeout = 86400], [rfile = /dev/null])
# 0, succ
# 1, fail
# 2, invalid params
# 3, fail
# 4, invalid script
# 5, login fail
# 6, put file fail
# 7, timeout
# 8, remote execute script fail
function exec_cmd()
{
	if [ $# -lt 5 ]; then
		return 4
	fi

	local host=$1
	local port=$2
	local user=$3
	local passwd=$4
	local cmd=$5
	local timeout=$((${6:-86400})) # default 1 day
	local rfile=${7-"/dev/null"}
	#local log=$(make_tmp_file "${__GEAR_SH}_exec_cmd")
	local ret=0

	expect -c "
		set timeout $timeout
		set flag 0
		spawn ssh $user@$host;
		expect {
			\"*assword*\" { send $passwd\r; } 
			\"yes\/no)?\" { 
				set flag 1; 
				send yes\r;
			}
			\"Welcome\" { }
		}
		if { \$flag == 1 } {
			expect {
				\"*assword\" { 
					send $passwd\r; 
				}
			}
		}
		expect {
			\"*assword*\" { 
				puts \"INVALID PASSWD, host = $host, user = $user, passwd = $passwd\";
				exit 1 
			}
			\"#\ \" {} \"$\ \" {} \">\ \" {}
		}
		log_file ${rfile}
		send \"$cmd \r\";
		expect {
			\"#\ \" {} \"$\ \" {} \">\ \" {}
		}
		send exit\r;
		expect eof {
			exit 0
		}
	"
	cat ${rfile} | sed -n '1,/[#$>].*exit/p' | sed '1d;$d' > ${rfile}
	#if [ -f ${log} ]; then rm ${log}; fi
	ret=$?
	if [ $ret -ne 0 ]; then
		return 5
	fi

	return 0
}


#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

binary_tar_file='/usr/local/src/mysql-5.7.34-linux-glibc2.12-x86_64.tar.gz'
binary_tar_base_path='/usr/local/'
binary_tar_dir=$binary_tar_base_path'mysql-5.7.34-linux-glibc2.12-x86_64'
binary_dir='/usr/local/mysql-5.7.34'

# install dependency by yum
function install_dependency(){
	echo 'install dependencies'
	yum -y install cmake gcc gcc-c++ libaio libaio-devel automake autoconf bzr bison libtool ncurses-devel zlib-devel install perl-DBD-MySQL perl-Time-HiRes.x86_64 python-dateutil gcc gcc-c++ libtool autoconf automake imake libxml2-devel expat-devel ncurses-devel cmake bison numactl numactl-devel python-devel > /dev/null
}

# init group mysql and system user mysql
function init_user(){
	echo 'init mysql group'
	groupadd mysql
	echo 'init mysql user'
	useradd mysql -g mysql -M -s /sbin/nologin
}

# download binary to /usr/local/src and install it to /usr/local
function install_binary(){
	echo 'install mysql binary'
	# pre clean
	rm -f $binary_tar_file
	rm -rf $binary_tar_dir
	rm -rf $binary_dir
	# download binary
	wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.7.34-linux-glibc2.12-x86_64.tar.gz -O $binary_tar_file
	# handle binary
	tar zxvf $binary_tar_file -C $binary_tar_base_path
	mv $binary_tar_dir $binary_dir
	chown mysql:mysql $binary_dir
	chmod 750 $binary_dir
}

# init base dir
function init_dir(){
	echo 'init base dir'
	# init base dir
	mkdir -p /data/mysql/

	chmod o+rx /data/
	chown -R mysql:mysql /data/mysql/
	chmod 755 /data/mysql/
}

function init_mysql(){
	echo 'init mysql'
	# install dependency
	install_dependency
	# init mysql user and group
	init_user
	# download mysql binary
	install_binary
	# init dir
	init_dir
}

function instance_mysql(){
	port=$1
	echo 'instance mysql to port : '$port
	# pre check
	if [ $(netstat -ant | grep $port | wc -l) -gt 0 ]; then
		echo 'port '$port' is using.'
		exit 1
	fi
	if [ -d /data/mysql/$port/ ]; then
		echo 'the instance may has been inited.'
		exit 1
	fi

	# init dir
	mkdir -p /data/mysql/$port/data
	mkdir -p /data/mysql/$port/log
	mkdir -p /data/mysql/$port/bin_log
	mkdir -p /data/mysql/$port/relay_log
	touch /data/mysql/$port/log/error-$port.log
	chown -R mysql:mysql /data/mysql/$port/

	# initial instance
	/usr/local/mysql-5.7.34/bin/mysqld --initialize-insecure --user=mysql --basedir=/usr/local/mysql-5.7.34 --datadir=/data/mysql/$port/data

	# init cfg file
	cnf_file=/data/mysql/$port/my_$port.cnf
	cp ./my_default.cnf $cnf_file
	sed -i "s/{port}/${port}/g" $cnf_file
	
	# init autostart

	# start instace
	/bin/sh /usr/local/mysql-5.7.34/bin/mysqld_safe --defaults-file=/data/mysql/$port/my_$port.cnf --pid-file=/data/mysql/$port/mysql-$port.pid &
}

# usage text
function echo_usage(){
	echo 'usage :'
	echo '        to install mysql : '$1' init'
	echo '        to init mysql instance of a port : '$1' instance {port}'
}
case $1 in
	init)
		init_mysql
	;;
	instance)
		if [[ "$2" =~ ^[0-9]+$ ]]; then
			instance_mysql $2
		else
			echo_usage $0
		fi
	;;
	*)
		echo_usage $0
	;;
esac



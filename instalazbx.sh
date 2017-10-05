#!/bin/bash
#
# -------------------------------------------------------------------------
#   @Programa 
# 	@name: instalazbx.sh
#	@author Paulo Tinoco <paulo.tinoco@seg.eti.br>
#	@versao: 1.0
#	@Data 08 de Junho de 2017
#	@Copyright: SEG Tecnologia, 2010 - 2017
# --------------------------------------------------------------------------
#
#
TITULO="instalazbx.sh - v.1.0"
BANNER="http://www.seg.eti.br"
PHPINI="/etc/php.ini"
WWW_PATH="/var/www/html/"
ZBX_TAG='rc1';
ZBX_VER="3.4.3$ZBX_TAG"

MAIN_MENU (){
 
menu01Option=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --menu "Selecione uma opção!" --fb 15 50 6 \
"1" "Instalar Zabbix" \
"2" "Instalar Hack Tela Login" \
"3" "Instalar Integração Telegram"  3>&1 1>&2 2>&3)
 
status=$?

if [ $status != 0 ]; then
	echo "Você selecionou, $menu01Option!"
	exit;
fi
}
DEPENDENCIAS(){
mkdir /install 
cd /install
rpm -Uvh https://mirror.webtatic.com/yum/el7/epel-release.rpm;
yum -y update && yum -y groupinstall 'Development Tools';
yum -y install wget net-snmp net-snmp-devel net-snmp-utils net-snmp-libs iksemel-devel zlib-devel libc-devel curl-devel automake libidn-devel openssl-devel rpm-devel OpenIPMI-devel libssh2-devel make fping; 
yum -y install php php-bcmath php-gd php-mbstring  php-xml php-ldap php-mysql php-ldap php-mysql httpd --skip-broken;
yum -y install sqlite-devel sqlite;

useradd zabbix -s /bin/false

sed -i "s/date.timezone/;date.timezone/" $PHPINI;
sed -i "s/max_execution_time/;max_execution_time/" $PHPINI;
sed -i "s/max_input_time/;max_input_time/" $PHPINI;
sed -i "s/post_max_size/;post_max_size/" $PHPINI;

echo "date.timezone =America/Sao_Paulo" >> $PHPINI;
echo "max_execution_time = 300" >> $PHPINI;
echo "max_input_time = 300" >> $PHPINI;
echo "post_max_size = 16M" >> $PHPINI;
echo "always_populate_raw_post_data=-1" >> $PHPINI

systemctl enable httpd.service;
systemctl restart httpd.service;

URL_DOWN=`curl -s http://www.zabbix.com/developers.php | grep $ZBX_VER | awk -Fhref '{print $2}' | awk -F\> '{print $1}' | awk -F\" '{print $2}'`
curl $URL_DOWN -o zabbix.tgz
tar -xzvf zabbix.tgz
mv zabbix* zabbix
}

INSTALAMYSQL(){

yum install mariadb mariadb-devel mariadb-server -y;
systemctl enable mariadb.service;
systemctl restart mariadb.service;

SENHA_A=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --inputbox "Digite a Senha do usuário root MySQL" --fb 10 60 3>&1 1>&2 2>&3)
statussaida=$?
if [ $statussaida = 0 ]; then
    echo " IP Master: $REDEIPMASTER" 
else
    echo " Não configurou o endereço IP do Servidor Master." 
fi

SENHA_B=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --inputbox "Repita a Senha do usuário root MySQL" --fb 10 60 3>&1 1>&2 2>&3)
statussaida=$?
if [ $statussaida = 0 ]; then
    echo " IP Master: $REDEIPMASTER" 
else
    echo " Não configurou o endereço IP do Servidor Master." 
fi

if [[ $SENHA_A -eq $SENHA_B ]]; then
	SENHAMYSQL=$SENHA_A;
else
	INSTALAMYSQL
fi

}

CONFIGURABANCO(){
NOMEBANCO=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --inputbox "Digite o nome do banco de dados para instalação" --fb 10 60 3>&1 1>&2 2>&3)
statussaida=$?
if [ $statussaida = 0 ]; then
    echo " IP Master: $REDEIPMASTER" 
else
    echo " Não configurou o endereço IP do Servidor Master." 
fi

USERINSTALLDB=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --inputbox "Digite o nome do banco de dados para instalação" --fb 10 60 3>&1 1>&2 2>&3)
statussaida=$?
if [ $statussaida = 0 ]; then
    echo " IP Master: $REDEIPMASTER" 
else
    echo " Não configurou o endereço IP do Servidor Master." 
fi

SENHAUSERDB=$(whiptail --title "${TITULO}" --backtitle "${BANNER}" --inputbox "Digite o nome do banco de dados para instalação" --fb 10 60 3>&1 1>&2 2>&3)
statussaida=$?
if [ $statussaida = 0 ]; then
    echo " IP Master: $REDEIPMASTER" 
else
    echo " Não configurou o endereço IP do Servidor Master." 
fi

/usr/bin/mysqladmin -u root password $SENHAMYSQL;
echo "CREATE DATABASE $NOMEBANCO CHARACTER SET UTF8;" | mysql -uroot -p$SENHAMYSQL;
echo "grant all privileges on $USERINSTALLDB.* to $USERINSTALLDB@localhost identified by '$SENHAUSERDB';" | mysql -uroot -p$SENHAMYSQL;
cd /install/zabbix
cat database/mysql/schema.sql | mysql -u $USERINSTALLDB -p$SENHAUSERDB $NOMEBANCO && cat database/mysql/images.sql | mysql -u $USERINSTALLDB -p$SENHAUSERDB $NOMEBANCO && cat database/mysql/data.sql | mysql -u $USERINSTALLDB -p$SENHAUSERDB $NOMEBANCO;
}

INSTALAZBX(){
cd /install/zabbix/database/sqlite3
mkdir /var/lib/sqlite/
sqlite3 /var/lib/sqlite/zabbix.db < schema.sql
chown -R zabbix:zabbix /var/lib/sqlite/

cd /install/zabbix
rm $WWW_PATH/index.html 
cp -Rpv frontends/php/* $WWW_PATH

# Criando o arquivo de configuracao do frontend
echo -e "<?php
// Zabbix GUI configuration file. - Created by Paulo Tinoco
global \$DB;

\$DB['TYPE']				= 'MYSQL';
\$DB['SERVER']			= 'localhost';
\$DB['PORT']				= '0';
\$DB['DATABASE']			= '$NOMEBANCO';
\$DB['USER']				= '$USERINSTALLDB';
\$DB['PASSWORD']			= '$SENHAUSERDB';
// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA']			= '';

\$ZBX_SERVER				= 'localhost';
\$ZBX_SERVER_PORT		= '10051';
\$ZBX_SERVER_NAME		= 'Sistema Monitoramento ($ZBX_VER)';

\$IMAGE_FORMAT_DEFAULT	= IMAGE_FORMAT_PNG;
?>
" > $WWW_PATH/conf/zabbix.conf.php

cd /install/zabbix

./configure --enable-server --enable-agent --with-mysql --with-net-snmp  --with-libcurl --with-openipmi && make install
cp -Rpv misc/init.d/fedora/core5/zabbix_* /etc/init.d/
cp -Rpv misc/init.d/fedora/core5/zabbix_server /etc/init.d/zabbix_proxy
sed -i "s/Server/Proxy/g" /etc/init.d/zabbix_proxy
sed -i "s/server/proxy/g" /etc/init.d/zabbix_proxy

chmod +x /etc/init.d/za*
chkconfig --add zabbix_server
chkconfig --add zabbix_agentd
chkconfig --level 35 zabbix_server on
chkconfig --level 35 zabbix_agentd on
# Proxy
chkconfig --add zabbix_proxy
chkconfig --level 35 zabbix_proxy on

chmod 755 $WWW_PATH/conf/zabbix.conf.php
}

clear

MAIN_MENU

while true
do
case $menu01Option in

	1)
		CONFIGURAMYSQL
		kill $$
	;;

	2)
		CONFIGURAMYSQL
		kill $$
	;;

	3)
		CONFIGURAMYSQL
		kill $$
	;;

esac
done
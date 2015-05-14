#!/bin/bash

echo "------------------ Install related update and packaged ------------------"
sleep 3

apt-get update && apt-get -y upgrade

## Note: Reboot is needed only if kernel is updated
#reboot

echo "------------------ Install RabiitMQ Server ------------------"
sleep 3

## RaabitMQ server
apt-get install -y rabbitmq-server

## Change Password for the user ‘guest’ in the rabbitmq-server
rabbitmqctl change_password guest rabbit

echo "------------------ Install MySQL Database Server ------------------"
sleep 3

## MySQL server
## Install MySQL server and related softwa**re
debconf-set-selections <<< 'mysql-server mysql-server/root_password password '$MYSQL_PASS''
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '$MYSQL_PASS''
apt-get install -y mysql-server python-mysqldb

## Replace /etc/mysql/mysql.conf.d/mysqld.cnf with ./config/mysqld.cnf
tempfile=/etc/mysql/mysql.conf.d/mysqld.cnf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/mysqld.cnf $tempfile

## Restart MySQL service
service mysql restart

sleep 5

echo "------------------ Install Other Support Packages ------------------"
sleep 3

## Other Support Packages
apt-get install -y ntp vlan bridge-utils

## Replace /etc/sysctl.conf with ./config/sysctl.conf
## The setting variable:
## + net.ipv4.ip_forwar
## + net.ipv4.conf.all.rp_filter
## + net.ipv4.conf.default.rp_filter
tempfile=/etc/sysctl.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/sysctl.conf $tempfile

## Load the values
sysctl -p

sleep 5

echo "------------------ Add Needed DataBase in MySQL ------------------"
sleep 3

## Create mysql database and add credentials
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;
DROP DATABASE IF EXISTS glance;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS cinder;
DROP DATABASE IF EXISTS neutron;

## For nova usage
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova_dbpass';

## For glance usage
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance_dbpass';

## For keystone usage
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone_dbpass';

## For cinder usage
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder_dbpass';

## For neutron usage
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron_dbpass';

EOF

#!/bin/bash

echo "Self ip: ${SELF_IP:="127.0.0.1"}"

echo "------------------ Install Nova ------------------"
sleep 3

## Nova(Compute)
## Install the Nova services
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient nova-compute nova-console

## Create Keystone entries for Nova
keystone user-create --name=nova --pass=nova_pass --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create --service=nova --publicurl=http://$SELF_IP:8774/v2/%\(tenant_id\)s --internalurl=http://$SELF_IP:8774/v2/%\(tenant_id\)s --adminurl=http://$SELF_IP:8774/v2/%\(tenant_id\)s


## Replace /etc/nova/nova.conf with ./config/nova.conf
tempfile=/etc/nova/nova.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/nova.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## sync the Nova db
nova-manage db sync

## Restart all nova services
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
service nova-compute restart
service nova-console restart
sleep 10

## Test the Nova installation using the following command
nova-manage service list

## The output should be something like this
## Binary           Host                                 Zone             Status     State Updated_At
## nova-cert        ift-VirtualBox                       internal         enabled    :-)   2015-05-12 06:58:51
## nova-consoleauth ift-VirtualBox                       internal         enabled    :-)   2015-05-12 06:58:51
## nova-conductor   ift-VirtualBox                       internal         enabled    :-)   2015-05-12 06:58:43
## nova-scheduler   ift-VirtualBox                       internal         enabled    :-)   2015-05-12 06:58:43
## nova-console     ift-VirtualBox                       internal         enabled    :-)   2015-05-12 06:58:44
## nova-compute     ift-VirtualBox                       nova             enabled    :-)   2015-05-12 06:58:45

## Also run the following command to check if nova is able to authenticate with keystone server
nova list

## The output should be something like this
## +----+------+--------+------------+-------------+----------+
## | ID | Name | Status | Task State | Power State | Networks |
## +----+------+--------+------------+-------------+----------+
## +----+------+--------+------------+-------------+----------+

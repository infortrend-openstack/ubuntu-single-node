#!/bin/bash

echo "Self ip: ${SELF_IP:="127.0.0.1"}"

echo "------------------ Install Cinder ------------------"
sleep 3

## Cinder
## Install Cinder services
apt-get install -y cinder-api cinder-scheduler cinder-volume lvm2 open-iscsi-utils open-iscsi iscsitarget sysfsutils

## Create Cinder related keystone entries
keystone user-create --name=cinder --pass=cinder_pass --email=cinder@example.com
keystone user-role-add --user=cinder --tenant=service --role=admin
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create --service=cinder --publicurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s --internalurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s --adminurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s
keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create --service=cinderv2 --publicurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s --internalurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s --adminurl=http://$SELF_IP:8776/v2/%\(tenant_id\)s


## Edit /etc/cinder/cinder.conf
tempfile=/etc/cinder/cinder.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/cinder.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## Sync the database
cinder-manage db sync

## Create physical volume
#pvcreate /dev/sdb

## Create volume group named “cinder-volumes”
#vgcreate cinder-volumes /dev/sdb

## Restart all the Cinder services
service cinder-scheduler restart;service cinder-api restart;service cinder-volume restart;service tgt restart
sleep 5

## Create a volume to test the setup
#cinder create --display-name myVolume 1

## List the volume created
cinder list

## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
## |                  ID                  |   Status  | Display Name | Size | Volume Type | Bootable | Attached to |
## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
## | e19242b5-8caf-4093-9b81-96d6bb1f7000 | available |   myVolume   |  1   |     None    |  false   |             |
## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+

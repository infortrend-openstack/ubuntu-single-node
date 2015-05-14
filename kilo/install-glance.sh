#!/bin/bash

echo "Self ip: ${SELF_IP:="127.0.0.1"}"

echo "------------------ Install Glance ------------------"
sleep 3

## Glance (Image Store)
## Install Glance
apt-get install -y glance

## Create glance related keystone entries
keystone user-create --name=glance --pass=glance_pass --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin
keystone service-create --name=glance --type=image --description="Glance Image Service"
keystone endpoint-create --service=glance --publicurl=http://$SELF_IP:9292 --internalurl=http://$SELF_IP:9292 --adminurl=http://$SELF_IP:9292

## Replace /etc/glance/glance-api.conf with ./config/glance-api.conf
## The Setting variable:
## + rabbit_password
## + connection
## + identity_uri
## + admin_tenant_name
## + admin_user
## + admin_password
## + flavor
tempfile=/etc/glance/glance-api.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/glance-api.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

##  Replace /etc/glance/glance-registry.conf with ./config/glance-registry.conf
## The Setting variable:
## + rabbit_password
## + connection
## + identity_uri
## + admin_tenant_name
## + admin_user
## + admin_password
## + flavor
tempfile=/etc/glance/glance-registry.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/glance-registry.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## Restart Glance services
service glance-api restart
service glance-registry restart
sleep 5

## Sync the database
glance-manage db_sync

## Download a pre-bundled image for testing
glance image-create --name Cirros --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
glance image-list

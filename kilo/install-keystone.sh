#!/bin/bash

echo "Self ip: ${SELF_IP:="127.0.0.1"}"

echo "------------------ Install Keystone ------------------"
sleep 3

## Keystone
## Install keystone
apt-get install -y keystone

## Replace /etc/keystone/keystone.conf with ./config/keystone.conf
## The Setting variable:
## + connection
tempfile=/etc/keystone/keystone.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/keystone.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## Restart the keystone service and sync the database
service keystone restart
sleep 5
keystone-manage db_sync
sleep 5

## Export the variable to run initial keystone commands
export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://$SELF_IP:35357/v2.0

## Create admin user, admin tenant, admin role and service tenant. Also add admin user to admin tenant and admin role.
keystone tenant-create --name=admin --description="Admin Tenant"
keystone tenant-create --name=service --description="Service Tenant"
keystone user-create --name=admin --pass=ADMIN --email=admin@example.com
keystone role-create --name=admin
keystone user-role-add --user=admin --tenant=admin --role=admin

## Create keystone service
keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"

## Create keystone endpoint
keystone endpoint-create --service=keystone --publicurl=http://$SELF_IP:5000/v2.0 --internalurl=http://$SELF_IP:5000/v2.0 --adminurl=http://$SELF_IP:35357/v2.0

## Unset the exported values
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT

## Create a file named creds and add the following lines
cat << EOF > creds
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$SELF_IP:35357/v2.0
EOF

## Source the file
source creds

## Test the keysone setup
keystone token-get
keystone user-list

#!/bin/bash

echo "Self ip: ${SELF_IP:="127.0.0.1"}"

echo "------------------ Install Neutron ------------------"
sleep 3

## Neutron(Networking service)
## Install the Neutron services
apt-get install -y neutron-server neutron-plugin-openvswitch neutron-plugin-openvswitch-agent neutron-common neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent openvswitch-switch


## Create Keystone entries for Neutron
keystone user-create --name=neutron --pass=neutron_pass --email=neutron@example.com
keystone service-create --name=neutron --type=network --description="OpenStack Networking"
keystone user-role-add --user=neutron --tenant=service --role=admin
keystone endpoint-create --service=neutron --publicurl http://$SELF_IP:9696 --adminurl http://$SELF_IP:9696  --internalurl http://$SELF_IP:9696

## Replace /etc/neutron/neutron.conf with ./config/neutron.conf
tempfile=/etc/neutron/neutron.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/neutron.conf $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## Replace /etc/neutron/plugins/ml2/ml2_conf.ini with ./config/ml2_conf.ini
tempfile=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/ml2_conf.ini $tempfile


## We have created two physical networks one as a flat network and the other as a vlan network with vlan ranging from 100 to 200. We have mapped External network to br-ex and Intnet1 to br-eth0. Now Create bridges
## You can use the appropriate interface names below instead of “eth0″ and “eth1″.
ovs-vsctl add-br br-int
ovs-vsctl add-br br-eth0
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-eth0 eth0
ovs-vsctl add-port br-ex eth1

echo "------------------ Setup Network interfaces ------------------"
sleep 3

## Replace /etc/network/interfaces with ./config/interfaces
tempfile=/etc/network/interfaces
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/interfaces $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile
sed -i "s/your_netmask/$SELF_NETMASK/g" $tempfile
sed -i "s/your_gateway/$SELF_GATEWAY/g" $tempfile
sed -i "s/your_dns/$SELF_DNS_IP/g" $tempfile

sed -i "s/your_ip_sec/$SELF_IP_SEC/g" $tempfile
sed -i "s/your_netmask_sec/$SELF_NETMASK_SEC/g" $tempfile
sed -i "s/your_gateway_sec/$SELF_GATEWAY_SEC/g" $tempfile

## restart network interfaces
/etc/init.d/networking restart

sleep 5

ping $SELF_DNS_IP

echo "------------------ Setupt Neutron ------------------"
sleep 3

## Replace /etc/neutron/metadata_agent.ini with ./config/metadata_agent.ini
tempfile=/etc/neutron/metadata_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/metadata_agent.ini $tempfile
sed -i "s/your_ip/$SELF_IP/g" $tempfile

## Replace /etc/neutron/dhcp_agent.ini with ./config/dhcp_agent.ini
tempfile=/etc/neutron/dhcp_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/dhcp_agent.ini $tempfile

## Replace /etc/neutron/l3_agent.ini to look like this with ./config/l3_agent.ini
tempfile=/etc/neutron/l3_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
cp -f ./config/l3_agent.ini $tempfile

## Sync the db
neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head

## Restart all Neutron services
service neutron-server restart
service neutron-plugin-openvswitch-agent restart
service neutron-metadata-agent restart
service neutron-dhcp-agent restart
service neutron-l3-agent restart
sleep 5

## Check if the services are running. Run the following command
neutron agent-list
## The output should be like
## +--------------------------------------+--------------------+----------------+-------+----------------+---------------------------+
## | id                                   | agent_type         | host           | alive | admin_state_up | binary                    |
## +--------------------------------------+--------------------+----------------+-------+----------------+---------------------------+
## | 4242a9dc-17e4-4a01-81dd-36231a7f5aff | Open vSwitch agent | ift-VirtualBox | :-)   | True           | neutron-openvswitch-agent |
## | 65ab4cfd-e61b-4bac-b869-2beac964ca97 | Metadata agent     | ift-VirtualBox | :-)   | True           | neutron-metadata-agent    |
## | 6d54e3f4-93c8-4c5e-8149-472246aaaee3 | DHCP agent         | ift-VirtualBox | :-)   | True           | neutron-dhcp-agent        |
## | d79a613d-bbd1-4278-8fea-3c5c0ad81f5d | L3 agent           | ift-VirtualBox | :-)   | True           | neutron-l3-agent          |
## +--------------------------------------+--------------------+----------------+-------+----------------+---------------------------+

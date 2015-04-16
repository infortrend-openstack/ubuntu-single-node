### OpenStack Juno on Ubuntu 14.04 LTS and 14.10 – Single Machine Setup
### Install Ubuntu with partitioning scheme as per your requirements. Note: Run all the commands as super-user. We assume that the IP of the Single machine is 127.0.0.1.


## Enter IP
echo "Enter All-in-one Ubuntu node IP (default 127.0.0.1)"
read self_ip
if [[ "$self_ip" == "" ]]; then
    echo "Set default address 127.0.0.1"
    self_ip=127.0.0.1
fi
echo "Enter netmask (default 255.255.255.0)"
read self_netmask
if [[ "$self_netmask" == "" ]]; then
    echo "Set default netmask 255.255.255.0"
    self_netmask=255.255.255.0
fi
echo "Enter gateway (Must)"
read self_gateway
if [[ "$self_gateway" == "" ]]; then
    echo "Please enter gateway in public network"
    exit 0
fi

#echo "Enter mysql password"
#read mysql_pass
mysql_pass=111111

## Configure the repositories and update the packages.
## This step is needed only if the OS is Ubuntu 14.04 LTS. You can skip the repository configuration if the OS is Ubuntu 14.10
apt-get install ubuntu-cloud-keyring
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
"trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
apt-get update && apt-get -y upgrade

## Note: Reboot is needed only if kernel is updated
#reboot 

## Support packages
## RaabitMQ server
apt-get install -y rabbitmq-server

## Change Password for the user ‘guest’ in the rabbitmq-server
rabbitmqctl change_password guest rabbit

## MySQL server
## Install MySQL server and related software
debconf-set-selections <<< 'mysql-server mysql-server/root_password password '$mysql_pass''
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '$mysql_pass''
apt-get install -y mysql-server python-mysqldb

## Edit the following lines in /etc/mysql/my.cnf
tempfile=/etc/mysql/my.cnf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
sed -i 's/127.0.0.1/0.0.0.0/g' $tempfile
sed -i "/bind-address/a\default-storage-engine = innodb\n\
innodb_file_per_table\n\
collation-server = utf8_general_ci\n\
init-connect = 'SET NAMES utf8'\n\
character-set-server = utf8" $tempfile

## Restart MySQL service
service mysql restart

## Other Support Packages
apt-get install -y ntp vlan bridge-utils

## Edit the following lines in the file /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf

## Load the values
sysctl -p

## Keystone
## Install keystone
apt-get install -y keystone

## Create mysql database and add credentials
cat << EOF | mysql -uroot -p$mysql_pass
DROP DATABASE IF EXISTS keystone;
DROP DATABASE IF EXISTS glance;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS cinder;
DROP DATABASE IF EXISTS neutron;
#
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova_dbpass';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'nova_dbpass';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'$CON_MGNT_IP' IDENTIFIED BY 'nova_dbpass';
CREATE DATABASE glance;
#
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance_dbpass';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'glance_dbpass';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'$CON_MGNT_IP' IDENTIFIED BY 'glance_dbpass';
#
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone_dbpass';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone_dbpass';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'$CON_MGNT_IP' IDENTIFIED BY 'keystone_dbpass';
#
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder_dbpass';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'cinder_dbpass';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$CON_MGNT_IP' IDENTIFIED BY 'cinder_dbpass';
#
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron_dbpass';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'neutron_dbpass';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'$CON_MGNT_IP' IDENTIFIED BY 'neutron_dbpass';
#
FLUSH PRIVILEGES;
EOF


## Edit the file /etc/keystone/keystone.conf. Comment the following line
tempfile=/etc/keystone/keystone.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp keystone.conf /etc/keystone
sed -i "s/your_ip/$self_ip/g" $tempfile

## Restart the keystone service and sync the database
service keystone restart
keystone-manage db_sync

## Export the variable to run initial keystone commands
export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://$self_ip:35357/v2.0

## Create admin user, admin tenant, admin role and service tenant. Also add admin user to admin tenant and admin role.
keystone tenant-create --name=admin --description="Admin Tenant"
keystone tenant-create --name=service --description="Service Tenant"
keystone user-create --name=admin --pass=ADMIN --email=admin@example.com
keystone role-create --name=admin
keystone user-role-add --user=admin --tenant=admin --role=admin

## Create keystone service
keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"

## Create keystone endpoint
keystone endpoint-create --service=keystone --publicurl=http://$self_ip:5000/v2.0 --internalurl=http://$self_ip:5000/v2.0 --adminurl=http://$self_ip:35357/v2.0

## Unset the exported values
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT

## Create a file named creds and add the following lines
cat << EOF > creds
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$self_ip:35357/v2.0
EOF

## Source the file
source creds

## Test the keysone setup
keystone token-get
keystone user-list

## Glance (Image Store)
## Install Glance
apt-get install -y glance


## Create glance related keystone entries
keystone user-create --name=glance --pass=glance_pass --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin
keystone service-create --name=glance --type=image --description="Glance Image Service"
keystone endpoint-create --service=glance --publicurl=http://$self_ip:9292 --internalurl=http://$self_ip:9292 --adminurl=http://$self_ip:9292

## Edit /etc/glance/glance-api.conf 
tempfile=/etc/glance/glance-api.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp glance-api.conf /etc/glance
sed -i "s/your_ip/$self_ip/g" $tempfile

## Edit /etc/glance/glance-registry.conf 
tempfile=/etc/glance/glance-registry.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp glance-registry.conf /etc/glance
sed -i "s/your_ip/$self_ip/g" $tempfile

## Restart Glance services
service glance-api restart
service glance-registry restart

## Sync the database
glance-manage db_sync

## Download a pre-bundled image for testing
glance image-create --name Cirros --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
glance image-list

## Nova(Compute)
## Install the Nova services
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient nova-compute nova-console

## Create Keystone entries for Nova
keystone user-create --name=nova --pass=nova_pass --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create --service=nova --publicurl=http://$self_ip:8774/v2/%\(tenant_id\)s --internalurl=http://$self_ip:8774/v2/%\(tenant_id\)s --adminurl=http://$self_ip:8774/v2/%\(tenant_id\)s


## Edit /etc/nova/nova.conf
tempfile=/etc/nova/nova.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp nova.conf /etc/nova
sed -i "s/your_ip/$self_ip/g" $tempfile

## sync the Nova db
nova-manage db sync

## Restart all nova services
service nova-api restart ;service nova-cert restart; service nova-consoleauth restart ;service nova-scheduler restart;service nova-conductor restart; service nova-novncproxy restart; service nova-compute restart; service nova-console restart

## Test the Nova installation using the following command
nova-manage service list

## The output should be something like this
# Binary           Host                     Zone             Status     State Updated_At
## nova-consoleauth ubuntu                   internal         enabled    :-)   2014-04-19 08:55:13
## nova-conductor   ubuntu                   internal         enabled    :-)   2014-04-19 08:55:14
## nova-cert        ubuntu                   internal         enabled    :-)   2014-04-19 08:55:13
## nova-scheduler   ubuntu                   internal         enabled    :-)   2014-04-19 08:55:13
## nova-compute     ubuntu                   nova             enabled    :-)   2014-04-19 08:55:14
## nova-console     ubuntu                   internal         enabled    :-)   2014-04-19 08:55:14

## Also run the following command to check if nova is able to authenticate with keystone server
nova list

## Neutron(Networking service)
## Install the Neutron services
apt-get install -y neutron-server neutron-plugin-openvswitch neutron-plugin-openvswitch-agent neutron-common neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent openvswitch-switch


## Create Keystone entries for Neutron
keystone user-create --name=neutron --pass=neutron_pass --email=neutron@example.com
keystone service-create --name=neutron --type=network --description="OpenStack Networking"
keystone user-role-add --user=neutron --tenant=service --role=admin
keystone endpoint-create --service=neutron --publicurl http://$self_ip:9696 --adminurl http://$self_ip:9696  --internalurl http://$self_ip:9696

## Edit /etc/neutron/neutron.conf
tempfile=/etc/neutron/neutron.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp neutron.conf /etc/neutron
sed -i "s/your_ip/$self_ip/g" $tempfile
keystone_service_tenant_id=$(keystone tenant-list | grep '^.*|\s*service\s*|.*$' | awk '{print $2}')
sed -i "s/service_id/$keystone_service_tenant_id/g" $tempfile

## Edit /etc/neutron/plugins/ml2/ml2_conf.ini 
tempfile=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp ml2_conf.ini /etc/neutron/plugins/ml2/


## We have created two physical networks one as a flat network and the other as a vlan network with vlan ranging from 100 to 200. We have mapped External network to br-ex and Intnet1 to br-eth1. Now Create bridges
## Note: The naming convention for the ethernet cards may also be like “p4p1″, “em1″ from Ubuntu 14.04 LTS. You can use the appropriate interface names below instead of “eth1″ and “eth2″.
ovs-vsctl add-br br-int
#ovs-vsctl add-br br-eth1
ovs-vsctl add-br br-ex
#ovs-vsctl add-port br-eth1 eth1
ovs-vsctl add-port br-ex eth0

## Edit /etc/network/interfaces
tempfile=/etc/network/interfaces
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp interfaces /etc/network/
sed -i "s/your_ip/$self_ip/g" $tempfile
sed -i "s/your_netmask/$self_netmask/g" $tempfile
sed -i "s/your_gateway/$self_gateway/g" $tempfile

## restart network interfaces
ifdown eth0 && ifup eth0
ifdown br-ex && ifup br-ex

## According to our set up all traffic belonging to External network will be bridged to eth2 and all traffic of Intnet1 will be bridged to eth1. If you have only one interface(eth0) and would like to use it for all networking then please have a look at https://fosskb.wordpress.com/2014/06/10/managing-openstack-internaldataexternal-network-in-one-interface.

## Edit /etc/neutron/metadata_agent.ini 
tempfile=/etc/neutron/metadata_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp metadata_agent.ini /etc/neutron/
sed -i "s/your_ip/$self_ip/g" $tempfile

## Edit /etc/neutron/dhcp_agent.ini
tempfile=/etc/neutron/dhcp_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp dhcp_agent.ini /etc/neutron/

## Edit /etc/neutron/l3_agent.ini to look like this
tempfile=/etc/neutron/l3_agent.ini
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp l3_agent.ini /etc/neutron/

## Sync the db
neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno

## Restart all Neutron services
service neutron-server restart; service neutron-plugin-openvswitch-agent restart;service neutron-metadata-agent restart; service neutron-dhcp-agent restart; service neutron-l3-agent restart

## Check if the services are running. Run the following command
neutron agent-list
## The output should be like
## +--------------------------------------+--------------------+--------+-------+----------------+
## | id                                   | agent_type         | host   | alive | admin_state_up |
## +--------------------------------------+--------------------+--------+-------+----------------+
## | 01a5e70c-324a-4183-9652-6cc0e5c98499 | Metadata agent     | ubuntu | :-)   | True           |
## | 17b9440b-50eb-48b7-80a8-a5bbabc47805 | DHCP agent         | ubuntu | :-)   | True           |
## | c30869f2-aaca-4118-829d-a28c63a27aa4 | L3 agent           | ubuntu | :-)   | True           |
## | f846440e-4ca6-4120-abe1-ffddaf1ab555 | Open vSwitch agent | ubuntu | :-)   | True           |
## +--------------------------------------+--------------------+--------+-------+----------------+

## Users who want to know what happens under the hood can read
## How neutron-openvswitch-agent provides L2 connectivity between Instances, DHCP servers and routers
## How neutron-l3-agent provides services like routing, natting, floatingIP and security groups
## See more of Linux networking capabilities


## Cinder
## Install Cinder services
apt-get install -y cinder-api cinder-scheduler cinder-volume lvm2 open-iscsi-utils open-iscsi iscsitarget sysfsutils

## Create Cinder related keystone entries
keystone user-create --name=cinder --pass=cinder_pass --email=cinder@example.com
keystone user-role-add --user=cinder --tenant=service --role=admin
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create --service=cinder --publicurl=http://$self_ip:8776/v1/%\(tenant_id\)s --internalurl=http://$self_ip:8776/v1/%\(tenant_id\)s --adminurl=http://$self_ip:8776/v1/%\(tenant_id\)s
keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create --service=cinderv2 --publicurl=http://$self_ip:8776/v2/%\(tenant_id\)s --internalurl=http://$self_ip:8776/v2/%\(tenant_id\)s --adminurl=http://$self_ip:8776/v2/%\(tenant_id\)s


## Edit /etc/cinder/cinder.conf
tempfile=/etc/cinder/cinder.conf
test -f $tempfile.orig || cp $tempfile $tempfile.orig
rm $tempfile
touch $tempfile
cp cinder.conf /etc/cinder/
sed -i "s/your_ip/$self_ip/g" $tempfile

## Sync the database
cinder-manage db sync

## Create physical volume
#pvcreate /dev/sdb

## Create volume group named “cinder-volumes”
#vgcreate cinder-volumes /dev/sdb

## Restart all the Cinder services
service cinder-scheduler restart;service cinder-api restart;service cinder-volume restart;service tgt restart

## Create a volume to test the setup
#cinder create --display-name myVolume 1

## List the volume created
cinder list

## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
## |                  ID                  |   Status  | Display Name | Size | Volume Type | Bootable | Attached to |
## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
## | e19242b5-8caf-4093-9b81-96d6bb1f7000 | available |   myVolume   |  1   |     None    |  false   |             |
## +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+

## Horizon (OpenStack Dashboard)
apt-get install -y openstack-dashboard

## After installing login using the following credentials
## URL     : http://YOUR_IP/horizon
## Username: admin
## Password: ADMIN



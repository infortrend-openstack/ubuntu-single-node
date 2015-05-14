#!/bin/bash

### OpenStack Kilo on Ubuntu 15.04 LTS – Single Machine Setup
### Install Ubuntu with partitioning scheme as per your requirements. Note: Run all the commands as super-user.

export MYSQL_PASS=111111
export SELF_IP=172.27.14.48
export SELF_NETMASK=255.255.255.0
export SELF_GATEWAY=172.27.14.254
export SELF_DNS_IP=8.8.8.8

export SELF_IP_SEC=172.27.14.43
export SELF_NETMASK_SEC=255.255.255.0
export SELF_GATEWAY_SEC=172.27.14.254

./pre-install.sh
./install-keystone.sh
./install-glance.sh
./install-neutron.sh
./install-dashboard.sh

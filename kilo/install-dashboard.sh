#!/bin/bash

echo "------------------ Install dashboard ------------------"
sleep 3

## Horizon (OpenStack Dashboard)
apt-get install -y openstack-dashboard

## After installing login using the following credentials
## URL     : http://YOUR_IP/horizon
## Username: admin
## Password: ADMIN

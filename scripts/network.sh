#!/bin/bash

PROVIDER_CIDR=$1
PROVIDER_CIDR_MSV="$(echo $PROVIDER_CIDR | cut -d/ -f1 | cut -d. -f1-3)"
PROVIDER_CIDR_LSV="$(echo $PROVIDER_CIDR | cut -d/ -f1 | cut -d. -f4)"
PROVIDER_CIDR_LSV=$(( $PROVIDER_CIDR_LSV + 1 ))
PROVIDER_CIDR_SIZE="$(echo $PROVIDER_CIDR | cut -d/ -f2)"
PROVIDER_IP=${PROVIDER_CIDR_MSV}.${PROVIDER_CIDR_LSV}/${PROVIDER_CIDR_SIZE}
SUBNET=$1

. ~/keystonerc_admin

openstack role add --user admin --project demo admin
openstack role add --user demo --project demo admin
openstack network --share public

# delete the demo public subnet
OLD_SUBNET_ID=`openstack subnet show public_subnet -f value -c id`
ROUTER_ID=`openstack router show router1 -c id -f value`
# is there an openstack cli replacement for router gateway clear?
neutron router-gateway-clear $ROUTER_ID
openstack subnet delete $OLD_SUBNET_ID

# add the new public subnet

IP=`hostname -I | cut -d' ' -f 1`
DNS_NAMESERVER=`grep -i nameserver /etc/resolv.conf | head -n1 | cut -d ' ' -f2`

openstack subnet create                         \
        --network public                        \
        --dns-nameserver $DNS_NAMESERVER        \
        --subnet-range $SUBNET                  \
        --no-dhcp
        $SUBNET

SUBNET_ID=`openstack subnet show $SUBNET -c id -f value`
neutron router-gateway-set router1 public

# create an internal network
INTERNAL_SUBNET=192.168.10.0/24

openstack network create internal --share

openstack subnet create                         \
        --network internal                      \
        --dns-nameserver $DNS_NAMESERVER        \
        --subnet-range $INTERNAL_SUBNET         \
        $INTERNAL_SUBNET

ROUTER_ID=`openstack router show router1 -c id -f value`
INTERNAL_SUBNET_ID=`openstack subnet show $INTERNAL_SUBNET -c id -f value`
openstack router add subnet $ROUTER_ID $INTERNAL_SUBNET_ID
	
# for i in $(openstack floating ip list -f value -c ID); do openstack floating ip delete $i; done
for i in 1 2 3 4 5 6 7 8; do openstack floating ip create public; done

GATEWAY=`ip route list | egrep "^default" | cut -d' ' -f 3`
IP=`hostname -I | cut -d' ' -f 1`
SUBNET=`ip -4 -o addr show dev bond0 | grep $IP | cut -d ' ' -f 7`

ip route del default via $GATEWAY dev bond0
ip addr del $SUBNET dev bond0
ip addr add $SUBNET dev br-ex
ip addr add $PROVIDER_IP dev br-ex
ifconfig br-ex up
ovs-vsctl add-port br-ex bond0
ip route add default via $GATEWAY dev br-ex

chmod +x /etc/rc.d/rc.local

cat >> /etc/rc.d/rc.local <<- EOM
ip route del default via $GATEWAY dev bond0
ip addr del $SUBNET dev bond0
ip addr add $SUBNET dev br-ex
ip addr add $PROVIDER_IP dev br-ex
ifconfig br-ex up
ip route add default via $GATEWAY dev br-ex
EOM

echo "networking has changed. recommend rebooting at this time to restart all the cloud services."
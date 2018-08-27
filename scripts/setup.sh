#!/bin/bash

yum -y update
yum install -y https://www.rdoproject.org/repos/rdo-release.rpm
yum install -y openstack-packstack
yum -y update

time packstack --allinone \
	--os-cinder-install=y \
	--os-ceilometer-install=n \
	--os-neutron-ml2-type-drivers=flat,vxlan \
	--os-heat-install=y \
    --os-neutron-lbaas-install=y

# end of OpenStack cloud install

## rpcops-onmetal-labconfigurator
Configuration script that builds out a X node lab environment for onboarding and testing purposes for Rackspace Private Cloud.  

## REQUIREMENTS ##
#### IAD Region Public Cloud Server  

OnMetal I/O v1: Ubuntu 14.04 LTS (Trusty Tahr)  
CPU: Dual 2.8 Ghz, 10 core Intel® Xeon® E5-2680 v2  
RAM: 128 GB  
System Disk: 32 GB  
Data Disk: Dual 1.6 TB PCIe flash cards  
Network: Redundant 10 Gb / s connections in a high availability bond  
Disk I/O: Good

# IMPORTANT
Before you run this, ensure that your host machine has acpi=noirq in the kernel parameters for boot  
This is necessary as there is a bug whereby the total number of CPUs will not be available if not done  
This requirement will more than likely be removed going forward as issue has been raised with images team  

## Pre Installation Considerations
##### Make sure your OnMetal host package cache is up-to-date, has git as it is required, vim|tmux|screen are optional, and using all available CPUs  

```shell
# Install at a minimum git
apt-get update
apt-get install -y vim tmux screen git

# Manually check for acpi bug and fix if you did not already heed the IMPORTANT section above
if ! [ `awk '/processor/ { count++ } END { print count }' /proc/cpuinfo` -eq 40 ]; then
  echo -e "No bueno! acpi=off or another issue.\n"
  echo -e "Fixing acpi=off. If this does not work, investigate further."
  sed -i.bak 's/acpi=off/acpi=noirq/' /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
  update-grub
  touch /acpi-fixed
else
  echo "Good to go! acpi=noirq or bug irrelevant"
fi

# Reboot for server to realize changes
shutdown -r now
```
__Ping requests will fail, keep checking for SSH connectivity__

## Installation Steps ##
```shell
# From the OnMetal host change to root directory
cd /root
# Clone the lab repo
git clone https://github.com/codebauss/rpcops-onmetal-labconfigurator
# Change into the lab repo directory
cd rpcops-onmetal-labconfigurator
# Create tmux session for install (recommended but not required)
tmux new-session -s rpcops
# Run the host setup script; will take some time (10-15m)
bash rpcops-host-setup
# Run the lab configuration setup; will take some time (5m)
# You can pass lab configuration/type, if nothing, default
# Lab Configs: (only default available at this time)
# default, defaultceph, defaultswift, defaultcinder, cephonly, swiftonly
bash rpcops-unattended-setup

# Once the above have completed

# SSH into infra01
ssh root@10.5.0.101
# Clone rpc-openstack to /opt
cd /opt
# Using Kilo here, be sure to check out branch you want
git clone -b r11.1.5 --recursive https://github.com/rcbops/rpc-openstack
# Bootstrap ansible
cd rpc-openstack/openstack-ansible
scripts/bootstrap-ansible.sh
# Copy openstack_deploy to etc
cp -r /opt/rpc-openstack/openstack-ansible/etc/openstack_deploy /etc/

# Copy VPX configuration script
cd /root
curl -sk https://raw.githubusercontent.com/codebauss/rpcops-onmetal-labconfigurator/master/resources/files/vpx-configurator -o vpx-configurator

# Get jq helper library
pushd /usr/local/bin
wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
mv jq-linux64 jq
chmod +x jq
popd

# Generate OpenStack Inventory
/opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py > /dev/null

# Update LoadBalancer with servers and bindings from inventory
# password is nsroot
ssh nsroot@10.5.0.4 <<EOF
`bash /root/vpx-configurator`
save config
EOF

# Check for existing SSH key on infra01 and create if there is not one
if [ ! -f "/root/.ssh/id_rsa" ]; then
  echo -e "\n" | ssh-keygen -t rsa -N ''
fi

# Copy infra01 SSH key to all nodes
# password is stack
for i in infra01 infra02 infra03 compute01 compute02; do
  ssh-copy-id -o StrictHostKeyChecking=no $i
done

# Set deploy.sh envrionment variables
export DEPLOY_HAPROXY='no'
export DEPLOY_MAAS='no'
export DEPLOY_ELK='no'

# Run deploy.sh
cd /opt/rpc-openstack
scripts/deploy.sh
```

## Post Installation Considerations ##
#### Configure public key authentication to load balancer (password: nsroot)
```shell
__SSHKEY__=$(cat /root/.ssh/id_rsa.pub)
ssh nsroot@10.5.0.4 <<EOF
shell touch /nsconfig/ssh/authorized_keys && \
chmod 600 /nsconfig/ssh/authorized_keys && \
echo $__SSHKEY__ > /nsconfig/ssh/authorized_keys
EOF
```

**Note:**  
This uses a trial license from Citrix - NetScaler VPX 1000 - which is good for 90 days. Once your lab is online, check the loadbalancer via SSH with the command 'show license'. You will want to be sure you see the following:
( ssh nsroot@10.5.0.4 'show license' )

	License status:
	                ...
	                Load Balancing: YES
	                ...

If not, run the following commands to get the latest license file, remove the current license, and install the new license **be sure you have set public key authentication up as noted above**:
```shell
# Remove current license
ssh nsroot@10.5.0.4 <<EOF
shell rm -f /nsconfig/license/lb.lic
EOF

# Add new license to load balancer
ssh nsroot@10.5.0.4 <<EOF
shell cd /nsconfig/license && \
curl -sk https://raw.githubusercontent.com/codebauss/rpcops-onmetal-labconfigurator/master/resources/files/lb.lic -o lb.lic
EOF

# Get session token
__NSTOKEN__=`curl -s -X POST -H 'Content-Type: application/json' \
http://10.5.0.4/nitro/v1/config/login \
-d '{"login": {"username":"nsroot","password":"nsroot","timeout":3600}}'|jq -r .sessionid`

# Warm reboot the load balancer
curl -s -X POST -H 'Content-Type: application/json' \
-H "Cookie: NITRO_AUTH_TOKEN=$__NSTOKEN__" \
http://10.5.0.4/nitro/v1/config/reboot -d '{"reboot":{"warm":true}}'

```

## Login Considerations ##
__OnMetal Host__  
SSH Public Key Authentication required during build  
*you can modify /etc/ssh/sshd_config to allow password authentication*  

__VyOS Firewall__  
ssh vyos@192.168.0.2  
password: vyos

__NetScaler VPX LoadBalancer__  
ssh nsroot@10.5.0.4  
password: nsroot  
GUI: http://{{ onmetal_host_public_ipv4_address }}:1413  

__OpenStack Nodes__  
User: root  
Pass: stack  

## Network Considerations ##

Firewalls: 192.168.0.2-7/24  
LoadBalancers: 192.168.0.249-254/24  
Node Public Addresses: 192.168.239.101-124/24  
OpenStack Public/Floating IPs: 192.168.240.1-99/22  

Tenant VLANS: 206-210  

Network | IP Block(s) | VLAN
--------|-------------|-----
Host/Node | 10.239.0.0/22 | 201
Gateway | 10.240.0.0/22 | 205
Container | 172.29.236.0/22 | 202
Tunnel/Overlay | 172.29.240.0/22 |
Storage | 172.29.244..0/22 |
Swift | 172.29.248.0/22 |
DRAC | 10.5.0.0/24 |
ServiceNet | 10.6.0.0/24 |
Public | 192.168.0.0/24 |
       | 192.168.239.0/24 |
       | 192.168.240.0/22 |

__NAT Translations on Firewall__  

Type | Address Block | Translation
-----|---------------|------------
DNAT | 192.168.239.101-105/24 | 10.239.0.101-105/24
     | 192.168.240.2-16/22 | 10.240.0.21-36/22
     | 172.29.236.100/22 | 192.168.0.249/24
SNAT | 10.239.0.101-105/24 | 192.168.239.101-105/24
     | 10.240.0.21-36/22 | 192.168.240.2-16/22
     | 172.24.96.249/24 | 192.168.0.249/24

## Libvirt Virtualization Considerations ##
#### Networks  
drac00: 10.5.0.0/24  
snet00: 10.6.0.0/24  
public00: 192.168.0.0/24 192.168.239.0/24 192.168.240.0/22

## Open vSwitch Considerations ##
#### Virtual Switches  
fwlbsw  
lbsrvsw  
hasw  

#### Contributors
Melvin Hillsman _codebauss_  
Kevin Carter _cloudnull_  
James Thorne _jameswthorne_
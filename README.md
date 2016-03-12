# IMPORTANT
Before you run this, ensure that your host machine has acpi=noirq in the kernel parameters for boot  
This is necessary as there is a bug whereby the total number of CPUs will not be available if not done  

#### Quick Fix (root or sudo required)
```shell
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
```


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

## Login Considerations ##

## Network Considerations ##
Network | IP Block(s)
--------|------------
Host/Node | 10.239.0.0/22
Gateway | 10.240.0.0/22
Container | 172.29.236.0/22
Tunnel/Overlay | 172.29.240.0/22
Storage | 172.29.244..0/22
Swift | 172.29.248.0/22
Drac | 10.5.0.0/24
ServiceNet | 10.6.0.0/24
Public | 192.168.0.0/24 192.168.239.0/24 192.168.240.0/22

## Libvirt Virtualization Considerations ##
#### Networks  
drac00  
snet00  
public00

## Open vSwitch Considerations ##
#### Virtual Switches  
fwlbsw  
lbsrvsw  
hasw

**Note:**  
This uses a trial license from Citrix - NetScaler VPX 1000 - which is good for 90 days. Once your lab is online, check the loadbalancer via SSH with the command 'show license'. You will want to be sure you see the following:

	License status:
	                ...
	                Load Balancing: YES
	                ...

If not, run the following command to get the latest license file, remove the current license, and install the new license:
_need to add command_

#!/bin/bash
#
# Script to deploy a wrking cobbler installation in Ubuntu Server 14.10
# Author: Luis Henrique Bolson <luis@luisb.net>
#
# Based on http://springerpe.github.io/tech/2014/09/09/Installing-Cobbler-2.6.5-on-Ubuntu-14.04-LTS.html
#
# Please run as root (don't use sudo <script>)
#
# curl -s https://raw.githubusercontent.com/luisbolson/cobbler/master/cobbler_install-ubuntu_14.04.sh | bash -s 192.168.56.101
#

# Add cobbler repository
wget -qO - http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/Release.key | apt-key add -
add-apt-repository "deb http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/ ./"

# Update APT repo and install required packages
apt-get update
apt-get install -y cobbler debmirror isc-dhcp-server ipcalc tftpd

# Get network information for the given IP
IP_ADDR=$1
NETMASK=$(ifconfig | grep $IP_ADDR | cut -d ':' -f 4)
NETDEVICE=$(ifconfig | grep -B1 $IP_ADDR | head -1 | awk '{print $1}')
NETWORK=$(ipcalc ${IP_ADDR}/${NETMASK} | grep Network | cut -d '/' -f 1 | awk '{print $2}')
NETMASK_HALF=$(expr $(ipcalc ${IP_ADDR}/${NETMASK} | grep Network | cut -d '/' -f 2 | awk '{print $1}') + 1)
DHCP_MIN_HOST=$(ipcalc ${IP_ADDR}/${NETMASK_HALF} | grep Broadcast | awk '{print $2}')
DHCP_MAX_HOST=$(ipcalc ${IP_ADDR}/${NETMASK} | grep HostMax | awk '{print $2}')

# Move Cobbler Apache config to the right place
cp /etc/apache2/conf.d/cobbler.conf /etc/apache2/conf-available/
cp /etc/apache2/conf.d/cobbler_web.conf /etc/apache2/conf-available/

# Enable the above config
a2enconf cobbler cobbler_web

# Enable Proxy modules
a2enmod proxy
a2enmod proxy_http

# Generate a new django secret key
SECRET_KEY=$(python -c 'import re;from random import choice; import sys; sys.stdout.write(re.escape("".join([choice("abcdefghijklmnopqrstuvwxyz0123456789^&*(-_=+)") for i in range(100)])))')
sed -i "s/^SECRET_KEY = .*/SECRET_KEY = '${SECRET_KEY}'/" /usr/share/cobbler/web/settings.py

# Change IP and manage_dhcp in cobbler settings
sed -i "s/127\.0\.0\.1/${IP_ADDR}/" /etc/cobbler/settings
sed -i "s/manage_dhcp: .*/manage_dhcp: 1/" /etc/cobbler/settings

# Change DHCP server template to match the given network configuration
sed -i "s/subnet .* netmask .* {/subnet $NETWORK netmask $NETMASK {/" /etc/cobbler/dhcp.template
sed -i "/option routers             192.168.1.5;/d" /etc/cobbler/dhcp.template
sed -i "/option domain-name-servers 192.168.1.1;/d" /etc/cobbler/dhcp.template
sed -i "s/range dynamic-bootp .*/range dynamic-bootp        ${DHCP_MIN_HOST} ${DHCP_MAX_HOST};/" /etc/cobbler/dhcp.template

# Change dhcp-server default listening interface
sed -i "s/INTERFACES=.*/INTERFACES=\"${NETDEVICE}\"/" /etc/default/isc-dhcp-server

# Fix TFTP server arguments in cobbler template to enable it to work on Ubuntu
sed -i "s/server_args .*/server_args             = -s \$args/" /etc/cobbler/tftpd.template

# Fix Apache conf to match 2.4 configuration
sed -i "/Order allow,deny/d" /etc/apache2/conf-enabled/cobbler*.conf
sed -i "s/Allow from all/Require all granted/" /etc/apache2/conf-enabled/cobbler*.conf

# Permission Workarounds
mkdir /tftpboot
chown www-data /var/lib/cobbler/webui_sessions

# Restart services
service cobblerd restart
service apache2 restart

# Get Loaders
cobbler get-loaders

# Update Cobbler Signatures
cobbler signature update

# Restart services again and configure autostart
service cobblerd restart
service apache2 restart
service xinetd restart
update-rc.d cobblerd defaults

# Sync cobbler configuration
cobbler sync

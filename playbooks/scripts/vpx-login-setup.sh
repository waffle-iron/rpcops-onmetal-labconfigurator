#!/bin/bash

# Check that empty-expect is installed and install if not
dpkg --get-selections | grep empty
rc=$?
if ! [ $rc -eq 0 ]; then
  apt-get install -y empty-expect
fi

# Check that loadbalancer is in /etc/hosts
grep 10.5.0.4 /etc/hosts
rc=$?
if ! [ $rc -eq 0 ]; then
  echo -e "\n10.5.0.4\tloadbalancer" >> /etc/hosts
fi

# Get hostname for loadbalancer
__LBHOSTNAME__=`awk '/10.5.0.4/ { print $2 }' /etc/hosts`

# Copy SSH key to firewall
# Check if password-less login to firewall is working
ssh -o BatchMode=yes nsroot@$__LBHOSTNAME__ 'exit'

# If password-less login works, continue
# else setup password-login and then continue
if ! [ $? -eq 0 ]; then
  # Copy SSH key to firewall
  empty -f -i input.fifo -o output.fifo -p vpxconfig.pid -L vpxconfig.log ssh-copy-id -o StrictHostKeyChecking=no nsroot@$__LBHOSTNAME__
  sleep 3
  empty -w -i output.fifo -o input.fifo "assword" "nsroot\n"
fi

#!/bin/sh

# Do not use this unless you know what you're doing!!!
# This can open up security holes on your machine.

# This script makes a brew-installed binary run as root automatically, such as htop:
# ./brewroot htop 

brewbin=`find /usr/local/Cellar -iname "*$1*" | grep 'bin'` 
echo $brewbin
sudo chown root:wheel $brewbin
sudo chmod u+s $brewbin
echo "$1 is now exectuable as auto root."

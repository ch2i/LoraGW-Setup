#!/bin/bash

if [ $(id -u) -ne 0 ]; then
	echo "Installer must be run as root."
	echo "Try 'sudo bash $0'"
	exit 1
fi

MODEL=`cat /proc/device-tree/model`

echo "This script configure a Raspberry Pi"
echo "Raspian for being a LoRaWAN Gateway"
echo
echo "Device is $MODEL"
echo
echo "Run time ~10 minutes. Reboot required."
echo
echo -n "CONTINUE? [y/N] "
read
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Canceled."
	exit 0
fi

# Given a filename, a regex pattern to match and a replacement string:
# If found, perform replacement, else append file w/replacement on new line.
replaceAppend() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	else
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append file with string on new line.
append1() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

echo "Updating dependencies"
apt-get update && sudo apt-get upgrade && sudo apt-get update
apt-get install -y --force-yes git-core build-essential ntp scons python-dev swig python-psutil

echo "Adding new user loragw, enter it password"
useradd -m loragw -s /bin/bash
passwd loragw
usermod -a -G sudo loragw
cp /etc/sudoers.d/010_pi-nopasswd /etc/sudoers.d/010_loragw-nopasswd
sed -i -- 's/pi/loragw/g' /etc/sudoers.d/010_loragw-nopasswd
cp /home/pi/.profile /home/loragw/
cp /home/pi/.bashrc /home/loragw/
chown loragw:loragw /home/loragw/.*
usermod -a -G i2c,spi,gpio loragw

echo "Enabling Uart, I2C, SPI, Video Memory to 16MB"
replaceAppend /boot/config.txt "^enable_uart.*$" "enable_uart=1"
replaceAppend /boot/config.txt "^dtparam=i2c_arm=.*$" "dtparam=i2c_arm=on"
replaceAppend /boot/config.txt "^dtparam=spi=.*$" "dtparam=spi=on"
replaceAppend /boot/config.txt "^gpu_mem=.*$" "gpu_mem=16"

echo -n "Do you want to configure timezone [y/N] "
read
if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Reconfiguring Time Zone."
	dpkg-reconfigure tzdata
fi

echo -n "Do you want to enable log2ram [y/N] "
read
if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Setting up log2ram."
	git clone https://github.com/azlux/log2ram.git
	cd log2ram
	chmod +x install.sh uninstall.sh
	./install.sh
	ln -s /usr/local/bin/ram2disk /etc/cron.hourly/
fi

# set hostname to loragw-xxyy with xxyy last MAC Address digits
set -- `cat /sys/class/net/wlan0/address`
IFS=":"; declare -a Array=($*)
HOST=loragw-${Array[4]}${Array[5]}
echo "New hostname will be set to $HOST"
echo -n "OK? [y/N] "
read
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	sudo echo "$HOST" >/etc/hostname
fi

echo "Done."
echo
echo "Settings take effect on next boot."
echo "after reboot, login back here with"
echo "ssh loragw@$HOST.local"
echo
echo -n "REBOOT NOW? [y/N] "
read
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Exiting without reboot."
	exit 0
fi
echo "Reboot started..."
reboot
exit 0


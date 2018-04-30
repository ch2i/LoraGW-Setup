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
echo "Run time ~5 minutes. Reboot required."
echo
echo -n "CONTINUE? [Y/n] "
read
if [[ "$REPLY" =~ ^(no|n|N)$ ]]; then
	echo "Canceled."
	exit 0
fi

# These functions have been copied from excellent Adafruit Read only tutorial
# https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/blob/master/read-only-fs.sh
# the one inspired by my original article http://hallard.me/raspberry-pi-read-only/
# That's an excellent demonstration of collaboration and open source sharing
# 
# Given a filename, a regex pattern to match and a replacement string:
# Replace string if found, else no change.
# (# $1 = filename, $2 = pattern to match, $3 = replacement)
replace() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	fi
}

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

# Given a list of strings representing options, display each option
# preceded by a number (1 to N), display a prompt, check input until
# a valid number within the selection range is entered.
selectN() {
	for ((i=1; i<=$#; i++)); do
		echo $i. ${!i}
	done
	echo
	REPLY=""
	while :
	do
		echo -n "SELECT 1-$#: "
		read
		if [[ $REPLY -ge 1 ]] && [[ $REPLY -le $# ]]; then
			return $REPLY
		fi
	done
}

echo "Updating dependencies"
apt-get update && apt-get upgrade -y --force-yes && apt-get update
apt-get install -y --force-yes git-core build-essential ntp scons i2c-tools

echo "Updating python dependencies"
apt-get install -y --force-yes python-dev swig python-psutil python-rpi.gpio python-pip
python -m pip install --upgrade pip setuptools wheel

if [[ ! -d /home/loragw ]]; then
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
fi

echo "Enabling Uart, I2C, SPI, Video Memory to 16MB"
replaceAppend /boot/config.txt "^.*enable_uart.*$" "enable_uart=1"
replaceAppend /boot/config.txt "^.*dtparam=i2c_arm=.*$" "dtparam=i2c_arm=on"
replaceAppend /boot/config.txt "^.*dtparam=spi=.*$" "dtparam=spi=on"
replaceAppend /boot/config.txt "^.*gpu_mem=.*$" "gpu_mem=16"
replaceAppend /etc/modules "^.*i2c-dev.*$" "i2c-dev"

echo -n "Do you want to configure timezone [y/N] "
read
if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Reconfiguring Time Zone."
	dpkg-reconfigure tzdata
fi

if [[ ! -f /usr/local/bin/log2ram ]]; then
	echo -n "Do you want to enable log2ram [y/N] "
	read
	if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
		echo "Setting up log2ram."
		git clone https://github.com/azlux/log2ram.git
		cd log2ram
		chmod +x install.sh uninstall.sh
		./install.sh
		ln -s /usr/local/bin/log2ram /etc/cron.hourly/
		echo "cleaning up log rotation"
		replace /etc/logrotage.d/rsyslog "^.*daily.*$" "    hourly"
		replace /etc/logrotage.d/rsyslog "^.*monthly.*$" "    daily"
		replace /etc/logrotage.d/rsyslog "^.*delaycompress.*$" "  "

		echo "forcing one log rotation"
		logrotate /etc/logrotate.conf
		echo "Please don't forget to adjust the logrotate"
		echo "paratemeters in /etc/logrotage.d/* to avoid"
		echo "filling up the ramdisk, see README in"
		echo "https://github.com/ch2i/LoraGW-Setup/"
		echo ""
	fi
fi

# set hostname to loragw-xxyy with xxyy last MAC Address digits
set -- `cat /sys/class/net/wlan0/address`
IFS=":"; declare -a Array=($*)
NEWHOST=loragw-${Array[4]}${Array[5]}

echo ""
echo "Please select new device name (hostname)"
selectN "Leave as $HOSTNAME" "loragw" "$NEWHOST"
SEL=$?
if [[ $SEL -gt 1 ]]; then
	if [[ $SEL == 2 ]]; then
    NEWHOST=loragw
	fi
	sudo bash -c "echo $NEWHOST" > /etc/hostname
	replace /etc/hosts  "^127.0.1.1.*$HOSTNAME.*$" "127.0.1.1\t$NEWHOST"
  echo "New hostname set to $NEWHOST"
else
  echo "hostname unchanged"
fi

echo "Done."
echo
echo "Settings take effect on next boot."
echo "after reboot, login back here with"
echo "ssh loragw@$NEWHOST.local"
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


#!/bin/bash

INSTALL_DIR="/opt/loragw"
MODEL=`cat /proc/device-tree/model`

if [ $(id -u) -ne 0 ]; then
  echo "Installer must be run as root."
  echo "Try 'sudo bash $0'"
  exit 1
fi

echo "This script configures a Raspberry Pi"
echo "as a wifi access pointonnected to TTN,"
echo
echo "It will install the following dependencies"
echo "hostapd, dnsmasq and configure SSID / Password"
echo
echo "Device is $MODEL"
echo
echo "Run time ~1 minute. Reboot required."
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


echo ""
echo "Enter SSID you want to see for your WiFi AP"
echo -n "default is set to $HOSTNAME : "
read SSID
if [[ $SSID == "" ]]; then
  SSID=$HOSTNAME
fi

echo ""
echo "Enter password you want for you access point"
echo -n "default is set $SSID : "
read PSK
if [[ $PSK == "" ]]; then
  PSK=$SSID
fi

echo ""
echo "Please enter WiFi country code"
echo -n "default is set to FR : "
read CCODE

echo ""
echo "Setting up WiFi access point with"
echo "SSID : $SSID"
echo "PSK  : $PSK"

sudo apt-get install -y hostapd dnsmasq 

# Set the SSID/PSK 
echo "Replacing SSID / PASK in hostapd.conf"
replace ./config/hostapd.conf "^.*_AP_SSID_.*$" "ssid=$SSID"
replace ./config/hostapd.conf "^.*_AP_PASSWORD_.*$" "wpa_passphrase=$PSK"
if [[ $CCODE != "" ]]; then
  echo "Setting default country code to $CCCODE in hostapd.conf"
  replace ./config/hostapd.conf "^.*country_code=.*$" "country_code=$CCODE"
fi

# Copy configuration files
cp ./config/90-wireless.rules /etc/udev/rules.d/
cp ./config/hostapd.conf /etc/hostapd/
cp ./config/dnsmasq.conf /etc/
cp ./config/interfaces /etc/network/

echo "Setting default hostapd config file"
append1 /etc/default/hostapd "^.*DAEMON_CONF=.*$" "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\""

# disable dhcpcd service
update-rc.d dhcpcd disable

# Fix bootup 
cp ./config/rc.local /etc/

echo "Done."
echo
echo "Settings take effect on next boot."
echo "after reboot, login back here with"
echo "ssh loragw@$HOSTNAME.local"
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




#!/bin/bash

INSTALL_DIR="/opt/loragw"
MODEL=`cat /proc/device-tree/model`

if [ $(id -u) -ne 0 ]; then
  echo "Installer must be run as root."
  echo "Try 'sudo bash $0'"
  exit 1
fi

echo "This script configures a Raspberry Pi"
echo "as a wifi access point and client"
echo
echo "It will install a docker container doing"
echo "all the necessary staff, please see"
echo "https://github.com/cjimti/iotwifi"
echo
echo "Device is $MODEL"
echo

echo "Run time ~3 minutes. Reboot required."
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

echo "installing dpendencies"
echo "Docker install script"
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker loragw

echo "ull the IOT Wifi Docker Image"
docker pull cjimti/iotwifi

# Set the SSID/PSK
echo "Replacing SSID / PASK in hostapd.conf"
replace ./wificfg.json "^.*_AP_SSID_.*$" "$SSID"
replace ./wificfg.json "^.*_AP_PASSWORD_.*$" "$PSK"

# Copy config file to install folder
sudo mv ./wificfg.json $INSTALL_DIR/
sudo ln -s $INSTALL_DIR/wificfg.json ./

if [[ $CCODE != "" ]]; then
  echo "Setting default country code to $CCCODE in hostapd.conf"
  replace /etc/wpa_supplicant/wpa_supplicant.conf "^.*country=.*$" "country=$CCODE"
fi


# prevent wpa_supplicant from starting on boot it will be used by docker
sudo systemctl mask wpa_supplicant.service
# rename wpa_supplicant on the host to ensure that it is not used.
sudo mv /sbin/wpa_supplicant /sbin/wpa_supplicant.old
# kill any running processes named wpa_supplicant
sudo pkill wpa_supplicant

echo "starting docker as a service"
docker run --restart unless-stopped -d --privileged --net host \
        -v /opt/loragw//wificfg.json:/cfg/wificfg.json \
        -v /etc/wpa_supplicant/wpa_supplicant.conf:/etc/wpa_supplicant/wpa_supplicant.conf \
        cjimti/iotwifi

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


#!/bin/bash

INSTALL_DIR="/opt/loragw"
MODEL=`cat /proc/device-tree/model`

if [ $(id -u) -ne 0 ]; then
  echo "Installer must be run as root."
  echo "Try 'sudo bash $0'"
  exit 1
fi

echo "This script configures a Raspberry Pi"
echo "GPS for TTN gateway"
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

echo ""
echo "Enter GPS device to use"
echo -n "default is set to /dev/ttyS0 : "
read DEVGPS
if [[ $DEVGPS == "" ]]; then
  DEVGPS="/dev/ttyS0"
fi

sudo systemctl stop serial-getty@ttyS0.service
sudo systemctl disable serial-getty@ttyS0.service

echo
echo "now change the file $INSTALL_DIR/local_conf.json"
echo "and check that the following lines exist"
echo
echo '"fake_gps": false,'
echo '"gps": true,'
echo '"gps_tty_path": "'$DEVGPS'"'
echo
echo "you may also need to add theese lines"
echo "to /boot/config.txt (example for PI 3)"
echo
echo "dtoverlay = pi3-miniuart-bt"
echo "enable_uart=1"
echo
echo "then reboot the Raspberry Pi"


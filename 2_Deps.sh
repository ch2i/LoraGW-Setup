#!/bin/bash

MODEL=`cat /proc/device-tree/model`

echo "This script configures a Raspberry Pi"
echo "as a LoRaWAN Gateway connected to TTN,"
echo
echo "It will install the following dependencies"
echo "nodejs, git, pyhton, ntp, scons, ws2812"
echo
echo "Device is $MODEL"
echo
echo "Run time ~10 minutes."
echo
echo -n "CONTINUE? [Y/n] "
read
if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
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

echo "Target board/shield for this $MODEL:"
selectN "CH2i RAK831 Minimal" "CH2i RAK831 with WS2812B Led" "CH2i ic880a" "All other models"
BOARD_TARGET=$?


echo -n "Do you want to install I2C OLED [y/N] "
read OLED
if [[ "$OLED" =~ ^(yes|y|Y)$ ]]; then
	echo "Reconfiguring Time Zone."
	dpkg-reconfigure tzdata
fi

grep "Pi 3" $MODEL >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs v8 for Raspberry PI 3"
	sudo curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
	sudo apt-get install nodejs
fi

grep "Pi Zero" $MODEL >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs lts for Raspberry PI Zero"
	sudo wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v.lts.sh | bash
	append1 /home/loragw/.profile "^.*PATH:/opt/nodejs/bin.*$" "export PATH=$PATH:/opt/nodejs/bin"
	append1 /home/loragw/.profile "^.*NODE_PATH=.*$" "NODE_PATH=/opt/nodejs/lib/node_modules"
fi

# Board has WS1812B LED
if [[ $BOARD_TARGET == 2 ]]; then
  echo "Installing WS2812B LED driver"

  echo "Blacklisting snd_bcm2835 module due to WS2812b LED PWM"
  append1 /etc/modprobe.d/snd-blacklist.conf "^.*snd_bcm2835.*$" "blacklist snd_bcm2835"

  echo "Installing WS2812B drivers and libraries"
  git clone https://github.com/jgarff/rpi_ws281x
  cd rpi_ws281x/
  scons
  scons deb
  sudo dpkg -i libws2811*.deb
  sudo cp ws2811.h /usr/local/include/
  sudo cp rpihw.h /usr/local/include/
  sudo cp pwm.h /usr/local/include/
  cd python
  python ./setup.py build
  sudo python setup.py install
  cd
  sudo npm install -g --unsafe-perm rpi-ws281x-native
  npm link rpi-ws281x-native
fi

if [[ "$OLED" =~ ^(yes|y|Y)$ ]]; then
  echo "Configuring and installing OLED driver"
  replaceAppend /boot/config.txt "^dtparam=i2c_arm=.*$" "dtparam=i2c_arm=on,i2c_baudrate=400000"
  sudo apt-get install -y --force-yes i2c-tools python-dev python-pip libfreetype6-dev libjpeg-dev build-essential

  echo "Install luma OLED core"
  sudo -H pip install --upgrade luma.oled

  echo "Get examples files (and font)"
  sudo mkdir -p /usr/share/fonts/truetype/luma
  git clone https://github.com/rm-hull/luma.examples.git
  sudo cp luma.examples/examples/fonts/*.ttf /usr/share/fonts/truetype/luma/
fi





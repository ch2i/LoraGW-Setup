#!/bin/bash

INSTALL_DIR="/opt/loragw"
MODEL=`cat /proc/device-tree/model`

if [ $(id -u) -ne 0 ]; then
  echo "Installer must be run as root."
  echo "Try 'sudo bash $0'"
  exit 1
fi

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

apt-get -y install protobuf-compiler libprotobuf-dev libprotoc-dev automake libtool autoconf python-dev python-rpi.gpio

grep "Pi 3" $MODEL >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs v8 for Raspberry PI 3"
	curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
	apt-get install nodejs
fi

grep "Pi Zero" $MODEL >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs lts for Raspberry PI Zero"
	wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v.lts.sh | bash
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
  dpkg -i libws2811*.deb
  cp ws2811.h /usr/local/include/
  cp rpihw.h /usr/local/include/
  cp pwm.h /usr/local/include/
  cd python
  python ./setup.py build
  python setup.py install
  cd
  npm install -g --unsafe-perm rpi-ws281x-native
  npm link rpi-ws281x-native
fi

if [[ "$OLED" =~ ^(yes|y|Y)$ ]]; then
  echo "Configuring and installing OLED driver"
  replaceAppend /boot/config.txt "^dtparam=i2c_arm=.*$" "dtparam=i2c_arm=on,i2c_baudrate=400000"
  apt-get install -y --force-yes i2c-tools python-dev python-pip libfreetype6-dev libjpeg-dev build-essential

  echo "Install luma OLED core"
  sudo -H pip install --upgrade luma.oled

  echo "Get examples files (and font)"
  mkdir -p /usr/share/fonts/truetype/luma
  git clone https://github.com/rm-hull/luma.examples.git
  cp luma.examples/examples/fonts/*.ttf /usr/share/fonts/truetype/luma/
fi

Echo "Building LoraGW and packet Forwarder"
mkdir -p $INSTALL_DIR/dev
cd $INSTALL_DIR/dev

if [ ! -d lora_gateway ]; then
    git clone https://github.com/kersing/lora_gateway.git  || { echo 'Cloning lora_gateway failed.' ; exit 1; }
else
    cd lora_gateway
    git reset --hard
    git pull
    cd ..
fi

if [ ! -d paho.mqtt.embedded-c ]; then
    git clone https://github.com/kersing/paho.mqtt.embedded-c.git  || { echo 'Cloning paho mqtt failed.' ; exit 1; }
else
    cd paho.mqtt.embedded-c
    git reset --hard
    git pull
    cd ..
fi

if [ ! -d ttn-gateway-connector ]; then
    git clone https://github.com/kersing/ttn-gateway-connector.git  || { echo 'Cloning gateway connector failed.' ; exit 1; }
else
    cd ttn-gateway-connector
    git reset --hard
    git pull
    cd ..
fi

if [ ! -d protobuf-c ]; then
    git clone https://github.com/kersing/protobuf-c.git  || { echo 'Cloning protobuf-c failed.' ; exit 1; }
else
    cd protobuf-c
    git reset --hard
    git pull
    cd ..
fi

if [ ! -d packet_forwarder ]; then
    git clone https://github.com/kersing/packet_forwarder.git  || { echo 'Cloning packet forwarder failed.' ; exit 1; }
else
    cd packet_forwarder
    git reset --hard
    git pull
    cd ..
fi

if [ ! -d protobuf ]; then
    git clone https://github.com/google/protobuf.git  || { echo 'Cloning protobuf failed.' ; exit 1; }
else
    cd protobuf
    git reset --hard
    git pull
    cd ..
fi


cd $INSTALL_DIR/dev/lora_gateway/libloragw
sed -i -e 's/PLATFORM= .*$/PLATFORM= imst_rpi/g' library.cfg
sed -i -e 's/CFG_SPI= .*$/CFG_SPI= native/g' library.cfg
make

cd $INSTALL_DIR/dev/protobuf-c
./autogen.sh
./configure
make protobuf-c/libprotobuf-c.la
mkdir bin
./libtool install /usr/bin/install -c protobuf-c/libprotobuf-c.la `pwd`/bin
rm -f `pwd`/bin/*so*

cd $INSTALL_DIR/dev/paho.mqtt.embedded-c/
make
make install

cd $INSTALL_DIR/dev/ttn-gateway-connector
cp config.mk.in config.mk
make
cp bin/libttn-gateway-connector.so /usr/lib/

cd $INSTALL_DIR/dev/packet_forwarder/mp_pkt_fwd/
make

# Copy things needed at runtime to where they'll be expected
cp $INSTALL_DIR/dev/packet_forwarder/mp_pkt_fwd/mp_pkt_fwd $INSTALL_DIR/mp_pkt_fwd

if [ ! -f $INSTALL_DIR/mp_pkt_fwd ]; then
    echo "Oup's, something went wrong, forwarder not found"
    echo "please check for any build error"
else
    echo "Build & Installation Completed."
    echo "forwrder is located at $INSTALL_DIR/mp_pkt_fwd"
    echo ""
    echo "you can now run the setup script with sudo ./3_Configure.sh"
fi



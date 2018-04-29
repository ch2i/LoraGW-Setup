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
echo "compile packet forwarder and install the"
echo "needed services (Monitor, Oled, GW) at boot"
echo
echo "Device is $MODEL"
echo
echo "Run time ~5 to 15 minutes depending on features."
echo
echo -n "CONTINUE? [Y/n] "
read
if [[ "$REPLY" =~ ^(no|n|N)$ ]]; then
  echo "Canceled."
  exit 0
fi

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

# These functions have been copied from excellent Adafruit Read only tutorial
# https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/blob/master/read-only-fs.sh
# the one inspired by my original article http://hallard.me/raspberry-pi-read-only/
# That's an excellent demonstration of collaboration and open source sharing
# 
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

echo ""
echo "Target board/shield for this $MODEL:"
selectN "CH2i RAK831 Minimal" "CH2i RAK831 with WS2812B Led" "CH2i ic880a" "RAK831 official shield" "All other models"
BOARD_TARGET=$?
if [[ $BOARD_TARGET == 1 ]]; then
  GW_RESET_PIN=25
  MONITOR_SCRIPT=monitor-ws2812.py
  export GW_RESET_PIN
fi
if [[ $BOARD_TARGET == 2 ]]; then
  GW_RESET_PIN=25
  MONITOR_SCRIPT=monitor-ws2812.py
  export GW_RESET_PIN
fi
if [[ $BOARD_TARGET == 3 ]]; then
  GW_RESET_PIN=17
  MONITOR_SCRIPT=monitor-gpio.py
  export GW_RESET_PIN
fi
if [[ $BOARD_TARGET == 4 ]]; then
  GW_RESET_PIN=17
  export GW_RESET_PIN
fi
echo "Monitor script is $MONITOR_SCRIPT"
echo "GW Reset pin is GPIO$GW_RESET_PIN"

echo ""
echo -n "Do you want to build Kersing packet forwarder [Y/n] "
read BUILD_GW

echo ""
echo -n "Do you want to build legacy packet forwarder [y/N] "
read BUILD_LEGACY

echo ""
echo "You can enable monitor service that manage blinking led to"
echo "display status and also add button management to shutdown PI"
echo -n "Would you like to enable this [Y/n] "
read EN_MONITOR

echo ""
echo "If you a OLED display, You can enable OLED service that"
echo "display some system information and LoRaWAN packet info"
echo -n "Do you want to install I2C OLED [y/N] "
read EN_OLED

echo ""
echo -n "Do you want to setup TTN [Y/n] "
read EN_TTN
if [[ ! "$EN_TTN" =~ ^(no|n|N)$ ]]; then

  echo "It's now time to create and configure your gateway on TTN"
  echo "See https://www.thethingsnetwork.org/docs/gateways/registration.html#via-gateway-connector"
  echo "once done, grab your gateway id (GW_ID) and key (GW_KEY) and paste them here"

  if [[ $GW_ID == "" ]]; then
      echo "No environement for GW_ID"
      echo ""
      echo -n "Please enter GW_ID: "
      read GW_ID
      export GW_ID
  fi

  if [[ $GW_KEY == "" ]]; then
      echo "No environement for GW_KEY"
      echo "See https://www.thethingsnetwork.org/docs/gateways/registration.html#via-gateway-connector"
      echo ""
      echo -n "Please enter GW_KEY: "
      read GW_KEY
      export GW_KEY
  fi

  if [[ $GW_RESET_PIN == "" ]]; then
      GW_RESET_PIN=25
      echo "No environement for GW_RESET_PIN"
      echo "Please select your reset pin"
      echo "see https://github.com/jpmeijers/ttn-resin-gateway-rpi/blob/master/README.md"
      echo "under section Reset Pin Values"
      echo "enter 25 (GPIO25) for this RAK831 shield or classic Gonzalo Casas"
      echo "enter 17 (GPIO17) for classic ic880A by CH2i"
      echo ""
      echo -n "Please enter GW_RESET_PIN [$GW_RESET_PIN]:"
      read GW_RESET_PIN
      export GW_RESET_PIN
  fi
fi

# Set the reset în in startup shell
replace ./start.sh "^.*RESET_BCM_PIN=.*$" "SX1301_RESET_BCM_PIN=$GW_RESET_PIN"

grep "Pi\ 3" /proc/device-tree/model >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs v8 for Raspberry PI 3"
	curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
	apt-get install nodejs

  # iC880a and RPI 3 Setup Activity LED and Power OFF Led 
  if [[ $BOARD_TARGET == 3 ]]; then
    replaceAppend /boot/config.txt "^dtoverlay=gpio-poweroff.*$" "dtoverlay=gpio-poweroff,gpiopin=24"
    replaceAppend /boot/config.txt "^dtoverlay=pi3-act-led.*$" "dtoverlay=pi3-act-led,gpio=23"
  fi

fi

grep "Pi\ Zero" /proc/device-tree/model >/dev/null
if [ $? -eq 0 ]; then
	echo "Installing nodejs lts for Raspberry PI Zero"
	wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v.lts.sh | bash
	append1 /home/loragw/.profile "^.*PATH:/opt/nodejs/bin.*$" "export PATH=$PATH:/opt/nodejs/bin"
	append1 /home/loragw/.profile "^.*NODE_PATH=.*$" "NODE_PATH=/opt/nodejs/lib/node_modules"
fi

apt-get -y install protobuf-compiler libprotobuf-dev libprotoc-dev automake libtool autoconf 

# Board has WS1812B LED
if [[ $BOARD_TARGET == 2 ]]; then
  echo "Installing WS2812B LED driver"
  cd /home/loragw/

  echo "Blacklisting snd_bcm2835 module due to WS2812b LED PWM"
  touch /etc/modprobe.d/snd-blacklist.conf
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
  cd /home/loragw/
  npm install -g --unsafe-perm rpi-ws281x-native
  npm link rpi-ws281x-native
  # We're sudo reset owner
  chown -R loragw:loragw /home/loragw/rpi_ws281x
  chown -R loragw:loragw /home/loragw/node_modules
fi

if [[ "$EN_OLED" =~ ^(yes|y|Y)$ ]]; then
  echo "Configuring and installing OLED driver"
  cd /home/loragw/
  replaceAppend /boot/config.txt "^.*dtparam=i2c_arm=.*$" "dtparam=i2c_arm=on,i2c_baudrate=400000"
  apt-get install -y --force-yes libfreetype6-dev libjpeg-dev

  echo "Install luma OLED core"
  sudo -H pip install --upgrade luma.oled

  echo "Get examples files (and font)"
  mkdir -p /usr/share/fonts/truetype/luma
  git clone https://github.com/rm-hull/luma.examples.git
  # We're sudo reset owner
  chown -R loragw:loragw /home/loragw/luma.examples
  cp luma.examples/examples/fonts/*.ttf /usr/share/fonts/truetype/luma/

  #echo "Build examples files"
  #sudo apt install libsdl-dev libportmidi-dev libsdl-ttf2.0-dev libsdl-mixer1.2-dev libsdl-image1.2-dev
  #sudo pip install --upgrade setuptools
  #cd luma.examples
  #udo -H pip install -e .
fi

if [[ ! "$BUILD_GW" =~ ^(no|n|N)$ ]]; then
  echo "Building LoraGW and kersing packet Forwarder"
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
      echo "Oup's, something went wrong, kersing forwarder not found"
      echo "please check for any build error"
  else
      echo "Build & Installation Completed."
      echo "kersing forwarder is located at $INSTALL_DIR/mp_pkt_fwd"
      echo ""
  fi
fi


if [[ "$BUILD_LEGACY" =~ ^(yes|y|Y)$ ]]; then
  echo "Building legacy packet Forwarder"

  mkdir -p $INSTALL_DIR/dev
  mkdir -p $INSTALL_DIR/dev/legacy
  cd $INSTALL_DIR/dev/legacy

  # Build legacy loragw library
  if [ ! -d lora_gateway ]; then
      git clone https://github.com/TheThingsNetwork/lora_gateway.git 
      pushd lora_gateway
  else
      pushd lora_gateway
      git reset --hard
      git pull
  fi
  sed -i -e 's/PLATFORM= .*$/PLATFORM= imst_rpi/g' ./libloragw/library.cfg
  sed -i -e 's/CFG_SPI= .*$/CFG_SPI= native/g' ./libloragw/library.cfg
  make

  popd
  # Build legacy packet forwarder
  if [ ! -d packet_forwarder ]; then
      git clone https://github.com/ch2i/packet_forwarder
      pushd packet_forwarder
  else
      pushd packet_forwarder
      git pull
      git reset --hard
  fi
  make
  popd

  if [ ! -f $INSTALL_DIR/poly_pkt_fwd ]; then
    echo "Oup's, something went wrong, legacy forwarder not found"
    echo "please check for any build error"
  else
    # Copy things needed at runtime to where they'll be expected
    cp $INSTALL_DIR/dev/legacy/packet_forwarder/poly_pkt_fwd/poly_pkt_fwd $INSTALL_DIR/poly_pkt_fwd
    echo "Build & Installation Completed."
    echo "forwarder is located at $INSTALL_DIR/poly_pkt_fwd"
    echo ""
    echo "Do you want this forwarder to be run instead"
    echo -n "kersing mp_pkt_fwd? [y/N] "
    read
    if [[ "$REPLY" =~ ^(yes|y|Y)$ ]]; then
      replace ./start.sh "^.*mp_pkt_fwd.*$" "./poly_pkt_fwd"
    fi

  fi

fi

# Copying all needed script and system
cd /home/loragw/LoraGW-Setup
cp ./oled.py $INSTALL_DIR/
cp ./monitor-ws2812.py  $INSTALL_DIR/
cp ./monitor-gpio.py  $INSTALL_DIR/
if [[ $MONITOR_SCRIPT != "" ]]; then
  ln -s $INSTALL_DIR/$MONITOR_SCRIPT  $INSTALL_DIR/monitor.py
fi
cp ./monitor.service /lib/systemd/system/
cp ./oled.service /lib/systemd/system/
cp start.sh  $INSTALL_DIR/

if [[ ! "$EN_TTN" =~ ^(no|n|N)$ ]]; then
  # script to get config from TTN server
  python set_config.py

  # Copy config to running folder
  sudo mv global_conf.json  $INSTALL_DIR/

  # Prepare start forwarder as systemd script
  sudo cp ./loragw.service /lib/systemd/system/
  sudo systemctl enable loragw.service
  sudo systemctl start loragw.service

  echo ""
  echo "all done, please check service running log with"
  echo "sudo journalctl -f -u loragw.service"

fi

if [[ ! "$EN_MONITOR" =~ ^(no|n|N)$ ]]; then
  echo "monitor service enabled!"
  sudo systemctl enable monitor.service
  sudo systemctl start monitor.service
  echo ""
fi

if [[ "$EN_OLED" =~ ^(yes|y|Y)$ ]]; then
  echo "Oled service enabled!"
  sudo systemctl enable oled.service
  sudo systemctl start oled.service
  echo "Please follow the procedure located here to finish setup"
  echo "https://github.com/ch2i/LoraGW-Setup/doc/DisplayOled.md"
  echo "Also don't forget to set the OLED wiring and type by editing file"
  echo "/opt/loragw/oled.py (as described into procedure)"
  echo ""
fi

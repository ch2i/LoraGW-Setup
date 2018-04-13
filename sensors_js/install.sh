#!/bin/bash

# ******************************************************************************
# installer script to send sensors data to cayenne IoT dashboard
# you can have a BMP280/BME280 and SI7021/HTU21D conencted to I2C bus
# This sample has been written by Charles-Henri Hallard (ch2i.eu)
# *******************************************************************************

function prog_installed {
  local ret=1
  type $1 >/dev/null 2>&1 || { local ret=0; }
  echo "$ret"
}

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

# Install repositories
INSTALL_DIR="/opt/loragw"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi


# Check if nodejs is installed
if [ $(prog_installed node) == 0 ]; then
  echo "nodejs not found, please install following lastest procedure"
	exit 1;
else
  echo "nodejs found, "`node -v`
fi

# nodejs module dependencies
pushd $INSTALL_DIR
if [ ! -d node_modules ]; then mkdir node_modules; fi
modules=( bme280-sensor si7021-sensor cayennejs )
for mod in "${modules[@]}"
do
	echo "Installing NodeJS $mod"
	npm install -g --unsafe-perm $mod
	npm link $mod
done
popd

printf "Please enter your cayenne credentials and your\n"
printf "device client ID (see https://cayenne.mydevices.com/)\n"
printf "  Cayenne username : "

read CAYENNE_USER
if [[ $CAYENNE_USER != "" ]]; then sed -i -- 's/__CAYENNE_USER__/'$CAYENNE_USER'/g' sensors.js; fi
printf "  Cayenne password : "
read CAYENNE_PASS
if [[ $CAYENNE_PASS != "" ]]; then sed -i -- 's/__CAYENNE_PASS__/'$CAYENNE_PASS'/g' sensors.js; fi
printf "  Cayenne clientID : "
read CAYENNE_CLID
if [[ $CAYENNE_CLID != "" ]]; then sed -i -- 's/__CAYENNE_CLID__/'$CAYENNE_CLID'/g' sensors.js; fi

# cp nodejs sensor script
cp -f ./sensors.js $INSTALL_DIR/

# cp startup script as a service
cp ./sensors-js.service /lib/systemd/system/

# Enable the service
systemctl enable sensors-js.service
systemctl start sensors-js.service

# wait service to read values
echo "Waiting service to start and connect..."
sleep 3

echo
echo "Installation completed.\n"
echo "use sudo systemctl status sensors-js to see service status"
echo "use sudo journalctl -f -u sensors-js to see service log"
echo -n
systemctl status sensors-js.service




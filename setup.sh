#! /bin/bash

GW_DIR="/opt/loragw"

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
    GW_RESET_PIN=22
    echo "No environement for GW_RESET_PIN"
    echo "Please select your reset pin"
    echo "see https://github.com/jpmeijers/ttn-resin-gateway-rpi/blob/master/README.md"
    echo "under section Reset Pin Values"
    echo "enter 25 (GPIO25) for classic Gonzalo Casas backplane or this RAK831 shield"
    echo "enter 17 (GPIO17) for classic ic880A by ch2i"
    echo ""
    echo -n "Please enter GW_RESET_PIN [$GW_RESET_PIN]:"
    read GW_RESET_PIN
    export GW_RESET_PIN
fi

# Set the reset în in startup shell
sed -i -- 's/PIN=25/PIN='"$GW_RESET_PIN"'/g' ./start.sh

# script to get config from TTN server
python set_config.py

# Copy config to running folder
sudo mv global_conf.json $GW_DIR/
sudo cp start.sh $GW_DIR/
#sudo cp off-button.py $GW_DIR/

# Adding off button management
#sudo sed -i -e '$i \\'"$GW_DIR"'/off-button.py &\n' /etc/rc.local

# Prepare start forwarder as systemd script
sudo cp ./loragw.service /lib/systemd/system/
sudo systemctl enable loragw.service
sudo systemctl start loragw.service

# Prepare monitor as systemd script
sudo cp ./monitor-ws2812.py $GW_DIR/
sudo cp ./monitor-gpio.py $GW_DIR/
sudo ln -s $GW_DIR/monitor-ws2812.py $GW_DIR/monitor.py
sudo cp ./monitor.service /lib/systemd/system/
sudo systemctl enable monitor.service
sudo systemctl start monitor.service


echo "all done, please check service running log with"
echo "sudo journalctl -f -u loragw.service"



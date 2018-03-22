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

# Set the reset în in startup shell
sudo sed -i -- "s/RESET_BCM_PIN=[0-9]+/RESET_BCM_PIN=$GW_RESET_PIN/g" ./start.sh

# script to get config from TTN server
python set_config.py

# Copy config to running folder
sudo mv global_conf.json $GW_DIR/
sudo cp start.sh $GW_DIR/

# Prepare start forwarder as systemd script
sudo cp ./loragw.service /lib/systemd/system/
sudo systemctl enable loragw.service
sudo systemctl start loragw.service

# ask if we need to enable monitoring service
sudo cp ./oled.py $GW_DIR/
sudo cp ./monitor-ws2812.py $GW_DIR/
sudo cp ./monitor-gpio.py $GW_DIR/
sudo ln -s $GW_DIR/monitor-ws2812.py $GW_DIR/monitor.py
sudo cp ./monitor.service /lib/systemd/system/
sudo cp ./oled.service /lib/systemd/system/

echo ""
echo "You can enable monitor service that manage blinking led to"
echo "display status and also add button management to shutdown PI"
echo -n "Would you like to enable this [y/N]:"
read rep

if [[ "$rep" == "y" ]]; then
  sudo systemctl enable monitor.service
  sudo systemctl start monitor.service
  echo "monitor service enabled!"
fi

echo ""
echo "You can enable OLED display service to show informations"
echo -n "Would you like to enable this [y/N]:"
read rep

if [[ "$rep" == "y" ]]; then
  sudo systemctl enable oled.service
  sudo systemctl start oled.service
  echo "Oled service enabled!"
  echo "Please follow the procedure located here to finish setup"
  echo "https://github.com/ch2i/LoraGW-Setup/blob/master/doc/DisplayOled.md"
  echo "Also don't forget to set the OLED wiring and type by editing file"
  echo "/opt/loragw/oled.py (as described into procedure)"
fi

echo ""
echo "all done, please check service running log with"
echo "sudo journalctl -f -u loragw.service"



#! /bin/bash

# Test the connection, wait if needed.
#while [[ $(ping -c1 google.com 2>&1 | grep " 0% packet loss") == "" ]]; do
#  echo "[Lora Gateway]: Waiting for internet connection..."
#  sleep 2
#  done

# Reset RAK831 PIN
SX1301_RESET_BCM_PIN=25

WAIT_GPIO() {
    sleep 0.1
}

# cleanup GPIO
if [ -d /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN ]
then
  echo "GPIO$SX1301_RESET_BCM_PIN Already available"
else
  echo "$SX1301_RESET_BCM_PIN" > /sys/class/gpio/export; WAIT_GPIO
fi

# setup GPIO
echo "out" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction
WAIT_GPIO
echo "1" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
WAIT_GPIO
echo "0" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
WAIT_GPIO

# removed, prevent start on IMST Gateway Lite
#echo "in" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction

# Fire up the forwarder.
./mp_pkt_fwd

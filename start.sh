#! /bin/bash

# Reset RAK831 PIN
SX1301_RESET_BCM_PIN=25

WAIT_GPIO() {
    sleep 0.1
}

# cleanup GPIO
if [ -d /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN ]
then
  echo "$SX1301_RESET_BCM_PIN" > /sys/class/gpio/unexport; WAIT_GPIO
fi

# setup GPIO
echo "$SX1301_RESET_BCM_PIN" > /sys/class/gpio/export; WAIT_GPIO
echo "out" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction; WAIT_GPIO
echo "1" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value; WAIT_GPIO
echo "0" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value; WAIT_GPIO
echo "in" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction; WAIT_GPIO

# Fire up the forwarder.
./mp_pkt_fwd

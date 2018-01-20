#! /bin/bash

# Reset RAK831 PIN
SX1301_RESET_BCM_PIN=17

echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 0.1
echo "1"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 0.1
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 0.1
echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/unexport


# Test the connection, wait if needed.
#while [[ $(ping -c1 google.com 2>&1 | grep " 0% packet loss") == "" ]]; do
#  echo "[TTN Gateway]: Waiting for internet connection..."
#  sleep 30
#  done

# Fire up the forwarder.  
./poly_pkt_fwd


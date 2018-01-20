#! /bin/bash

# Reset SX1301 concentrator
GW_RESET_PIN=22

echo "[SX1301 Gateway]: Toggling reset pin $GW_RESET_PIN"
gpio -1 mode $GW_RESET_PIN out
gpio -1 write $GW_RESET_PIN 0
sleep 0.1
gpio -1 write $GW_RESET_PIN 1
sleep 0.1
gpio -1 write $GW_RESET_PIN 0
sleep 0.1


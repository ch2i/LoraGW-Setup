#!/usr/bin/python

# **********************************************************************************
# monitor-ws2812.py
# **********************************************************************************
# Script for monitoring LoraWAN Gateways based on small Linux computers
# it's lighing some WS2812 LEDs depending on status and process
# it's also monitoring a push button to do a clean shutdown
#
# Written by Charles-Henri Hallard http://ch2i.eu
#
# History : V1.00 2017-12-22 - Creation
#
# All text above must be included in any redistribution.
#
# **********************************************************************************

import RPi.GPIO as GPIO
import thread
import time
import os
import urllib
from neopixel import *
import sys
import signal
import subprocess

# Switch push button
gpio_pin = 17
gpio_led = 18

internet = False
localnet = False
lorawan  = False
web      = False

hostapd  = False
pktfwd   = False

color_off = Color(0,0,0)
color_red = Color(128,0,0)
color_grn = Color(0,128,0)
color_blu = Color(0,0,128)
color_yel = Color(128,128,0)

def signal_handler(signal, frame):
    colorSet(strip, 0, color_off )
    colorSet(strip, 1, color_off )
    sys.exit(0)


def check_process(process):
  proc = subprocess.Popen(["if pgrep " + process + " >/dev/null 2>&1; then echo '1'; else echo '0'; fi"], stdout=subprocess.PIPE, shell=True)
  (ret, err) = proc.communicate()
  ret = int(ret)
  #print ret
  if ret==1:
    return True
  else:
    return False

def check_inet(delay):
  global internet
  global localnet
  global lorawan
  global web
  global hostapd
  global pktfwd

  while True:
    #print "check Internet"
    try:
      url = "https://www.google.com"
      urllib.urlopen(url)
      internet = True
    except:
      internet = False

    try:
      url = "http://127.0.0.1"
      urllib.urlopen(url)
      web = True
    except:
      web = False

    try:
      url = "http://127.0.0.1:8080"
      urllib.urlopen(url)
      lorawan = True
    except:
      lorawan = False

    hostapd = check_process("hostapd")
    pktfwd = check_process("mp_pkt_fwd")

    time.sleep(delay)


# Use the Broadcom SOC Pin numbers
# Setup the Pin with Internal pullups enabled and PIN in reading mode.
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(gpio_pin, GPIO.IN, pull_up_down = GPIO.PUD_DOWN)


# Define functions which animate LEDs in various ways.
def colorSet(strip, led, color):
      strip.setPixelColor(led, color)
      strip.show()

# Our function on what to do when the button is pressed
def checkShutdown():
    if GPIO.input(gpio_pin) == 1:
      colorSet(strip, 0, color_red)
      colorSet(strip, 1, color_off)
      time.sleep(.9)
      if GPIO.input(gpio_pin) == 1:
        colorSet(strip, 1, color_red)
        time.sleep(.9)
        if GPIO.input(gpio_pin) == 1:
          for x in range(0, 10):
            colorSet(strip, 0, color_blu)
            colorSet(strip, 1, color_blu)
            time.sleep(.2)
            colorSet(strip, 0, color_off)
            colorSet(strip, 1, color_off)
            time.sleep(.4)
          print "shutdown"
          os.system("sudo halt &")
          time.sleep(30)

signal.signal(signal.SIGINT, signal_handler)

# Create NeoPixel object 2 LEDs, 64 Brighness GRB leds
strip = Adafruit_NeoPixel(2, gpio_led, 800000, 5, False, 64, 0, ws.WS2811_STRIP_GRB)

# Intialize the library (must be called once before other functions).
strip.begin()

try:
   thread.start_new_thread( check_inet, (5, ) )
except:
   print "Error: unable to start thread"

# Now wait!
while 1:
    led0 = color_red
    led1 = color_red

    if internet == True:
      led0 = color_grn
    else:
      if hostapd == True:
        led0 = color_blu

#    if web == True and lorawan == True:
    if pktfwd == True :
      led1 = color_grn
    else:
      led1 = color_red

    colorSet(strip, 0, led0)
    time.sleep(.2)
    checkShutdown();
    colorSet(strip, 0, color_off)
    time.sleep(.8)
    checkShutdown();

    colorSet(strip, 1, led1)
    time.sleep(.2)
    checkShutdown();
    colorSet(strip, 1, color_off)
    time.sleep(.8)
    checkShutdown();

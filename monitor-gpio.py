#!/usr/bin/python
# **********************************************************************************
# monitor-gpio.py
# **********************************************************************************
# Script for monitoring LoraWAN Gateways based on small Linux computers
# it's lighing some LEDs depending on status and process
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

gpio_blu = 4
gpio_yel = 18
gpio_red = 23
gpio_grn = 24

internet = False
localnet = False
lorawan  = False
web      = False
hostapd  = False

def signal_handler(signal, frame):
    GPIO.output(gpio_blu, GPIO.LOW)
    GPIO.output(gpio_yel, GPIO.LOW)
    GPIO.output(gpio_red, GPIO.LOW)
    GPIO.output(gpio_grn, GPIO.LOW)
    sys.exit(0)


def check_process(process):
  proc = subprocess.Popen(["if pgrep " + process + " >/dev/null 2>&1; then echo '1'; else echo '0'; fi"], stdout=subprocess.PIPE, shell=True)
  (ret, err) = proc.communicate()
  ret = int(ret)
  print ret
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

    time.sleep(delay)


# Use the Broadcom SOC Pin numbers
# Setup the Pin with Internal pullups enabled and PIN in reading mode.
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(gpio_pin, GPIO.IN, pull_up_down = GPIO.PUD_DOWN)
GPIO.setup(gpio_blu, GPIO.OUT)
GPIO.setup(gpio_yel, GPIO.OUT)
GPIO.setup(gpio_red, GPIO.OUT)
GPIO.setup(gpio_grn, GPIO.OUT)


# Our function on what to do when the button is pressed
def checkShutdown():
    if GPIO.input(gpio_pin) == 1:

      GPIO.output(gpio_blu, GPIO.LOW)
      GPIO.output(gpio_yel, GPIO.LOW)
      GPIO.output(gpio_red, GPIO.LOW)
      GPIO.output(gpio_grn, GPIO.LOW)

      time.sleep(.9)
      if GPIO.input(gpio_pin) == 1:
        GPIO.output(gpio_blu, GPIO.HIGH)
        time.sleep(.9)
        if GPIO.input(gpio_pin) == 1:
          GPIO.output(gpio_yel, GPIO.HIGH)
          time.sleep(.9)
          if GPIO.input(gpio_pin) == 1:
            GPIO.output(gpio_red, GPIO.HIGH)
            time.sleep(.9)
            if GPIO.input(gpio_pin) == 1:
                for x in range(0, 10):
                  GPIO.output(gpio_blu, GPIO.HIGH)
                  GPIO.output(gpio_yel, GPIO.HIGH)
                  GPIO.output(gpio_red, GPIO.HIGH)
                  GPIO.output(gpio_grn, GPIO.HIGH)
                  time.sleep(.2)
                  GPIO.output(gpio_blu, GPIO.LOW)
                  GPIO.output(gpio_yel, GPIO.LOW)
                  GPIO.output(gpio_red, GPIO.LOW)
                  GPIO.output(gpio_grn, GPIO.LOW)
                  time.sleep(.4)
            print "shutdown"
            #os.system("sudo halt &")
            time.sleep(30)

signal.signal(signal.SIGINT, signal_handler)

try:
   thread.start_new_thread( check_inet, (5, ) )
except:
   print "Error: unable to start thread"

# Now wait!
while 1:
    led_blu = GPIO.LOW
    led_yel = GPIO.LOW
    led_red = GPIO.LOW
    led_grn = GPIO.LOW

    if hostapd == True:
      led_blu = GPIO.HIGH
    else:
      led_red = GPIO.HIGH

    if web == True:
      led_yel = GPIO.HIGH
    else:
      led_red = GPIO.HIGH

    if lorawan == True:
      led_grn = GPIO.HIGH
    else:
      led_red = GPIO.HIGH

    GPIO.output(gpio_blu, led_blu)
    time.sleep(.2)
    checkShutdown();
    GPIO.output(gpio_blu, GPIO.LOW)
    time.sleep(.8)
    checkShutdown();

    GPIO.output(gpio_yel, led_yel)
    time.sleep(.2)
    checkShutdown();
    GPIO.output(gpio_yel, GPIO.LOW)
    time.sleep(.8)
    checkShutdown();

    GPIO.output(gpio_grn, led_grn)
    time.sleep(.2)
    checkShutdown();
    GPIO.output(gpio_grn, GPIO.LOW)
    time.sleep(.8)
    checkShutdown();



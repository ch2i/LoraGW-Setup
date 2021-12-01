#!/usr/bin/python
# **********************************************************************************
# monitor-gpio-helium.py
# **********************************************************************************
# Script for monitoring LoraWAN Gateways based on small Linux computers
# it's lighing some LEDs depending on status and process
# it's also monitoring a push button to do a clean shutdown
# this one monitor also status of helium gateway service
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
import sys
import signal
import subprocess
import select
from systemd import journal

gpio_blu = 4
gpio_yel = 18
gpio_red = 23
gpio_grn = 24

internet = False # True if internet connected
pktfwd   = False # True if packet forwarder is started
helium   = False # True if helium_gateway is running

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
#  print ret
  if ret==1:
    return True
  else:
    return False

def check_inet(delay):
  global internet
  global pktfwd
  global helium

  while True:
    #print "check Internet"
    try:
      url = "https://www.google.com"
      urllib.urlopen(url)
      internet = True
    except:
      internet = False

    # Check packet forwarder
    pktfwd = check_process("mp_pkt_fwd") or check_process("poly_pkt_fwd") or check_process("lora_pkt_fwd")
    # Check helium gateway
    helium = check_process("helium_gateway")

    time.sleep(delay)

def check_packet(pool_delay):

    # Create a systemd.journal.Reader instance
    j = journal.Reader()
    # Set the reader's default log level
    j.log_level(journal.LOG_INFO)
    # Filter log entries
    j.add_match(_SYSTEMD_UNIT="helium_gateway.service", SYSLOG_IDENTIFIER="helium_gateway")
    j.seek_tail()
    j.get_previous()
    p = select.poll()
    # Register the journal's file descriptor with the polling object.
    journal_fd = j.fileno()
    poll_event_mask = j.get_events()
    p.register(journal_fd, poll_event_mask)

    # Poll for new journal entries every 250ms
    while True:
      if p.poll(pool_delay):
        if j.process() == journal.APPEND:
          for entry in j:
             try:
               # message starts with what we call packet
               msg = str(entry['MESSAGE'])
               if msg.startswith(('uplink','downlink','join')):
                   GPIO.output(gpio_grn, GPIO.HIGH)
                   time.sleep(.3)
             except:
               pass
      GPIO.output(gpio_grn, GPIO.LOW)

# Use the Broadcom SOC Pin numbers
# Setup the Pin with Internal pullups enabled and PIN in reading mode.
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(gpio_blu, GPIO.OUT)
GPIO.setup(gpio_yel, GPIO.OUT)
GPIO.setup(gpio_red, GPIO.OUT)
GPIO.setup(gpio_grn, GPIO.OUT)

signal.signal(signal.SIGINT, signal_handler)

try:
   thread.start_new_thread( check_inet, (5, ) )
except:
   print "Error: unable to start check_inet thread"

try:
   thread.start_new_thread( check_packet, (250, ) )
except:
   print "Error: unable to start check_packet thread"

# Now wait!
while True:
    # Light off all LEDS
    led_blu = GPIO.LOW
    led_yel = GPIO.LOW
    led_red = GPIO.LOW

    # Blue Internet OK else light RED
    if internet == True:
      led_blu = GPIO.HIGH
    else:
      led_red = GPIO.HIGH

    # Yellow forwarders OK else light RED
    if pktfwd == True and helium == True:
      led_yel = GPIO.HIGH
    else:
      led_red = GPIO.HIGH

    # Blink Blue (Internet)
    GPIO.output(gpio_blu, led_blu)
    time.sleep(.2)
    GPIO.output(gpio_blu, GPIO.LOW)
    time.sleep(.8)

    # Blink Yellow (Forwarders)
    GPIO.output(gpio_yel, led_yel)
    time.sleep(.2)
    GPIO.output(gpio_yel, GPIO.LOW)
    time.sleep(.8)



#!/usr/bin/env python

import os
import psutil
import platform
import thread
import socket
import SocketServer
import json
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from luma.oled.device import sh1106
from PIL import ImageFont
import time
from datetime import datetime

width=128
height=64

font_pixel=12
line1=0
line2=line1+12
line3=line2+12
line4=line3+12
line5=line4+12
col1=0
lora_rssi = None
lora_chan = None
lora_freq = None
lora_datr = None
lora_mote = None

class LeaseEntry:
  def __init__(self, leasetime, macAddress, ipAddress, name):
    if (leasetime == '0'):
      self.staticIP = True
    else:
      self.staticIP = False
    self.leasetime = datetime.fromtimestamp(int(leasetime)).strftime('%Y-%m-%d %H:%M:%S')
    self.macAddress = macAddress.upper()
    self.ipAddress = ipAddress
    self.name = name

  def serialize(self):
    return {
      'staticIP': self.staticIP,
      'leasetime': self.leasetime,
      'macAddress': self.macAddress,
      'ipAddress': self.ipAddress,
      'name': self.name
    }


class MyUDPHandler(SocketServer.BaseRequestHandler):

  def is_json(self, myjson):
    try:
      json_object = json.loads(myjson)
    except ValueError, e:
      return False
    return True

  def handle(self):
    json_data
    global lora_rssi
    global lora_chan
    global lora_freq
    global lora_datr
    global lora_mote

    data = self.request[0]
    # for poly_pkt_fwd remove 12 first bytes
    # if mp_pkt_fwd then packet are already fine
    if data.find("{\"rxpk\":[") > 0:
      data = data[12::]

    if self.is_json(data):
        #print("\r\n")
        #print(data)
        js_data = json.loads(data)

        # for mp_pkt_fwd
        if js_data.get('type')=='uplink':
            lora_mote = js_data["mote"]
            lora_rssi = js_data["rssi"]
            lora_chan = js_data["chan"]
            lora_freq = js_data["freq"]
            lora_datr = js_data["datr"]
        # for poly_pkt_fwd
        elif js_data.get('rxpk'):
            lora_mote = "legacy_fwd"
            lora_rssi = js_data["rxpk"][0]["rssi"]
            lora_chan = js_data["rxpk"][0]["chan"]
            lora_freq = js_data["rxpk"][0]["freq"]
            lora_datr = js_data["rxpk"][0]["datr"]
            
def leaseSort(arg):
  # Fixed IPs first
  if arg.staticIP == True:
    return 0
  else:
    return arg.name.lower()

def getLeases():
  leases = list()
  try:
    with open("/var/lib/misc/dnsmasq.leases") as f:
      for line in f:
        elements = line.split()
        if len(elements) == 5:
          entry = LeaseEntry(elements[0],elements[1],elements[2],elements[3])
          leases.append(entry)

    leases.sort(key = leaseSort)
    return [lease.serialize() for lease in leases]

  except Exception as e:
    print "error in getLeases"
    print(e)
    print(type(e))            
    return None
            

def do_nothing(obj):
  pass

def make_font(name, size):
  font_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'fonts', name))
  return ImageFont.truetype(font_path, size)

# rev.1 users set port=0
# substitute spi(device=0, port=0) below if using that interface
serial = i2c(port=1, address=0x3c)
device = sh1106(serial)
#device = ssd1306(serial)
device.cleanup = do_nothing

font10 = make_font("/usr/share/fonts/truetype/luma/ProggyTiny.ttf", 16)
byteunits = ('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')

def udp_receive(delay):
  server = SocketServer.UDPServer(("127.0.0.1", 1688), MyUDPHandler)
  server.serve_forever()
  #server.handle_request()

def filesizeformat(value):
  exponent = int(log(value, 1024))
  return "%.1f %s" % (float(value) / pow(1024, exponent), byteunits[exponent])

def bytes2human(n):
  symbols = ('K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y')
  prefix = {}
  for i, s in enumerate(symbols):
    prefix[s] = 1 << (i + 1) * 10
  for s in reversed(symbols):
    if n >= prefix[s]:
      value = int(float(n) / prefix[s])
      return '%s%s' % (value, s)
  return "%sB" % n

def if_stat(iface):
  try:
    stat = psutil.net_io_counters(pernic=True)[iface]
    return "Tx %s   Rx %s" % (bytes2human(stat.bytes_sent), bytes2human(stat.bytes_recv))

  except KeyError as e:
    return "Tx %s   Rx %s" % (bytes2human(0), bytes2human(0))

def lan_info(iface):
  ip = "No Interface"
  stat = ""
  try:
    for snic in psutil.net_if_addrs()[iface]:
      if snic.family == socket.AF_INET:
        ip = snic.address
        stat = if_stat(iface)
        break
      else:
        ip ="No IP"

    return "%-5s: %s" % (iface, ip), stat

  except KeyError as e:
    return ip, stat


def uptime():
  try:
    f = open( "/proc/uptime" )
    contents = f.read().split()
    f.close()
  except:
    return "no /proc/uptime"

  total_seconds = float(contents[0])

  # Helper vars:
  MINUTE  = 60
  HOUR    = MINUTE * 60
  DAY     = HOUR * 24

  # Get the days, hours, etc:
  days    = int( total_seconds / DAY )
  hours   = int( ( total_seconds % DAY ) / HOUR )
  minutes = int( ( total_seconds % HOUR ) / MINUTE )
  seconds = int( total_seconds % MINUTE )

  # Build up the pretty string (like this: "N days, N hours, N minutes, N seconds")
  string = ""
  if days > 0:
    string += str(days) + "d "
  if len(string) > 0 or hours > 0:
    string += str(hours) + "h "
  if len(string) > 0 or minutes > 0:
    string += str(minutes) + "m "
  if hours == 0 and seconds >0:
    string += str(seconds) + "s" 

  return string;

def ip_client(thislease):
  ips = thislease["ipAddress"].split('.')
  return "%s.%s: %s" % (ips[2],ips[3], thislease["name"])

def stats():
  global looper
  lease = None
  with canvas(device) as draw:
    #draw.rectangle((0,0,127,63), outline="white", fill="black")
    if looper==0:
      looper=1
      if lora_mote != None:
          draw.text((col1, line1),"Mote %s" % lora_mote, font=font10, fill=255)
          draw.text((col1, line2),"RSSI %sdBm" % lora_rssi, font=font10, fill=255)
          draw.text((col1, line3),"Chan %s" % lora_chan, font=font10, fill=255)
          draw.text((col1, line4),"Freq %.2f MHz" % lora_freq, font=font10, fill=255)
          draw.text((col1, line5),"Rate %s" % lora_datr, font=font10, fill=255)
      else:
        draw.text((col1, line1),"No LoRaWAN Data yet", font=font10, fill=255)

    elif looper==1:
      looper = 2
      draw.text((col1, line1),"Host :%s" % socket.gethostname(), font=font10, fill=255)
      # Try to get wlan0 if not then eth0
      ip, stats = lan_info("eth0")
      if ip == "No Interface":
        ip, stats = lan_info("wlan0")
        
      draw.text((col1, line2), ip,  font=font10, fill=255)
      draw.text((col1, line3), stats,  font=font10, fill=255)

      ip, stats = lan_info("ap0")
      if ip != "No IP" and ip != "No Interface":
        draw.text((col1, line4), ip,  font=font10, fill=255)
        draw.text((col1, line5), stats,  font=font10, fill=255)
        lease = getLeases()
      else:
        draw.text((col1, line4), "ap0",  font=font10, fill=255)
        draw.text((col1, line5), "No Access Point",  font=font10, fill=255)

      if lease == None:
        looper = 3 
    elif looper==2:
      looper = 3 
      lease = getLeases()
      lg = len(lease)

      draw.text((col1, line1), "Wifi Clients => %d" % lg, font=font10, fill=255)
      if lg>=1: draw.text((col1, line2), ip_client(lease[0]), font=font10, fill=255)
      if lg>=2: draw.text((col1, line3), ip_client(lease[1]), font=font10, fill=255)
      if lg>=3: draw.text((col1, line4), ip_client(lease[2]), font=font10, fill=255)
      if lg>=4: draw.text((col1, line5), ip_client(lease[3]), font=font10, fill=255)

    elif looper==3:
      looper = 0
      tempC = int(open('/sys/class/thermal/thermal_zone0/temp').read())
      av1, av2, av3 = os.getloadavg()
      mem = psutil.virtual_memory()
      dsk = psutil.disk_usage("/")

      draw.text((col1, line1), "CPU LOAD: %.1f  %.1f" % (av1, av3),  font=font10, fill=255)
      draw.text((col1, line2), "MEM FREE: %s/%s" % (bytes2human(mem.available), bytes2human(mem.total)), font=font10, fill=255)
      draw.text((col1, line3), "DSK FREE: %s/%s" % (bytes2human(dsk.total-dsk.used), bytes2human(dsk.total)),font=font10, fill=255)
      draw.text((col1, line4), "CPU TEMP: %sc" % (str(tempC/1000)), font=font10, fill=255)
      draw.text((col1, line5), "UP : %s" % uptime(), font=font10, fill=255)

    else:
      #draw.text((col1, line1),"%s %s" % (platform.system(),platform.release()), font=font10, fill=255)
      #uptime = datetime.now() - datetime.fromtimestamp(psutil.boot_time())
      #draw.text((col1, line2),str(datetime.now().strftime('%a %b %d %H:%M:%S')), font=font10, fill=255)
      #draw.text((col1, line3),"Uptime %s" % str(uptime).split('.')[0], font=font10, fill=255)
      looper=0

def main():
  global looper
  global json_data
  looper = 1
  json_data = None

  try:
    thread.start_new_thread( udp_receive, (5, ) )
  except:
    print "Error: unable to start thread"

  while True:
    stats()
    if looper==0:
      time.sleep(2)
    else:
      time.sleep(5)

if __name__ == "__main__":
  try:
    main()
  except KeyboardInterrupt:
    pass

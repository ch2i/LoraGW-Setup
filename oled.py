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

class MyUDPHandler(SocketServer.BaseRequestHandler):

  def handle(self):
    global json_data
    data = self.request[0]
    #print(self.request)
    data = data[12::]
    #print(data)
    js_data = json.loads(data)

    if js_data.get('rxpk'):
      json_data = data

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

def network(iface):
  stat = psutil.net_io_counters(pernic=True)[iface]
  return "Tx %s   Rx %s" % (bytes2human(stat.bytes_sent), bytes2human(stat.bytes_recv))

def lan_ip(iface):
  for nic, addrs in psutil.net_if_addrs().items():
    if nic == iface:
      for addr in addrs:
        if addr.family==socket.AF_INET:
          return "%-5s: %s" % (iface, addr.address)

  return "%-5s: Unknown IP" % iface

def stats():
  global looper
  with canvas(device) as draw:
    #draw.rectangle((0,0,127,63), outline="white", fill="black")
    if looper==0:
      if json_data!=None:
        try:
          o = json.loads(json_data)
          draw.text((col1, line1),"RSSI %sdBi" % (o["rxpk"][0]["rssi"]), font=font10, fill=255)
          draw.text((col1, line2),"Chan %s" % (o["rxpk"][0]["chan"]), font=font10, fill=255)
          draw.text((col1, line3),"Freq %.2f MHz" % (o["rxpk"][0]["freq"]), font=font10, fill=255)
          draw.text((col1, line4),"Rate %s" % (o["rxpk"][0]["datr"]), font=font10, fill=255)
        except:
          draw.text((col1, line1),"Invalid JSON received", font=font10, fill=255)
          pass
      else:
        draw.text((col1, line1),"No LoraWAN Data yet", font=font10, fill=255)

      looper=1
    elif looper==1:
      draw.text((col1, line1),"Host :%s" % socket.gethostname(), font=font10, fill=255)
      draw.text((col1, line2), lan_ip("wlan0"),  font=font10, fill=255)
      draw.text((col1, line3), network("wlan0"),  font=font10, fill=255)
      draw.text((col1, line4), lan_ip("uap0"),  font=font10, fill=255)
      draw.text((col1, line5), network("uap0"),  font=font10, fill=255)
      looper=2
    elif looper==2:
      tempC = int(open('/sys/class/thermal/thermal_zone0/temp').read())
      av1, av2, av3 = os.getloadavg()
      mem = psutil.virtual_memory()
      dsk = psutil.disk_usage("/")

      draw.text((col1, line1), "CPU LOAD: %.1f  %.1f" % (av1, av3),  font=font10, fill=255)
      draw.text((col1, line2), "MEM FREE: %s/%s" % (bytes2human(mem.available), bytes2human(mem.total)), font=font10, fill=255)
      draw.text((col1, line3), "DSK FREE: %s/%s" % (bytes2human(dsk.total-dsk.used), bytes2human(dsk.total)),font=font10, fill=255)
      draw.text((col1, line4), "CPU TEMP: %sc" % (str(tempC/1000)), font=font10, fill=255)
      looper=3
    else:
      draw.text((col1, line1),"%s %s" % (platform.system(),platform.release()), font=font10, fill=255)
      uptime = datetime.now() - datetime.fromtimestamp(psutil.boot_time())
      draw.text((col1, line2),str(datetime.now().strftime('%a %b %d %H:%M:%S')), font=font10, fill=255)
      draw.text((col1, line3),"Uptime %s" % str(uptime).split('.')[0], font=font10, fill=255)
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

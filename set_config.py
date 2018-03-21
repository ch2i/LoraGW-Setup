#!/usr/bin/python
"""
Author: JP Meijers
Date: 2017-02-26
Based on: https://github.com/rayozzie/ttn-resin-gateway-rpi/blob/master/run.sh
"""
import os
import os.path
import sys
import urllib2
import time
import uuid
import json
import subprocess
try:
  import urlparse
except:
  import urllib.parse as urlparse
try:
  import RPi.GPIO as GPIO
except RuntimeError:
  print("Error importing RPi.GPIO!  This is probably because you need superuser privileges.  You can achieve this by using 'sudo' to run your script")

GWID_PREFIX="FFFE"

if os.environ.get('HALT') != None:
  print ("*** HALT asserted - exiting ***")
  sys.exit(0)

# Check if the correct environment variables are set

print ("*******************")
print ("*** Configuration:")
print ("*******************")

if os.environ.get("GW_EUI")==None:
  # The FFFE should be inserted in the middle (so xxxxxxFFFExxxxxx)
  my_eui = format(uuid.getnode(), '012x')
  my_eui = my_eui[:6]+GWID_PREFIX+my_eui[6:]
  my_eui = my_eui.upper()
else:
  my_eui = os.environ.get("GW_EUI")


# Define default configs
description = os.getenv('GW_DESCRIPTION', "")
placement = ""
latitude = os.getenv('GW_REF_LATITUDE', 0)
longitude = os.getenv('GW_REF_LONGITUDE', 0)
altitude = os.getenv('GW_REF_ALTITUDE', 0)
frequency_plan_url = os.getenv('FREQ_PLAN_URL', "https://account.thethingsnetwork.org/api/v2/frequency-plans/EU_863_870")

# Fetch config from TTN if TTN is enabled
if(os.getenv('SERVER_TTN', "true")=="true"):

  if os.environ.get("GW_ID")==None:
    print ("ERROR: GW_ID required")
    print ("See https://www.thethingsnetwork.org/docs/gateways/registration.html#via-gateway-connector")
    sys.exit(0)

  if os.environ.get("GW_KEY")==None:
    print ("ERROR: GW_KEY required")
    print ("See https://www.thethingsnetwork.org/docs/gateways/registration.html#via-gateway-connector")
    sys.exit(0)

  print ("*******************")
  print ("*** Fetching config from TTN account server")
  print ("*******************")

  # Fetch the URL, if it fails try 30 seconds later again.
  config_response = ""
  try:
    req = urllib2.Request('https://account.thethingsnetwork.org/gateways/'+os.environ.get("GW_ID"))
    req.add_header('Authorization', 'Key '+os.environ.get("GW_KEY"))
    response = urllib2.urlopen(req, timeout=30)
    config_response = response.read()
  except urllib2.URLError as err: 
    print ("Unable to fetch configuration from TTN. Are your GW_ID and GW_KEY correct?")
    sys.exit(0)

  # Parse config
  ttn_config = {}
  try:
    ttn_config = json.loads(config_response)
  except:
    print ("Unable to parse configuration from TTN")
    sys.exit(0)

  frequency_plan = ttn_config.get('frequency_plan', "EU_863_870")
  frequency_plan_url = ttn_config.get('frequency_plan_url', "https://account.thethingsnetwork.org/api/v2/frequency-plans/EU_863_870")

  if "router" in ttn_config:
    router = ttn_config['router'].get('mqtt_address', "mqtt://router.dev.thethings.network:1883")
    router = urlparse.urlparse(router)
    router = router.hostname # mp_pkt_fwd only wants the hostname, not the protocol and port
  else:
    router = "router.dev.thethings.network"

  if "attributes" in ttn_config:
    description = ttn_config['attributes'].get('description', "")
    placement = ttn_config['attributes'].get('placement', "unknown")

  if "antenna_location" in ttn_config:
    latitude = ttn_config['antenna_location'].get('latitude', 0)
    longitude = ttn_config['antenna_location'].get('longitude', 0)
    altitude = ttn_config['antenna_location'].get('altitude', 0)

  fallback_routers = []
  if "fallback_routers" in ttn_config:
    for fb_router in ttn_config["fallback_routers"]:
      if "mqtt_address" in fb_router:
        fallback_routers.append(fb_router["mqtt_address"])


  print ("Gateway ID:\t"+os.environ.get("GW_ID"))
  print ("Gateway Key:\t"+os.environ.get("GW_KEY"))
  print ("Frequency plan:\t\t"+frequency_plan)
  print ("Frequency plan url:\t"+frequency_plan_url)
  print ("Gateway description:\t"+description)
  print ("Gateway placement:\t"+placement)
  print ("Router:\t\t\t"+router)
  print ("")
  print ("Fallback routers:")
  for fb_router in fallback_routers:
    print ("\t"+fb_router)
# Done fetching config from TTN
else:
  print ("TTN gateway connector disabled. Not fetching config from account server.")

print ("Latitude:\t\t"+str(latitude))
print ("Longitude:\t\t"+str(longitude))
print ("Altitude:\t\t"+str(altitude))
print ("Gateway EUI:\t"+my_eui)
print ("Has hardware GPS:\t"+str(os.getenv('GW_GPS', False)))
print ("Hardware GPS port:\t"+os.getenv('GW_GPS_PORT', "/dev/ttyAMA0"))



# Retrieve global_conf
sx1301_conf = {}
try:
  response = urllib2.urlopen(frequency_plan_url, timeout=30)
  global_conf = response.read()
  global_conf_object = json.loads(global_conf)
  if('SX1301_conf' in global_conf_object):
    sx1301_conf = global_conf_object['SX1301_conf']
except urllib2.URLError as err: 
  print ("Unable to fetch global conf from Github")
  sys.exit(0)

sx1301_conf['antenna_gain'] = float(os.getenv('GW_ANTENNA_GAIN', 0))


# Build local_conf
gateway_conf = {}
gateway_conf['gateway_ID'] = my_eui
gateway_conf['contact_email'] = os.getenv('GW_CONTACT_EMAIL', "")
gateway_conf['description'] = description

if(os.getenv('GW_FWD_CRC_ERR', "false")=="true"):
  #default is False
  gateway_conf['forward_crc_error'] = True

if(os.getenv('GW_FWD_CRC_VAL', "true")=="false"):
  #default is True
  gateway_conf['forward_crc_valid'] = False

# Parse GW_GPS env var. It is a string, we need a boolean.
if(os.getenv('GW_GPS', "false")=="true"):
  gw_gps = True
else:
  gw_gps = False

# Use hardware GPS
if(gw_gps):
  print ("Using real GPS")
  gateway_conf['gps'] = True
  gateway_conf['fake_gps'] = False
  gateway_conf['gps_tty_path'] = os.getenv('GW_GPS_PORT', "/dev/ttyAMA0")
# Use fake GPS with coordinates from TTN
elif(gw_gps==False and latitude!=0 and longitude!=0):
  print ("Using fake GPS")
  gateway_conf['gps'] = True
  gateway_conf['fake_gps'] = True
  gateway_conf['ref_latitude'] = float(latitude)
  gateway_conf['ref_longitude'] = float(longitude)
  gateway_conf['ref_altitude'] = float(altitude)
# No GPS coordinates
else:
  print ("Not sending coordinates")
  gateway_conf['gps'] = False
  gateway_conf['fake_gps'] = False


# Add server configuration
gateway_conf['servers'] = []

# Add TTN server
if(os.getenv('SERVER_TTN', "true")=="true"):
  server = {}
  server['serv_type'] = "ttn"
  server['server_address'] = router
  server['server_fallbacks'] = fallback_routers
  server['serv_gw_id'] = os.environ.get("GW_ID")
  server['serv_gw_key'] = os.environ.get("GW_KEY")
  server['serv_enabled'] = True
  gateway_conf['servers'].append(server)
else:
  if(os.getenv('SERVER_0_ENABLED', "false")=="true"):
    server = {}
    if(os.getenv('SERVER_0_TYPE', "semtech")=="ttn"):
      server['serv_type'] = "ttn"
      server['serv_gw_id'] = os.environ.get("SERVER_0_GWID")
      server['serv_gw_key'] = os.environ.get("SERVER_0_GWKEY")
    server['server_address'] = os.environ.get("SERVER_0_ADDRESS")
    server['serv_port_up'] = int(os.getenv("SERVER_0_PORTUP", 1700))
    server['serv_port_down'] = int(os.getenv("SERVER_0_PORTDOWN", 1700))
    server['serv_enabled'] = True
    if(os.getenv('SERVER_0_DOWNLINK', "false")=="true"):
      server['serv_down_enabled'] = True
    else:
      server['serv_down_enabled'] = False
    gateway_conf['servers'].append(server)

# Add up to 3 additional servers
if(os.getenv('SERVER_1_ENABLED', "false")=="true"):
  server = {}
  if(os.getenv('SERVER_1_TYPE', "semtech")=="ttn"):
    server['serv_type'] = "ttn"
    server['serv_gw_id'] = os.environ.get("SERVER_1_GWID")
    server['serv_gw_key'] = os.environ.get("SERVER_1_GWKEY")
  server['server_address'] = os.environ.get("SERVER_1_ADDRESS")
  server['serv_port_up'] = int(os.getenv("SERVER_1_PORTUP", 1700))
  server['serv_port_down'] = int(os.getenv("SERVER_1_PORTDOWN", 1700))
  server['serv_enabled'] = True
  if(os.getenv('SERVER_1_DOWNLINK', "false")=="true"):
    server['serv_down_enabled'] = True
  else:
    server['serv_down_enabled'] = False
  gateway_conf['servers'].append(server)

if(os.getenv('SERVER_2_ENABLED', "false")=="true"):
  server = {}
  if(os.getenv('SERVER_2_TYPE', "semtech")=="ttn"):
    server['serv_type'] = "ttn"
    server['serv_gw_id'] = os.environ.get("SERVER_2_GWID")
    server['serv_gw_key'] = os.environ.get("SERVER_2_GWKEY")
  server['server_address'] = os.environ.get("SERVER_2_ADDRESS")
  server['serv_port_up'] = int(os.getenv("SERVER_2_PORTUP", 1700))
  server['serv_port_down'] = int(os.getenv("SERVER_2_PORTDOWN", 1700))
  server['serv_enabled'] = True
  if(os.getenv('SERVER_2_DOWNLINK', "false")=="true"):
    server['serv_down_enabled'] = True
  else:
    server['serv_down_enabled'] = False
  gateway_conf['servers'].append(server)

if(os.getenv('SERVER_3_ENABLED', "false")=="true"):
  server = {}
  if(os.getenv('SERVER_3_TYPE', "semtech")=="ttn"):
    server['serv_type'] = "ttn"
    server['serv_gw_id'] = os.environ.get("SERVER_3_GWID")
    server['serv_gw_key'] = os.environ.get("SERVER_3_GWKEY")
  server['server_address'] = os.environ.get("SERVER_3_ADDRESS")
  server['serv_port_up'] = int(os.getenv("SERVER_3_PORTUP", 1700))
  server['serv_port_down'] = int(os.getenv("SERVER_3_PORTDOWN", 1700))
  server['serv_enabled'] = True
  if(os.getenv('SERVER_3_DOWNLINK', "false")=="true"):
    server['serv_down_enabled'] = True
  else:
    server['serv_down_enabled'] = False
  gateway_conf['servers'].append(server)


# Add GW Traff server
server = {}
server['serv_type'] = "gwtraf"
server['server_address'] = "127.0.0.1"
server['serv_port_up'] = 1688
server['serv_port_down'] = 1689
server['serv_enabled'] = True
gateway_conf['servers'].append(server)

# Add Local LoRaWAN server
server = {}
server['server_address'] = "127.0.0.1"
server['serv_port_up'] = 1680
server['serv_port_down'] = 1680
server['serv_enabled'] = False
gateway_conf['servers'].append(server)
 

# We merge the json objects from the global_conf and local_conf and save it to the global_conf.
# Therefore there will not be a local_conf.json file.
local_conf = {'SX1301_conf': sx1301_conf, 'gateway_conf': gateway_conf}
with open('global_conf.json', 'w') as the_file:
  the_file.write(json.dumps(local_conf, indent=4))


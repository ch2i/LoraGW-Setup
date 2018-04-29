# Promote Raspberry PI based gateway as a WiFi access point

 I found several method to got this working but despite my best efforts, I was unable to get any of those tutorials to work reliably on their own until I found this article. The procedure here works with Raspberry **PI Zero W and Debian Stretch**.

 It may work (or not) with other PI model or OS version.

I copied the procedure from [original article](https://albeec13.github.io/2017/09/26/raspberry-pi-zero-w-simultaneous-ap-and-managed-mode-wifi/) to have a backup in case and also to adapt to my needs.

Other solutions I tried with mitigated success on PI Zero is excellent [RaspAP-webgui](https://github.com/billz/raspap-webgui) to make access point. It may works perfecttly for RPI 3 but still issues with PI Zero.

# Pi Zero W with Raspbian Stretch Procedure

## Create new network interface for Access Point (ap0)

Create/edit the file `/etc/udev/rules.d/90-wireless.rules`, and add the following line.

```
ACTION=="add|change", SUBSYSTEM=="ieee80211", KERNEL=="phy0", RUN+="/sbin/iw phy %k interface add ap0 type __ap"
```


## Install the packages you need for DNS, Access Point and Firewall rules.
```
sudo apt-get install -y hostapd dnsmasq iptables-persistent
```

## Configure the DNS server

Edit the file `/etc/dnsmasq.conf` that should be like that, I kept the comments has a reminder to activate some features

```
interface=lo,ap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=192.168.50.50,192.168.50.100,12h

#dhcp-leasefile=/tmp/dnsmasq.leases
#address=/*.apple.com/192.168.50.1
#address=/*.icloud.com/192.168.50.1
#address=/#/192.168.50.1

###### logging ############
# own logfile
#log-facility=/var/log/dnsmasq.log
# log-async
# log dhcp infos
#log-dhcp
# debugging dns
```

After that my AP is distributing address from `192.168.50.50` to `192.168.50.100`

## Setup the Access Point configuration

### Edit the file `/etc/hostapd/hostapd.conf` that should be like that

```
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
interface=ap0
driver=nl80211
ssid=_AP_SSID_
hw_mode=g
channel=9
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=2
wpa_passphrase=_AP_PASSWORD_
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
country_code=FR
```

Replace `_AP_SSID_` with the SSID you want for your access point. Replace `_AP_PASSWORD_` with the password for your access point. Make sure it has enough characters to be a legal password! (8 characters minimum) else hostapd won't start.

Change also `country_code` to your own country

### Edit the file `/etc/default/hostapd` to enable service to start correctly

```
#DAEMON_OPTS=" -f /tmp/hostapd.log"
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

## Set up the client wifi (station) on wlan0.

Create or edit `/etc/wpa_supplicant/wpa_supplicant.conf`. The contents depend on whether your home network is open, WEP or WPA/2.  It is
probably WPA2, and so should look like:

```
    country=FR
    ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
    update_config=1    

    network={
      ssid="_ST_SSID_"
      psk="_ST_PASSWORD_"
      id_str="_MYAP_"
    }

```

Replace `_ST_SSID_` with your router SSID and `_ST_PASSWORD_` with your wifi password (in clear text). 
id_str is a name you'll need later, replace `_MYAP_` by the logical name you want.

Change also `country` to your own country


## Set up the network inferfaces

Edit the file  `/etc/network/interfaces`. Mine looks like that:

```
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
auto ap0
auto wlan0
iface lo inet loopback

allow-hotplug wlan0
iface wlan0 inet manual
    wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface _MYAP_ inet dhcp

allow-hotplug ap0
iface ap0 inet static
    address 192.168.50.1
    netmask 255.255.255.0
    hostapd /etc/hostapd/hostapd.conf
```

Replace `_MYAP_` with the logical name you put in the file `wpa_supplicant.conf`

## Set up boot order and/or workaround

Make sure do disable dhcpcd with 
```shell
sudo update-rc.d dhcpcd disable
```

Edit `/etc/rc.local` and add the following lines just before `# Print the IP Address`

```shell
ifdown --force wlan0 && ifdown --force ap0 && ifup ap0 && ifup wlan0
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.50.0/24 ! -d 192.168.50.0/24 -j MASQUERADE
systemctl restart dnsmasq
iwconfig wlan0 power off
```

## Optional, add AP display on OLED software

If you have enabled OLED, you may need to change the following line in `/opt/loragw/oled.py` according to the connected network interface you have to add the ap0 interface

Mine is wlan0 for WiFi and ap0 for WiFi [access point](https://github.com/ch2i/LoraGW-Setup/blob/master/doc/AccessPoint.md)
```python
draw.text((col1, line1),"Host :%s" % socket.gethostname(), font=font10, fill=255)
draw.text((col1, line2), lan_ip("wlan0"),  font=font10, fill=255)
draw.text((col1, line3), network("wlan0"),  font=font10, fill=255)
draw.text((col1, line4), lan_ip("uap0"),  font=font10, fill=255)
draw.text((col1, line5), network("uap0"),  font=font10, fill=255)
```

if for example it's running from RPI 3 with eth0 code could be 
```python
draw.text((col1, line1),"Host :%s" % socket.gethostname(), font=font10, fill=255)
draw.text((col1, line2), lan_ip("eth0"),  font=font10, fill=255)
draw.text((col1, line3), network("eth0"),  font=font10, fill=255)
draw.text((col1, line4), lan_ip("ap0"),  font=font10, fill=255)
draw.text((col1, line5), network("ap0"),  font=font10, fill=255)
```

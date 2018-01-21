# Promote Raspberry PI based gateway as a WiFi access point

## Install the packages you need for DNS, Access Point and Firewall rules.
```
sudo apt-get install hostapd dnsmasq iptables-persistent
```

## create RAM filesystem (I'm using Read Only Filesystem)
```
sudo mkdir /var/dnsmasq
sudo mkdir /mnt/ramdisk
```

## Add this to /etc/fstab
```
tmpfs   /mnt/ramdisk    tmpfs   defaults,size=16M       0       0
tmpfs   /var/dnsmasq    tmpfs   nosuid,nodev            0       0
```

```shell
sudo cp /etc/resolv.conf /tmp/resolv.conf
sudo rm /etc/resolv.conf
sudo ln -s /tmp/resolv.conf /etc/resolv.conf
#sudo ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf
```


## just in case, save old dnsmasq.conf
```shell
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.org
```

## /etc/dnsmasq.conf
```
interface=lo,uap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=192.168.50.50,192.168.50.150,12h
dhcp-leasefile=/var/dnsmasq/dnsmasq.leases

#address=/*.apple.com/192.168.50.1
#address=/*.icloud.com/192.168.50.1
#address=/#/192.168.50.1

###### logging ############
# own logfile
log-facility=/var/log/dnsmasq.log
# log-async
# log dhcp infos
#log-dhcp
# debugging dns
log-queries


```


## /etc/hostapd/hostapd.conf
```
interface=uap0
ssid=_AP_SSID_
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=_AP_PASSWORD_
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

Replace `_AP_SSID_` with the SSID you want for your access point.  Replace `_AP_PASSWORD_` with the password for your access point.  Make sure it has
enough characters to be a legal password!  (8 characters minimum).

## /etc/default/hostapd
```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```


# On Debian Jessie
http://imti.co/post/145442415333/raspberry-pi-3-wifi-station-ap

## /etc/network/interfaces
```
auto uap0
iface uap0 inet static
  address 192.168.50.1
  netmask 255.255.255.0
  network 192.168.50.0
  broadcast 192.168.50.255
  gateway 192.168.50.1
  metric 9999
```


## /etc/init.d/hostapd
```
  start)

        iw dev wlan0 interface add uap0 type __ap
        service dnsmasq restart
        sysctl net.ipv4.ip_forward=1
        iptables -t nat -A POSTROUTING -s 192.168.50.0/24 ! -d 192.168.50.0/24 -j MASQUERADE
        ifup uap0
        log_daemon_msg "Starting $DESC" "$NAME"
        start-stop-daemon --start --oknodo --quiet --exec "$DAEMON_SBIN" \
                --pidfile "$PIDFILE" -- $DAEMON_OPTS >/dev/null
        log_end_msg "$?"
        ;;

```


# On Debian stretch

https://github.com/peebles/rpi3-wifi-station-ap-stretch

## /etc/network/interfaces.d/ap
```
allow-hotplug uap0
auto uap0
iface uap0 inet static
  address 192.168.50.1
  netmask 255.255.255.0
  metric 9999

```

## /etc/network/interfaces.d/station
```
allow-hotplug wlan0
iface wlan0 inet manual
  wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

```


## /etc/udev/rules.d/90-wireless.rules 
```
ACTION=="add", SUBSYSTEM=="ieee80211", KERNEL=="phy0", RUN+="/sbin/iw phy %k interface add uap0 type __ap"
```

## Do not let DHCPCD manage wpa_supplicant!!
```shell
sudo rm -f /lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant
```

## Set up the client wifi (station) on wlan0.

Create or edit `/etc/wpa_supplicant/wpa_supplicant.conf`. The contents depend on whether your home network is open, WEP or WPA.  It is
probably WPA, and so should look like:

```
    ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
    country=GB
    
    network={
      ssid="_ST_SSID_"
      scan_ssid=1
      psk="_ST_PASSWORD_"
      key_mgmt=WPA-PSK
    }
```

Replace `_ST_SSID_` with your home network SSID and `_ST_PASSWORD_` with your wifi password (in clear text).


## Permanently deal with interface bringup order

see this [issue](https://unix.stackexchange.com/questions/396059/unable-to-establish-connection-with-mlme-connect-failed-ret-1-operation-not-p)
  
Edit `/etc/rc.local` and add the following lines just before `exit 0`
```shell
sleep 5
ifdown wlan0
sleep 2
rm -f /var/run/wpa_supplicant/wlan0
ifup wlan0
```

## Bridge AP to cient side
```shell
sudo sh -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 ! -d 192.168.50.0/24 -j MASQUERADE
sudo sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
```



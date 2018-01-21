# Installation

Download [Raspbian lite image](https://downloads.raspberrypi.org/raspbian_lite_latest) and [flash](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) it to your SD card using [etcher](http://etcher.io/).

## Prepare SD to your environement

Once flashed, on boot partition (windows users, remove and then replug SD card)

Create also a dummy `ssh` file on this partition as well. By default SSH is now disabled so this is required to enable it. Windows users, make sure your file doesn't have an extension like .txt etc.

If you need to be able to use OTG (PI Zero console access for any computer by conecting the PI to computer USB port)
Open up the file `cmdline.txt`. Be careful with this file, it is very picky with its formatting! Each parameter is seperated by a single space (it does not use newlines). Insert `modules-load=dwc2,g_ether` after `rootwait`. And since I don't like the Auto Resize SD function (I prefer do do it manually from `raspi-config`), remove also from the file `cmdline.txt` auto resize by deleting the following 
```
init=/usr/lib/raspi-config/init_resize.sh
```

The new file `cmdline.txt`  should looks like this
```
dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=37665771-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet modules-load=dwc2,g_ether
```

For OTG, add also the bottom of the `config.txt` file, on a new line 
```
dtoverlay=dwc2
```


Finally, on same partition (boot), to allow your PI to connect to your WiFi after first boot, create a file named `wpa_supplicant.conf` to allow the PI to be connected on your WiFi network.

``` 
country=FR
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
  ssid="YOUR-WIFI-SSID"
  psk="YOUR-WIFI-PASSWORD"
}
``` 
Of course change country, ssid and psk with your own WiFi settings.

Finally, to access ssh after boot, always on same partition (boot), create a dummy empty file named `ssh` to allow the PI to run sshd daemon


That's it, eject the SD card from your computer, put it in your Raspberry Pi Zero . It will take up to 90s to boot up (shorter on subsequent boots). You then can SSH into it using `raspberrypi.local` as the address.
If WiFi does not work, connect it via USB to your computer It should then appear as a USB Ethernet device.


## connect to raspberry PI with ssh or via USB otg

Remember default login/paswword (ssh or serial console) is pi/raspberry

```shell
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install git-core build-essential ntp scons python-dev swig
``` 

## Create a new user account.

This `loragw` account will be used instead of default existing `pi` account for security reasons.
```shell
sudo useradd -m loragw -s /bin/bash
``` 

Type a suitable password for the `loragw` account.
```shell
sudo passwd loragw
``` 

Add the `loragw` user to the group `sudo` and allow sudo command with no password
```shell
sudo usermod -a -G sudo loragw
sudo cp /etc/sudoers.d/010_pi-nopasswd /etc/sudoers.d/010_loragw-nopasswd
sudo sed -i -- 's/pi/loragw/g' /etc/sudoers.d/010_loragw-nopasswd
``` 

copy default `pi` profile to `loragw`
```shell
sudo cp /home/pi/.profile /home/loragw/
sudo cp /home/pi/.bashrc /home/loragw/
sudo chown loragw:loragw /home/loragw/.*
``` 

Now do some system configuration with `raspi-config` tool
```shell
sudo raspi-config
``` 

  - change user password (Type a strong password)
  - network options, change hostname (loragw for example)
  - localization options, change Locale to EN_us.UTF8
  - localization options, change keyboard layout
  - localization options, change time zone
  - interfacing options, enable SPI, I2C, Serial and SSH (if not already done)
  - advanced options, expand filesystem
  - advanced options, reduce video memory split set to 16M

then *reboot and log back with `loragw` user*.
```shell
sudo reboot
``` 

## Optionnal, Install log2ram this will preserve your SD card
```shell
git clone https://github.com/azlux/log2ram.git
cd log2ram
chmod +x install.sh uninstall.sh
sudo ./install.sh
sudo ln -s /usr/local/bin/ram2disk /etc/cron.hourly/
```

## Install nodejs

### For Pi Zero (see below for PI3)
You can select and change nodejs version selecting the correct shell script [here](https://github.com/sdesalas/node-pi-zero) 
Here is latest V7 at the time of writing.
``` 
sudo wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v7.7.1.sh | bash
``` 
Add the following to the end of your ~/.profile file:
``` 
export PATH=$PATH:/opt/nodejs/bin
export NODE_PATH=/opt/nodejs/lib/node_modules
``` 

### For Pi 3 (see above for PI Zero)
``` 
sudo curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
sudo apt-get install nodejs
``` 


then *reboot and log back with `loragw` user*.
```shell
sudo reboot
``` 


## Get CH2i Gateway Install repository
``` 
git clone https://github.com/ch2i/LoraGW-Setup
cd LoraGW-Setup
```

## Packet Forwarder

New Multi-protocol Packet Forwarder by Jac @Kersing (thanks to @jpmeijers for scripting stuff)
Now build the whole thing, time to get a coffe, it can take 10/15 minutes!
``` 
sudo ./build.sh
``` 

## Configure Gateway on TTN

Now you need to register your new GW on ttn, see [gateway registration](https://www.thethingsnetwork.org/docs/gateways/registration.html#via-gateway-connector), fill the GW_ID and GW_KEY when running

``` 
sudo ./setup.sh
``` 

## Install WS2812 driver 

The onboard WS2812 library and the Raspberry Pi audio both use the PWM, they cannot be used together. You will need to blacklist the Broadcom audio kernel module by editing a file 
``` 
sudo nano /etc/modprobe.d/snd-blacklist.conf 
``` 

and put into
```
blacklist snd_bcm2835
```


### Install WS2812 led driver
``` 
git clone https://github.com/jgarff/rpi_ws281x
cd rpi_ws281x/
scons
scons deb
sudo dpkg -i libws2811*.deb
sudo cp ws2811.h /usr/local/include/
sudo cp rpihw.h /usr/local/include/
sudo cp pwm.h /usr/local/include/
``` 

### Install WS2812 python wrapper
``` 
cd python
python ./setup.py build
``` 

### Install WS2812 python library
``` 
sudo python setup.py install
cd
``` 

### Install NodeJS version of WS2812 driver
``` 
cd
sudo npm install -g --unsafe-perm rpi-ws281x-native
npm link rpi-ws281x-native
``` 


### Test WS2812 LED if you have any, in python or nodejs
``` 
sudo ./LoraGW-Setup/testled.py
sudo ./LoraGW-Setup/testled.js
``` 


# Use nice I2C OLED display

## Install the packages you need
```
sudo apt-get update && sudo apt-get upgrade
sudo apt-get install i2c-tools
```

## Increase the I2C baudrate from the default of 100KHz to 400KHz

```
sudo nano /boot/config.txt
```

add this line at the end of the file
```
dtparam=i2c_arm=on,i2c_baudrate=400000
```



## Add your user to I2C group 

```
sudo usermod -a -G i2c loragw
```

then *logout (CTRL-d) and log back so that the group membership permissions take effect*
```shell
sudo reboot
``` 

## Check you can see I2C OLED

```shell
 i2cdetect -y 1
```

you should see something in your OLED I2C address, here it's 3C (Hex)
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- 3c -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
```

## Install OLED Python library

### Install dependencies
``` 
sudo apt install python-dev python-pip libfreetype6-dev libjpeg-dev build-essential
```

### Install luma OLED core 
You can go for a coffe after this one, takes some time
``` 
sudo -H pip install --upgrade luma.oled
``` 

### Get examples files (and font)
``` 
sudo mkdir -p /usr/share/fonts/truetype/luma
git clone https://github.com/rm-hull/luma.examples.git
sudo cp luma.examples/examples/fonts/*.ttf /usr/share/fonts/truetype/luma/
```

### Build examples (recommend to skip this section)
But if you want to run all examples, which I do not recommand because it takes SD space and very long time to install, type the following
``` 
sudo apt install libsdl-dev libportmidi-dev libsdl-ttf2.0-dev libsdl-mixer1.2-dev libsdl-image1.2-dev
sudo pip install --upgrade setuptools
cd luma.examples
sudo -H pip install -e .
```

## Configure OLED 

### Configure OLED Hardware

You may need to change the following line in `oled.py` according to the connected OLED type and it I2C address.

The i2c adress can be seen with `i2cdetect -y 1`

```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- 3c -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
```

If you already installed all the Gateway software it's located in `/opt/loragw/oled.py` else in `~/LoraGW-Setup/oled.py`

Mine is 1.3" SH1106 with 0x3c address so my config is 
```python
serial = i2c(port=1, address=0x3c)
device = sh1106(serial)
```

But as an example, for SSD1306 oled with address 0x3d
```python
serial = i2c(port=1, address=0x3d)
device = ssd1306(serial)
```

Then you can check OLED display with, shold display something
```
./oled.py
```


### Configure OLED software

You may need to change the following line in `/opt/loragw/oled.py` according to the connected network interface you have

Mine is wlan0 for WiFi and uap0 for WiFi [access point](https://github.com/ch2i/LoraGW-Setup/blob/master/doc/AccessPoint.md)
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
draw.text((col1, line4), lan_ip("wlan0"),  font=font10, fill=255)
draw.text((col1, line5), network("wlan0"),  font=font10, fill=255)
```

Once all is setup and running you can enable disbale OLED service with
``` 
sudo systemctl enable oled
sudo systemctl disable oled
```

And start or stop the OLED service with
``` 
sudo systemctl start oled
sudo systemctl stop oled
```

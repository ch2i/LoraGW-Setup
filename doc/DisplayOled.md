# Use nice I2C OLED display

## Install the packages you need
```
sudo apt-get update && sudo apt-get upgrade
sudo apt-get install i2c-tools
```

## Increase the I2C baudrate from the default of 100KHz to 400KHz

add this line to `/boot/config.txt`
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

you should see somthing in your OLED I2C address, here it's 3C (Hex)
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

### Install examples and library
``` 
git clone https://github.com/rm-hull/luma.examples.git
cd luma.examples
sudo -H pip install -e .
```

### Copy examples fonts to system
``` 
sudo mkdir /usr/share/fonts/truetype/luma
sudo cp ~/luma.examples/examples/fonts/*.ttf /usr/share/fonts/truetype/luma/
```


## Configure forwarder to send stats to OLED process

You need to send data to the listener (we use port 1688), for this we add a gwtraf server into the servers options in file 
`/opt/loragw/local_conf.json` 
```json
{
  "server_address": "127.0.0.1",
  "serv_type": "gwtraf",
  "serv_port_up": 1688,
  "serv_port_down": 1689,
  "serv_enabled": true
}
```

for example my full `/opt/loragw/local_conf.json` is configured with 3 Gateways as follow

 - 1 for TTN (here disabled)
 - 1 for gw traffic monitoring on OLED
 - 1 for local backend LoRaWAN server

You can enable/disable each server with key `serv_enabled` set to `true` or `false`

```
{
  "gateway_conf": {
    "gateway_ID": "B827EBFFFED41691",
    "description": "CH2i TTN GW For testing  purpose",
    "servers": [
      {
        "server_address": "bridge.eu.thethings.network",
        "serv_gw_id": "YOUR_GW_ID",
        "serv_type": "ttn",
        "serv_gw_key": "ttn-account-v2.YOUR_ACCOUNT_KEY",
        "serv_enabled": false
      },


      {
        "server_address": "127.0.0.1",
        "serv_type": "gwtraf",
        "serv_port_up": 1688,
        "serv_port_down": 1689,
        "serv_enabled": true
      },

      {
        "server_address": "127.0.0.1",
        "serv_port_up": 1680,
        "serv_port_down": 1680,
        "serv_enabled": true
      }
    ],

    "keepalive_interval": 10,
    "stat_interval": 30,
    "push_timeout_ms": 100,
    "forward_crc_valid": true,
    "forward_crc_error": false,
    "forward_crc_disabled": false,

    "contact_email": "contact@ch2i.eu"
  }
}
```


## Configure OLED hardware

You may need to change the following line in `/opt/loragw/oled.py` according to the connected OLED type and it I2C address

For SH1106 oled with address 0x3c
```python
serial = i2c(port=1, address=0x3c)
device = sh1106(serial)
```

For SSD1306 oled with address 0x3d
```python
serial = i2c(port=1, address=0x3d)
device = ssd1306(serial)
```


Once all is setup and running you can try to launch the OLED script with

``` 
/opt/loragw/oled.py
```

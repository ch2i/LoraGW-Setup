# Use LoRaWAN Server

## Description
For this we will use a freee open source lorawan-server written by Peter Gotthard. Thanks to him for sharing. The server is very light and efficient and always safisfied my need.

## Installation
You can follow the installation procedure [here](https://github.com/gotthardp/lorawan-server/blob/master/doc/Installation.md)

I generally use to download the Debian package install it with `dpkg -i`

```
wget https://github.com/gotthardp/lorawan-server/releases/download/v0.5.3/lorawan-server_0.5.3_all.deb
dpkg -i lorawan-server_0.5.3_all.deb
```

## Post Installation
Then to improove log rotation, you can add this lines to 
`/etc/logrotate.d/rsyslog`
```
/var/log/lorawan-server/crash.log
/var/log/lorawan-server/error.log
/var/log/lorawan-server/debug.log
{
        rotate 1
        daily
        missingok
        notifempty
        compress
        postrotate
                invoke-rc.d rsyslog rotate > /dev/null
        endscript
}
```

### Forward packets to local Server

If you installed all your gateway stuff from this current [repository](https://github.com/ch2i/LoraGW-Setup), you just need to enable the forwarder to send packed to the Local LoRaWAN server. 
For this set the line `serv_enabled` to `true` for the server `127.0.0.1`
Take care, the one that has both port to 1680, not the one with 1688/1689 (this one is for OLED)

`sudo nano /opt/loragw/global_conf.json`

```json
            {
                "server_address": "127.0.0.1",
                "serv_enabled": true,           // <== set this one to true
                "serv_port_up": 1680,
                "serv_port_down": 1680
            }
```

And restart loragw service to take into account the new local server with
``` 
sudo systemctl stop loragw
sudo systemctl start loragw
```




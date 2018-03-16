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


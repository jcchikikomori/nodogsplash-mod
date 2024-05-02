# nodogsplash

## OpenWRT Setup

```sh
uci set nodogsplash.@nodogsplash[0].splashpage='splash.html'
uci set nodogsplash.@nodogsplash[0].binauth='/etc/nodogsplash/binauth.sh'
uci commit nodogsplash
```

## Logging

Please read the documentation provided: https://openwrt.org/docs/guide-user/base-system/log.essentials

```sh
# List syslog
logread
 
# Write a message with a tag to syslog
logger -t TAG MESSAGE
 
# List syslog filtered by tag
logread -e TAG
```

## Reminder

Make sure binauth.sh has proper permissions:

```sh
chmod u+x bin/binauth.sh
```

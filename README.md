# nodogsplash

## OpenWRT Setup

```sh
uci set nodogsplash.@nodogsplash[0].splashpage='splash.html'
uci set nodogsplash.@nodogsplash[0].binauth='/etc/nodogsplash/binauth.sh'
uci commit nodogsplash
```

## Reminder

Make sure binauth.sh has proper permissions:

```sh
chmod u+x bin/binauth.sh
```

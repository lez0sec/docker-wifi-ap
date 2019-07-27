

## Usage

Build image:
```bash
docker build  -t wifi-ap ./
```

Start container:
```bash
docker run --rm -it --env-file=`pwd`/env_file.txt --cap-add=NET_ADMIN --net host wifi-ap
```
Note that you do not need to run it as ```sudo docker [...] --privileged```, it is enough with ```--cap-add=NET_ADMIN```.

env_file.txt template:

```
INTERFACE=wlan0
CHANNEL=6
SSID=JANDEPORA
AP_ADDR=10.15.0.10		# IP address to configure for the Wifi Access Point. Note that clients will be NAT'ed.
SUBNET=10.15.0.0
GATEWAY=10.15.0.10		# Default gateway, in case it's different than the AP's IP. In this case you'd have to tweak the dhcpd.conf options embedded within wlanstart.sh as client's would not be NAT'ed by the AP.
WPA_PASSPHRASE=passw0rd
OUTGOINGS=eth0			# 
PRI_DNS=192.168.1.49	# Useful if you are running a rogue DNS server here to spoof DNS records
SEC_DNS=8.8.4.4

HW_MODE=g
```

Take a look at the following variables at ```wlanstart.sh``` for extra Wi-Fi options:

```
# Activate channel selection for HT High Througput (802.11an)
${HT_ENABLED+"ieee80211n=1"}
${HT_CAPAB+"ht_capab=${HT_CAPAB}"}

# Activate channel selection for VHT Very High Througput (802.11ac)

${VHT_ENABLED+"ieee80211ac=1"}
${VHT_CAPAB+
```

## Additional notes:

It's worth bearing in mind that the container has access to **all** of the host's interfaces. Note that it is using ```--net host``` (Reference here: https://docs.docker.com/network/host/)

## Credit:

This is a customized version of https://hub.docker.com/r/sdelrio/rpi-hostap
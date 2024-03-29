#!/bin/bash

# CONSTANTS #
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# /CONSTANTS #

printf "${RED}ATTENTION:${BLUE}"
printf "\tIf you are having problems, you may need to run:\n"    
printf "\t\tsudo nmcli radio wifi off\n"    
printf "\t\tsudo rfkill unblock wlan${NC}\n"   


# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo "[Error] Not running in privileged mode."
    #exit 1
fi

# Check environment variables
if [ ! "${INTERFACE}" ] ; then
    echo "[Error] An interface must be specified."
    exit 1
fi

# Default values
true ${SUBNET:=192.168.254.0}
true ${AP_ADDR:=192.168.254.1}
true ${PRI_DNS:=8.8.8.8}
true ${SEC_DNS:=8.8.4.4}
true ${SSID:=raspberry}
true ${CHANNEL:=11}
true ${WPA_PASSPHRASE:=passw0rd}
true ${HW_MODE:=g}

if [ ! -f "/etc/hostapd.conf" ] ; then
    cat > "/etc/hostapd.conf" <<EOF
interface=${INTERFACE}
${DRIVER+"driver=${DRIVER}"}
ssid=${SSID}
hw_mode=${HW_MODE}
channel=${CHANNEL}
wpa=2
wpa_passphrase=${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
# TKIP is no secure anymore
#wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_ptk_rekey=600
wmm_enabled=1

# Activate channel selection for HT High Througput (802.11an)

${HT_ENABLED+"ieee80211n=1"}
${HT_CAPAB+"ht_capab=${HT_CAPAB}"}

# Activate channel selection for VHT Very High Througput (802.11ac)

${VHT_ENABLED+"ieee80211ac=1"}
${VHT_CAPAB+"vht_capab=${VHT_CAPAB}"}
EOF

fi

# Setup interface and restart DHCP service
ip link set ${INTERFACE} up
ip addr flush dev ${INTERFACE}
ip addr add ${AP_ADDR}/24 dev ${INTERFACE}

# NAT settings
echo "NAT settings ip_dynaddr, ip_forward"


for i in ip_dynaddr ip_forward ; do
  if [ $(cat /proc/sys/net/ipv4/$i) -eq 1 ] ; then
    echo $i already 1
  else
    echo "1" > /proc/sys/net/ipv4/$i
  fi
done

cat /proc/sys/net/ipv4/ip_dynaddr
cat /proc/sys/net/ipv4/ip_forward

if [ "${OUTGOINGS}" ] ; then
   ints="$(sed 's/,\+/ /g' <<<"${OUTGOINGS}")"
   for int in ${ints}
   do
      echo "Setting iptables for outgoing traffics on ${int}..."

      iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE > /dev/null 2>&1 || true
      iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE

      iptables -D FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -D FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT
   done
else
   echo "Setting iptables for outgoing traffics on all interfaces..."

   iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
   iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -j MASQUERADE

   iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

   iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -i ${INTERFACE} -j ACCEPT
fi

echo "Configuring DHCP server .."

cat > "/etc/dhcpd.conf" <<EOF
option domain-name-servers ${PRI_DNS}, ${SEC_DNS};
option subnet-mask 255.255.255.0;
option routers ${GATEWAY};
subnet ${SUBNET} netmask 255.255.255.0 {
  range ${SUBNET::-1}100 ${SUBNET::-1}200;
}
EOF

echo "Starting DHCP server .."
dhcpd ${INTERFACE} -cf /etc/dhcpd.conf

# Capture external docker signals
trap 'true' SIGINT
trap 'true' SIGTERM
trap 'true' SIGHUP

echo "Starting HostAP daemon ..."
/usr/sbin/hostapd /etc/hostapd.conf &

wait $!

echo "Removing iptables rules..."

if [ "${OUTGOINGS}" ] ; then
   ints="$(sed 's/,\+/ /g' <<<"${OUTGOINGS}")"
   for int in ${ints}
   do
      echo "Removing iptables for outgoing traffics on ${int}..."

      iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE > /dev/null 2>&1 || true

      iptables -D FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true

      iptables -D FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT > /dev/null 2>&1 || true
   done
else
   echo "Setting iptables for outgoing traffics on all interfaces..."

   iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true

   iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true

   iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
fi

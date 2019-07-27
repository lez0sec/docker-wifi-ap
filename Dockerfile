FROM alpine:latest

RUN apk update && \
	apk --no-cache add bash hostapd iptables dhcp &&\
	rm -rf /var/cache/apk/*

RUN echo "" > /var/lib/dhcp/dhcpd.leases

# Copy script over and give it exec permissions
COPY wlanstart.sh /bin/wlanstart.sh
RUN ["chmod", "+x", "/bin/wlanstart.sh"]

ENTRYPOINT [ "/bin/wlanstart.sh" ]


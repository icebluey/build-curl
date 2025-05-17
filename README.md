
# capture HTTP/3 (QUIC) traffic
```
tcpdump -i ens5 -w www.cloudflare.com-h3.pcap -s 0 -Snn -vvv -XX host 104.16.123.96 or host 104.16.124.96

SSLKEYLOGFILE=/tmp/tlskey.log curl -4 -vI --http3-only https://www.cloudflare.com
```

# wireshark
```
Edit -> Preferences -> Protocols -> TLS -> (Pre)-Master-Secret log filename
Browse to select tlskey.log
Apply
```

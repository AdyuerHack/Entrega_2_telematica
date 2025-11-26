;
; BIND data file for miempresa.com
;
$TTL    604800
@       IN      SOA     ns1.miempresa.com. admin.miempresa.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.miempresa.com.
@       IN      A       192.168.1.10  ; IP del servidor Nginx (Proxy)
ns1     IN      A       192.168.1.10
www     IN      A       192.168.1.10
app     IN      A       192.168.1.10

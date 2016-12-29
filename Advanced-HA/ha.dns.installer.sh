#!/bin/bash

guid=`hostname|cut -f2 -d-|cut -f1 -d.`
yum -y install bind bind-utils
systemctl enable named
systemctl stop named

### firewalld was being a bit problematic
### Since we turn it off later anyway, I've skipped this step.
#firewall-cmd --permanent --zone=public --add-service=dns
#firewall-cmd --reload
#sleep 100;

infraIP1=`host infranode1-$guid.oslab.opentlc.com ipa.opentlc.com  | grep $guid | awk '{ print $4 }'`
infraIP2=`host infranode2-$guid.oslab.opentlc.com ipa.opentlc.com  | grep $guid | awk '{ print $4 }'`
domain="cloudapps-$guid.oslab.opentlc.com"

  10  ; minimum (10 seconds)
)
  NS master.${domain}.
\$ORIGIN ${domain}.
test A ${infraIP1}
* A ${infraIP1}
* A ${infraIP2}"  >  /var/named/zones/${domain}.db

chgrp named -R /var/named
chown named -R /var/named/zones
restorecon -R /var/named

echo "// named.conf
options {
  listen-on port 53 { any; };
  directory \"/var/named\";
  dump-file \"/var/named/data/cache_dump.db\";
  statistics-file \"/var/named/data/named_stats.txt\";
  memstatistics-file \"/var/named/data/named_mem_stats.txt\";
  allow-query { any; };
  recursion yes;
  /* Path to ISC DLV key */
  bindkeys-file \"/etc/named.iscdlv.key\";
};
logging {
  channel default_debug {
    file \"data/named.run\";
    severity dynamic;
  };
};
zone \"${domain}\" IN {
  type master;
  file \"zones/${domain}.db\";
  allow-update { key ${domain} ; } ;
};" > /etc/named.conf

chown root:named /etc/named.conf
restorecon /etc/named.conf

systemctl start named

dig @127.0.0.1 test.cloudapps-$guid.oslab.opentlc.com

if [ $? = 0 ]
then
  echo "DNS Setup was successful!"
else
  echo "DNS Setup failed"
fi

echo Fully Finished the $0 script  | tee -a /root/.dns.installer.txt

yum install iptables-services -y
systemctl stop firewalld
systemctl disable firewalld
systemctl enable iptables
systemctl start iptables

iptables -I INPUT -p tcp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

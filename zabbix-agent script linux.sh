#!/bin/sh

# installe les packets nécessaire depuis le répertoire zabbix 
wget https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian11_all.deb
dpkg -i zabbix-release_6.4-1+debian11_all.deb
apt update
apt install zabbix-agent

# modifie le fichier conf pour le paramétré avec les informations du serveur et aussi utile à ceux dernier
agent_conf = /etc/zabbix/zabbix_agentd.conf;
hostname = $(hostname);

sed -i 's/Server=127.0.0.1/Server=zabbix.systancia.com/g' $agent_conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=zabbix.systancia.com/g' $agent_conf
sed -i 's/# Hostname=/Hostname=$hostname/g' $agent_conf

# si on veut que la machine s'identifie par son "Hostname", on a besoin de la ligne suivante :
# sed -i 's/# HostnameItem=system.hostname/HostnameItem=system.hostname/g' $agent_conf

# Pour que le serveur puisse automatiquement enregistrer les nouveaux hôtes, les données ci-dessus ne suffisent pas, 
\nous avons donc besoin de spécifier le "HostMetaDataItem" pour que ça fonctionne
sed -i 's/# HostMetaData=/HostMetaData=linux/g' $agent_conf

psk = $(openssl rand -hex 32);
psk_into_rep = $($psk > /etc/zabbix/zabbix_agentd.psk);
repPsk = /etc/zabbix/zabbix_agentd.psk;

sed -i 's/# TLSConnect=unencrypted/TLSConnect=psk/g' $agent_conf
sed -i 's/# TLSAccept=unencrypted/TLSAccept=psk/g' $agent_conf
sed -i 's/# TLSPSKFile=/TLSPSKFile=$repPsk/g' $agent_conf

systemctl start zabbix-agent
systemctl enable zabbix-agent
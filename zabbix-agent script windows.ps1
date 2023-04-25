$Target = "C:"
$zabbixDir = "C:\zabbix"

Invoke-WebRequest -Uri "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.1/zabbix_agent-6.4.1-windows-amd64-openssl.zip" -OutFile $Target
Expand-Archive $Target -DestinationPath $zabbixDir

if ( Test-Path "C:\zabbix" ) {

        C:\zabbix\zabbix_agentd.exe --config C:\zabbix\zabbix_agentd.conf --install 2>&1 | out-null
        Start-Sleep -s 2

        C:\zabbix\zabbix_agentd.exe --config C:\zabbix\zabbix_agentd.conf --start 2>&1 | out-null

        #je coupe le service pour modifier la configuration
        Start-Sleep -s 2
        C:\zabbix\zabbix_agentd.exe --config C:\zabbix\zabbix_agentd.conf --stop 2>&1 | out-null

        #Génère la clef PSK de l'host avec son nom machine.psk
        $mypsk = C:\zabbix\openssl.exe rand -hex 32
        Write-Output $mypsk > "C:\zabbix\zabbix_agentd.psk"
    } else {
    Write-Host "Fail Copy check sources"
    Exit
    }

# Crée le répertoire si il n'existe pas
if (!(Test-Path -Path $zabbixDir)) {
    New-Item $zabbixDir -ItemType Directory
    }

$Hostname = hostname

# Pour identifier le serveur, il faut modifier quelques paramètres (à noter que "ServerActive" et "Hostname" n'importe pas sur le bon fonctionnement du monitoring de la machine, ils là que pour donner des indications)
# Autre remarque; si on veut que la machine s'identifie par son "Hostname", on a besoin de la ligne suivante :
# (Get-Content C:\zabbix\zabbix_agentd.conf).replace('# HostnameItem=system.hostname', 'HostnameItem=system.hostname') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('Server=127.0.0.1', 'Server=zabbix.systancia.com') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('ServerActive=127.0.0.1', 'ServerActive=zabbix.systancia.com') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# Hostname=', "Hostname=$Hostname") | Set-Content C:\zabbix\zabbix_agentd.conf

# Pour que le serveur puisse automatiquement enregistrer les nouveaux hôtes, les données ci-dessus ne suffisent pas, nous avons donc besoin de spécifier le "HostMetaDataItem" pour que ça fonctionne
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# HostMetadataItem=', 'HostMetadataItem=system.uname') | Set-Content C:\zabbix\zabbix_agentd.conf


# génère aléatoirement un chiffre qui sera réutilisé pour l'identité psk
$CurrentRandom = Get-Random -minimum 1 -maximum 99
$FinalePSKId = "PSK $CurrentRandom"

# Pour qu'il accepte le chiffrement psk, il faut modifier quelques paramètres
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# TLSConnect=unencrypted', 'TLSConnect=psk') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# TLSAccept=unencrypted', 'TLSAccept=psk') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# TLSPSKIdentity=', "TLSPSKIdentity=$FinalePSKId") | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# TLSPSKFile=', "TLSPSKFile=C:\zabbix\zabbix_agentd.psk") | Set-Content C:\zabbix\zabbix_agentd.conf

# On s'assure que le service à bien été arrêté et on le démarre normalement
C:\zabbix\zabbix_agentd.exe --config C:\zabbix\zabbix_agentd.conf --stop 2>&1 | out-null
Start-Sleep -s 2
C:\zabbix\zabbix_agentd.exe --config C:\zabbix\zabbix_agentd.conf --start 2>&1 | out-null
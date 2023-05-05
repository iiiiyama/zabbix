$Target = "C:"
$zabbixDir = "C:\zabbix"

# Télécharge l'archive de l'agent
Invoke-WebRequest -Uri "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.1/zabbix_agent-6.4.1-windows-amd64-openssl.zip" -OutFile $Target
Expand-Archive $Target -DestinationPath $zabbixDir

#télécharge openssl pour Windows
Invoke-WebRequest -Uri "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.1.0.zip" -OutFile "openssl.zip"
Expand-Archive -Path "openssl.zip" -DestinationPath "C:\Users"

if ( Test-Path "C:\zabbix" ) {
        
        Set-Location $zabbixDir

        .\zabbix_agentd.exe --config .\zabbix_agentd.conf --install 2>&1 | out-null
        Start-Sleep -s 2

        .\zabbix_agentd.exe --config .\zabbix_agentd.conf --start 2>&1 | out-null

        #je coupe le service pour modifier la configuration
        Start-Sleep -s 2
        .\zabbix_agentd.exe --config .\zabbix_agentd.conf --stop 2>&1 | out-null

        #Génère la clef PSK de l'host avec son nom machine.psk
        Set-Location "C:\Users\openssl-3\x64\bin"
        $mypsk = .\openssl.exe rand -hex 32
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

# Pour identifier le serveur, il faut modifier quelques paramètres (à noter que "ServerActive" et "Hostname" n'importe pas sur le bon fonctionnement du monitoring de la machine, il ne l'a que pour donner des indications)
# Autre remarque; si on veut que la machine s'identifie par son "Hostname", on a besoin de la ligne suivante :
# (Get-Content C:\zabbix\zabbix_agentd.conf).replace('# HostnameItem=system.hostname', 'HostnameItem=system.hostname') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('Server=127.0.0.1', 'Server=zabbix.systancia.com') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('ServerActive=127.0.0.1', 'ServerActive=zabbix.systancia.com') | Set-Content C:\zabbix\zabbix_agentd.conf
(Get-Content C:\zabbix\zabbix_agentd.conf).replace('# Hostname=', "Hostname=$Hostname") | Set-Content C:\zabbix\zabbix_agentd.conf
# la ligne ci-dessous permet d'effectuer des commandes à distance sur l'agent
(Get-Content C:\zabbix\zabbix_agentd.conf | foreach {$_ -match "EnableRemoteCommands"}).replace('# Mandatory: no', 'EnableRemoteCommands=1') | Set-Content C:\zabbix\zabbix_agentd.conf

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
.\zabbix_agentd.exe --config .\zabbix_agentd.conf --stop 2>&1 | out-null
Start-Sleep -s 2
.\zabbix_agentd.exe --config .\zabbix_agentd.conf --start 2>&1 | out-null

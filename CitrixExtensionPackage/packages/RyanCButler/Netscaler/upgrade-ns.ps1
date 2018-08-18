﻿<#
.SYNOPSIS
   A PowerShell script for upgrading Netscaler firmware via REST API (Versions greater than 11.1)
.DESCRIPTION
   A PowerShell script for upgrading Netscaler firmware via REST API (Firmware greater than 11.1)
.PARAMETER nsip
   DNS Name or IP of the Netscaler that needs to be configured. (MANDATORY)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password for the Netscaler admin account (Default: nsroot)
.PARAMETER https
   Use HTTPS for communication to NSSIP
.PARAMETER url
   URL for Netscaler firmware (MANDATORY)
.PARAMETER reboot
    Reboot after upgrade (Default: true)
.PARAMETER callhome
    Enable CallHome (Default: false)
.EXAMPLE
   ./upgrade-ns.ps1 -nsip 10.1.1.2 -url "https://mywebserver/build-11.1-47.14_nc.tgz"
   Use the default NSROOT\NSROOT credentials and the providedd url.  Uses the default values of disabling "callhome" and rebooting after upgrade.
.EXAMPLE
   ./upgrade-ns.ps1 -nsip 10.1.1.2 -url "https://mywebserver/build-11.1-47.14_nc.tgz" -adminaccount nsadmin -adminpassword "mysupersecretpassword" -callhome -noreboot
   Uses a different set of Netscaler credentials, enables callhome and does not reboot after upgrade completetion
#>
Param
(
    [Parameter(Mandatory=$true)]$nsip,
    [String]$adminaccount="nsroot",
    [String]$adminpassword="nsroot",
    [switch]$https,
    [Parameter(Mandatory=$true)]$url,
    [switch]$noreboot,
    [switch]$callhome
)


#Tested with Windows 10 and Netscaler 11.1_47.14
#USE AT OWN RISK
#By: Ryan Butler 6-30-16
#updated: 8-11-16 added function to get NS version and some minor error checking
#         12-29-16: added NS version check   


#Netscaler NSIP login information
if ($https)
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    write-host "Connecting HTTPS" -ForegroundColor Yellow
    $hostname = "https://" + $nsip
}
else
{
    write-host "Connecting HTTP" -ForegroundColor Yellow
    $hostname = "http://" + $nsip
}


$username = $adminaccount
$password = $adminpassword



##Functions
###############################
#Probably not much you have to edit below this
###############################


function Login {

    # Login to NetScaler and save session to global variable
    $body = ConvertTo-JSON @{
        "login"=@{
            "username"="$username";
            "password"="$password"
            }
        }
    try {
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST |Out-Null
    $Script:NSSession = $local:NSSession
    }
    Catch
    {
    throw $_
    }
}


#Upgrade the NS function
function upgradens ($url, $callhome) {

    # Support function called by CipherGroup
    $body = ConvertTo-JSON @{
        "install"=@{
            "url" = $url;
            "y" = $false;
            "l" = $ch;
            }
        }

    try {
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/install" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method POST -TimeoutSec 600 |Out-Null
    }
    Catch
    {
    throw $_
    }
  
}

#Gets Netscaler Version
function get-nsversion () {

    # Support function called by CipherGroup


    try {
    $version = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET 
    }
    Catch
    {
    throw $_
    }

return $version.nsversion  
}


#Reboots netscaler
function reboot-ns {

    $body = ConvertTo-JSON @{
        "reboot"=@{
            "warm" = $false;
            }
        }

    Invoke-RestMethod -uri "$hostname/nitro/v1/config/reboot" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method POST|Out-Null
}

function check-nsversion {
    #Checks for supported NS version
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $version = $info.nsversion.version
    $version = $version.Substring(12,4)

    if ($version -lt 11.1)
    {
    throw "Version of Netsaler firmware must be greater or equal to 11.1"
    }

}

###Script starts here

#Logs into netscaler
write-host "Logging in..."
Login

#Check for supported firmware version
check-nsversion

#workaround for variable type
if($callhome)
{
   write-host "Enabling callhome"
   $ch = $true
}
else
{
    write-host "Disabling callhome"
    $ch = $false
}

$version = get-nsversion
write-host "Netscaler Version:" $version.version
write-host "Upgrading Netscaler at $nsip..."
$timetorun = measure-command {upgradens $url $callhome}

write-host "Upgrade completed..." -ForegroundColor Green
write-host "Took $timetorun..."

if(!$noreboot)
{
write-host "Rebooting $nsip..."
reboot-ns
}
else
{
write-host "Upgrade for $nsip completed. Make sure to reboot NS."
}



CLS
#Configures Storefront and IIS for application-initialization
#Must be run as administrator and application-initialization must be already installed
#see http://support.citrix.com/article/CTX137400
#Ryan Butler
#10/7/2014

#Imports modules needed
& 'C:\Program Files\Citrix\Receiver StoreFront\Scripts\importModules.ps1'



######################DON'T EDIT BELOW LINE
$servers = (Get-DSClusterMembersName).hostnames

$storenames = (get-dsstores).FriendlyName

foreach ($server in $servers)
{
$flag = 0
write-host Checking $server


#Edits applicationHost.config for application initalization
$xmlpath = "\\" + $server + "\C$\Windows\System32\inetsrv\config\applicationHost.config"

if (test-path $xmlpath)
{
write-host "Found config file..." -foregroundcolor green
$config = New-Object System.Xml.XmlDocument
$config.Load($xmlpath)

$pools = $config.configuration.'system.applicationHost'.applicationpools.add | where{$_.name -like "Citrix*"}
foreach ($pool in $pools)
{
Write-Host $pool.name
	if($pool.startMode -eq "AlwaysRunning")
	{
	Write-Host "Set to AlwaysRunning" -ForegroundColor Green
	}
	else
	{
	Write-Host "Changing to AlwaysRunning" -ForegroundColor yellow
	$pool.SetAttribute('startMode','AlwaysRunning')
	$flag = 1
	}

}

$sites = $config.configuration.'system.applicationHost'.sites.site
foreach ($site in $sites)
{
$apps = $site.application
	foreach ($app in $apps)
	{
		if (($app.path -like "/Citrix*") -or ($app.path -like "/AGServices*") -and ($app.path -notlike "/Citrix/PNAgent*"))
		{
			Write-Host $app.path
		
			if ($app.preloadEnabled -eq "true")
			{
			Write-Host "preloadEnabled already configured" -ForegroundColor Green
			}
			else
			{
			Write-Host "Adjusting preloadEnabled" -ForegroundColor yellow
            $app.SetAttribute('preloadEnabled','true')
			$flag = 1
			}
		}
	}

}
        if ($flag -eq 1)
        {
		Write-Host "Renaming file..." -foregroundcolor gray
		Rename-Item -Path $xmlpath -NewName "applicationHost.config.old"
        #write-host "Restarting IIS..." -foregroundcolor gray
        #iisreset $server
        $config.Save($xmlpath)
		}

}
else
{
write-host "Config file not found..."
}

foreach ($storename in $storenames)
{
#Edits the Storefront config files
$webconfigs = "\AGServices\web.config","\Citrix\Authentication\web.config","\Citrix\Roaming\web.config",("\Citrix\" + $storename + "\web.config")
foreach ($webconfig in $webconfigs)
{
    write-host $webconfig
    $configpath = "\\" + $server + "\c$\inetpub\wwwroot\" + $webconfig
    if (test-path $configpath)
    {
    Write-host "Webconfig file found..."
    $webxml = New-Object System.Xml.XmlDocument
    $webxml.Load($configpath)
	$config = $webxml.configuration.'system.webServer'
	if ($config.applicationInitialization)
	{
	Write-Host "Found applicationInitialization" -foregroundcolor green
	}
	else
	{
	Write-Host "Adding applicationInitialization"
	$add = $webxml.CreateElement('applicationInitialization')
	$add.SetAttribute('skipManagedModules','true')|Out-Null
	$config.AppendChild($add)
	$config = $config.applicationInitialization
	$add = $webxml.CreateElement('add')
	$add.SetAttribute('initializationPage','/endpoints/v1')|Out-Null
	$config.AppendChild($add)
	Rename-Item -Path $configpath -NewName ((get-item $configpath).name + ".old")
    $webxml.Save($configpath)
    $flag = 1
    }
}
}
#Edits Storeweb config
    $configpath = "\\" + $server + "\c$\inetpub\wwwroot\Citrix\" + $storename + "Web\web.config"
if (test-path $configpath)
{
    Write-host "Storeweb file found..."
    $webxml = New-Object System.Xml.XmlDocument
    $webxml.Load($configpath)
	$config = $webxml.configuration.'system.webServer'
	if ($config.applicationInitialization)
	{
	Write-Host "Found applicationInitialization" -foregroundcolor green
	}
	else
	{
	Write-Host "Adding applicationInitialization"
	$add = $webxml.CreateElement('applicationInitialization')
	$add.SetAttribute('skipManagedModules','true')|Out-Null
	$config.AppendChild($add)
	$config = $config.applicationInitialization
	$add = $webxml.CreateElement('add')
	$add.SetAttribute('initializationPage','/Home/Index')|Out-Null
	$config.AppendChild($add)
	Rename-Item -Path $configpath -NewName ((get-item $configpath).name + ".old")
    $webxml.Save($configpath)
    $flag = 1
    }

}
}

 if ($flag -eq 1)
 {
 write-host "Restarting IIS..." -foregroundcolor gray
 iisreset $server
 }

}
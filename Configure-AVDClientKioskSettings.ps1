$ErrorActionPreference = 'Stop'

# Remove Windows Default Apps
& ".\Remove-BuiltinApps.ps1"

# Removing any existing shortcuts from the All Users (Public) Desktop and Default User Desktop.
Get-ChildItem -Path "$env:Public\Desktop" -Filter '*.lnk' | Remove-Item -Force
Get-ChildItem -Path "$env:SystemDrive\Users\Default\Desktop" -Filter '*.lnk' | Remove-Item -Force   

# Copy LGPO.exe to system32
Copy-Item -Path ".\Tools\lgpo.exe" -Destination "$env:SystemRoot\System32" -Force

# Apply Non-Admin GPO settings
## Configured basic Explorer settings for kiosk user via Non-Administrators Local Group Policy Object
$null = cmd /c lgpo.exe /t ".\GpoSettings\nonadmins-MultiAppKiosk.txt" '2>&1'

## Restricted Settings App and Control Panel to allow only Display Settings for kiosk user via Non-Administrators Local Group Policy Object
$null = cmd /c lgpo.exe /t ".\GpoSettings\nonadmins-ShowDisplaySettings.txt" '2>&1'

# Configured AVD Feed URL for all users via Local Group Policy Object
$outfile = "$env:Temp\Users-AVDURL.txt"
(Get-Content -Path '.\GpoSettings\users-AutoSubscribe.txt').Replace('<url>', 'https://client.wvd.microsoft.com') | Out-File $outfile
$null = cmd /c lgpo.exe /t "$outfile" '2>&1'

# Set 'Interactive logon: Machine inactivity limit' to '900 seconds' via Local Group Policy Object
$null = cmd /c lgpo /s ".\GpoSettings\MachineInactivityTimeout.inf" '2>&1'

# Load Default User Hive
$null = cmd /c REG LOAD "HKLM\Default" "$env:SystemDrive\Users\default\ntuser.dat" '2>&1'

# Import registry keys file
$RegKeys = Import-Csv -Path '.\RegistryKeys\RegKeys.csv'

# Loop through and set registry settings
foreach ($Entry in $RegKeys) {
    #reset from previous values
    $Key = $null
    $Value = $null
    $Type = $null
    $Data = $null
    #set values
    $Key = $Entry.Key
    $Value = $Entry.Value
    $Type = $Entry.Type
    $Data = $Entry.Data

    if ($Key -like 'HKCU\*') {
        $Key = $Key.Replace("HKCU\","HKLM\Default\")
    }
    
    if ($null -ne $Data -and $Data -ne '') {
        $null = cmd /c REG ADD "$Key" /v $Value /t $Type /d "$Data" /f '2>&1'
    }

    Start-Sleep -Seconds 1
}

# Unload Default User Hive
$null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'

# Applying AppLocker Policy to disable Microsoft Edge, Internet Explorer, Notepad, Windows Search, and Wordpad
Set-AppLockerPolicy -XmlPolicy ".\AppLocker\MultiAppKioskAppLockerPolicy.xml"

# Enabling & Starting Application Identity Service
Set-Service -Name 'AppIDSvc' -StartupType 'Automatic' -ErrorAction 'SilentlyContinue'
if ((Get-Service -Name AppIDSvc).Status -ne 'Running') 
{
    Start-Service -Name 'AppIDSvc'
}

# Configuring Multi-App Kiosk Settings
. ".\Scripts\AssignedAccessWmiBridgeHelpers.ps1"
Set-MultiAppKioskConfiguration -FilePath '.\MultiAppConfigs\MultiAppWithSettings.xml'

# Update Group Policy"
$null = Start-Process -FilePath 'GPUpdate' -ArgumentList '/force' -Wait -PassThru

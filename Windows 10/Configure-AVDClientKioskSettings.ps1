<# 
.SYNOPSIS
    This script creates a custom Remote Desktop client for Windows (AVD Client) kiosk configuration designed to only allow the use of the client.
    It uses a combination of Applocker policies, multi-local group policy settings, Shell Launcher configuration, provisioning packages, and
    registry edits to complete the configuration. There are basically four major options for configuration:

    * Remote Desktop client shell
    * Remote Desktop client shell with autologon
    * Custom Explorer shell
    * Custom Explorer shell with autologon

    These options are controlled by the combination of the two switch parameters - AVDClientShell and Autologon. Additionally, you can choose to

    * Install the latest Remote Desktop client for Windows and Visual C++ Redistributables directly from the web.
    * Apply the latest applicable Security Technical Implementation Guides (STIG) group policy settings into the local group policy object via the
      local group policy object tool. This also applies several delta settings to maintain operability as a kiosk.
    * Monitor for Yubikey authentication device removals and perform the same actions as smart cards such as local computer lock or Remote Desktop
      client reset.

.DESCRIPTION 
    This script completes a series of configuration tasks based on the parameters chosen. These tasks can include:

    * Applocker policy application to block Internet Explorer, Edge, Wordpad, and Notepad
    * Provisioning packages to remove pinned items from the Start Menu for the custom explorer shell option.
    * Multi-Local Group Policy configuration to limit interface elements.
    * Built-in application removal.
    * Shell Launcher configuration in all but the Custom Explorer shell (without autologon)
    * Remote Desktop client for Windows install (if selected)
    * STIG application (if selected)
    * Start Layout modification for the custom explorer shell options
    * Custom Azure Virtual Desktop client shortcuts or shell launcher configuration that launches the Remote Desktop client for Windows
      via a script to enable WMI Event subscription.

.NOTES 
    The script will automatically remove older configurations by running 'Remove-KioskSettings.ps1' during the install process.    

.COMPONENT 
    No PowerShell modules required.

.LINK 
    https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows?tabs=subscribe
    https://learn.microsoft.com/en-us/azure/virtual-desktop/uri-scheme
    https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/applocker/applocker-overview
    https://learn.microsoft.com/en-us/windows/configuration/kiosk-shelllauncher
    https://public.cyber.mil/stigs/gpo/
 

.PARAMETER Version
    This version parameter allows tracking of the installed version using configuration management software such as Microsoft Endpoint Manager or Microsoft Endpoint Configuration Manager by querying the value of the registry value: HKLM\Software\Kiosk\version.

.PARAMETER EnvironmentAVD
This value determines the Azure environment to which you are connecting. It ultimately determines the Url of the Remote Desktop Feed which
varies by environment by setting the $SubscribeUrl variable and replacing placeholders in several files during installation.
The list of Urls can be found at
https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-microsoft-store?source=recommendations#subscribe-to-a-workspace.

.PARAMETER AVDClientShell
This switch parameter determines whether the Windows Shell is replaced by the Remote Desktop client for Windows or remains the default 'explorer.exe'.
When the default 'explorer' shell is used additional local group policy settings and provisioning packages are applied to lock down the shell.

.PARAMETER AutoLogon
This switch parameter determines if autologon is enabled through the Shell Launcher configuration. The Shell Launcher feature will automatically
create a new user - 'KioskUser0' - which will not have a password and be configured to automatically logon when Windows starts.

.PARAMETER SharedPC
This switch parameter determines if the computer is setup as a shared PC. The account management process is enabled and all user profiles are automatically
deleted on logoff.

.PARAMETER InstallAVDClient
This switch parameter determines if the latest Remote Desktop client for Windows is automatically downloaded from the Internet and installed
on the system prior to configuration.

.PARAMETER ShowDisplaySettings
This switch parameter determines if the Settings App and Control Panel are restricted to only allow access to the Display Settings page. If this value is not set,
then the Settings app and Control Panel are not displayed or accessible.

.PARAMETER ApplySTIGs
This switch parameter determines if the latest DoD Security Technical Implementation Guide Group Policy Objects are automatically downloaded
from https://public.cyber.mil/stigs/gpo and applied via the Local Group Policy Object (LGPO) tool to the system. If they are, then several
delta settings are applied to allow the system to communicate with Azure Active Directory and complete autologon (if applicable).

.PARAMETER Yubikey
This switch parameter determines if the WMI Event Subscription Filter also monitors for Yubikey removal.

#>
[CmdletBinding()]
param (
    [version]$Version = '4.6.0',

    [switch]$ApplySTIGs,

    [ValidateSet('AzureCloud','AzureUSGovernment')]
    [string]$EnvironmentAVD = 'AzureUSGovernment',

    [switch]$InstallAVDClient,

    [Parameter(Mandatory, ParameterSetName='AutologonClientShell')]
    [Parameter(Mandatory, ParameterSetName='DirectLogonClientShell')]
    [switch]$AVDClientShell,

    [Parameter(Mandatory, ParameterSetName='AutologonClientShell')]
    [Parameter(Mandatory, ParameterSetName='AutologonExplorerShell')]
    [switch]$AutoLogon,

    [Parameter(ParameterSetName='DirectLogonClientShell')]
    [Parameter(ParameterSetName='DirectLogonExplorerShell')]
    [switch]$SharedPC,

    [Parameter(ParameterSetName='AutologonExplorerShell')]
    [Parameter(ParameterSetName='DirectLogonExplorerShell')]
    [switch]$ShowDisplaySettings,

    [switch]$Yubikey
)

#region Set Variables

$Script:FullName = $MyInvocation.MyCommand.Path
$Script:Dir = Split-Path $Script:FullName
$Script:File = [string]$myInvocation.MyCommand.Name
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($Script:File)
# Log file (.log)
$Script:LogDir = "$env:SystemRoot\Logs\Configuration"
$Script:LogName = "$($Script:Name).log"
# Windows Event Log (.evtx)
$EventLog = 'AVD Client Kiosk'
$EventSource = 'Configuration Script'
# Source Directories and supporting files
$DirAppLocker = "$Script:Dir\AppLocker"
$FileAppLockerKiosk = "$DirAppLocker\AVDClientKioskAppLockerPolicy.xml"
$FileAppLockerClear = "$DirAppLocker\ClearAppLockerPolicy.xml"
$DirProvisioningPackages = "$Script:Dir\ProvisioningPackages"
$DirStartMenu = "$Script:Dir\StartMenu"
$DirShellLauncherSettings = "$Script:Dir\ShellLauncherConfigs"
$DirGPO = "$Script:Dir\GPOSettings"
$DirKiosk = "$env:SystemDrive\KioskSettings"
$DirRegKeys = "$Script:Dir\RegistryKeys"
$FileRegKeys = "$DirRegKeys\RegKeys.csv"
$DirTools = "$Script:Dir\Tools"
$DirUserLogos = "$Script:Dir\UserLogos"
$DirConfigurationScripts = "$Script:Dir\Scripts\Configuration"
$DirSchedTasksScripts = "$Script:Dir\Scripts\ScheduledTasks"
# Find LTSC OS (and Windows IoT Enterprise)
$OS = Get-WmiObject -Class Win32_OperatingSystem
If ($OS.Name -match 'LTSC') {$LTSC = $true}
# Set AVD feed subscription Url.
If ($EnvironmentAVD -eq 'AzureUSGovernment') {
    $SubscribeUrl = 'https://rdweb.wvd.azure.us'
} Else {
    $SubscribeUrl = 'https://client.wvd.microsoft.com'
}
# Detect Wifi Adapter in order to show Wifi Settings in system tray when necessary.
$WifiAdapter = Get-NetAdapter | Where-Object {$_.Name -like '*Wi-Fi*' -or $_.Name -like '*Wifi*' -or $_.MediaType -like '*802.11*'}
# Set default exit code to 0
$ScriptExitCode = 0

#endregion Set Variables

#region Restart Script in 64-bit powershell if necessary

If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    $scriptArguments = $null
    Try {
        foreach($k in $PSBoundParameters.keys)
        {
            switch($PSBoundParameters[$k].GetType().Name)
            {
                "SwitchParameter"   { If($PSBoundParameters[$k].IsPresent) { $scriptArguments += "-$k " } }
                "String"            { If($PSBoundParameters[$k] -match '_') { $scriptArguments += "-$k `"$($PSBoundParameters[$k].Replace('_',' '))`" "} Else { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " } }
                "Int32"             { $scriptArguments += "-$k $($PSBoundParameters[$k]) " }
                "Boolean"           { $scriptArguments += "-$k `$$($PSBoundParameters[$k]) " }
                "Version"           { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " }
            }
        }
        If ($null -ne $scriptArguments) {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`" $scriptArguments" -PassThru -Wait -NoNewWindow
        } Else {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`"" -PassThru -Wait -NoNewWindow
        }
    }
    Catch {
        Throw "Failed to start 64-bit PowerShell"
    }
    Exit $RunScript.ExitCode
}

#endregion Restart Script in 64-bit powershell if necessary

#region Functions

Function Get-PendingReboot {
    <#
    .SYNOPSIS
        Gets the pending reboot status on a local or remote computer.

    .DESCRIPTION
        This function will query the registry on a local or remote computer and determine if the
        system is pending a reboot, from Microsoft updates, Configuration Manager Client SDK, Pending Computer 
        Rename, Domain Join or Pending File Rename Operations. For Windows 2008+ the function will query the 
        CBS registry key as another factor in determining pending reboot state.  "PendingFileRenameOperations" 
        and "Auto Update\RebootRequired" are observed as being consistant across Windows Server 2003 & 2008.
        
        CBServicing = Component Based Servicing (Windows 2008+)
        WindowsUpdate = Windows Update / Auto Update (Windows 2003+)
        CCMClientSDK = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
        PendComputerRename = Detects either a computer rename or domain join operation (Windows 2003+)
        PendFileRename = PendingFileRenameOperations (Windows 2003+)
        PendFileRenVal = PendingFilerenameOperations registry value; used to filter if need be, some Anti-
                        Virus leverage this key for def/dat removal, giving a false positive PendingReboot

    .EXAMPLE
        Get-PendingReboot
        
    .LINK

    .NOTES
    #>
	Try {
	    ## Setting pending values to false to cut down on the number of else statements
        $RebootPending = $false
	    $CompPendRen = $false
        $PendFileRename = $false
        $SCCM = $false

	    ## Setting CBSRebootPend to null since not all versions of Windows has this value
	    $CBSRebootPend = $null

	    ## Making registry connection to the local/remote computer
	    $HKLM = [UInt32] "0x80000002"
	    $WMI_Reg = [WMIClass] "\\.\root\default:StdRegProv"
						
	    ## query the CBS Reg Key
	    
		$RegSubKeysCBS = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\")
		$CBSRebootPend = $RegSubKeysCBS.sNames -contains "RebootPending"		
	    							
	    ## Query WUAU from the registry
	    $RegWUAURebootReq = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
	    $WUAURebootReq = $RegWUAURebootReq.sNames -contains "RebootRequired"
						
	    ## Query PendingFileRenameOperations from the registry
	    $RegSubKeySM = $WMI_Reg.GetMultiStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\Session Manager\","PendingFileRenameOperations")
	    $RegValuePFRO = $RegSubKeySM.sValue

	    ## Query JoinDomain key from the registry - These keys are present if pending a reboot from a domain join operation
	    $Netlogon = $WMI_Reg.EnumKey($HKLM,"SYSTEM\CurrentControlSet\Services\Netlogon").sNames
	    $PendDomJoin = ($Netlogon -contains 'JoinDomain') -or ($Netlogon -contains 'AvoidSpnSet')

	    ## Query ComputerName and ActiveComputerName from the registry
	    $ActCompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\","ComputerName")            
	    $CompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\","ComputerName")

	    If (($ActCompNm -ne $CompNm) -or $PendDomJoin) {
	        $CompPendRen = $true
	    }
						
	    ## If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
	    If ($RegValuePFRO) {
		    $PendFileRename = $true
	    }

	    ## Determine SCCM 2012 Client Reboot Pending Status
	    ## To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
        
	    ## Try CCMClientSDK
	    Try {
	        $CCMClientSDK = Invoke-WmiMethod -ComputerName LocalHost -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -Name DetermineIfRebootPending -ErrorAction 'Stop'
	    } Catch {
	        $CCMClientSDK = $null
	    }

	    If ($CCMClientSDK) {
	        If ($CCMClientSDK.ReturnValue -ne 0) {
		        Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"          
		    }
		    If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending) {
		        $SCCM = $true
		    }
	    } Else {
	        $SCCM = $False
	    }
	    If ($CompPendRen -or $CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename) { $RebootPending = $true }
        Return $RebootPending

	} Catch {
	    Write-Warning "$_"				
	}						
}

function Update-ACL {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Path,
        [Parameter(Mandatory=$true)]
        $Identity,
        [Parameter(Mandatory=$true)]
        $FileSystemRights,
        $InheritanceFlags = 'ContainerInherit,ObjectInherit',
        $PropogationFlags = 'None',
        [Parameter(Mandatory)]
        [ValidateSet('Allow','Deny')]
        $Type
    )

   If (Test-Path $Path) {
        $NewAcl = Get-ACL -Path $Path
        $FileSystemAccessRuleArgumentList = $Identity, $FileSystemRights, $InheritanceFlags, $PropogationFlags, $type
        $FileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $FileSystemAccessRuleArgumentList
        $NewAcl.SetAccessRule($FileSystemAccessRule)
        Set-Acl -Path "$Path" -AclObject $NewAcl
    }
}

function Update-ACLInheritance {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$Path,
        [Parameter(Mandatory=$false,
                   Position=1)]
        [bool]$DisableInheritance = $false,

        [Parameter(Mandatory=$true,
                   Position=2)]
        [bool]$PreserveInheritedACEs = $true
    )

    If (Test-Path $Path) {
        $NewACL = Get-Acl -Path $Path
        $NewACL.SetAccessRuleProtection($DisableInheritance, $PreserveInheritedACEs)
        Set-ACL -Path $Path -AclObject $NewACL
    }

}

Function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $EventLog = $EventLog,
        [Parameter()]
        [string]
        $EventSource = $EventSource,
        [Parameter()]
        [string]
        [ValidateSet('Information','Warning','Error')]
        $EntryType = 'Information',
        [Parameter()]
        [Int]
        $EventID,
        [Parameter()]
        [string]
        $Message
    )
    If ($EntryType -eq 'Error') {
        Write-Error $Message
    } Elseif ($EntryType -eq 'Warning') {
        Write-Warning -Message $Message
    } Else {
        Write-Output $Message
    }
    Write-EventLog -LogName $EventLog -Source $EventSource -EntryType $EntryType -EventId $EventId -Message $Message -ErrorAction SilentlyContinue
}

#endregion Functions

#region Initialization
New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue

If (-not (Test-Path $Script:LogDir)) {
    $null = New-Item -Path $Script:LogDir -ItemType Directory -Force
}
Start-Transcript -Path "$Script:LogDir\$Script:LogName" -Force

Write-Log -EntryType Information -EventId 1 -Message "Executing '$Script:FullName'."

If (Get-PendingReboot) {
    Write-Log -EntryType Error -EventId 0 -Message "There is a reboot pending. This application cannot be installed when a reboot is pending.`nRebooting the computer in 15 seconds."
    Stop-Transcript
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 15'
    Exit 1618
}

# Copy lgpo to system32 for future use.
Copy-Item -Path "$DirTools\lgpo.exe" -Destination "$env:SystemRoot\System32" -Force

# Enable the Scheduled Task History by enabling the TaskScheduler operational log
$TaskschdLog = Get-WinEvent -ListLog Microsoft-Windows-TaskScheduler/Operational
$TaskschdLog.IsEnabled = $True
$TaskschdLog.SaveChanges()

#endregion

#region Remove Previous Versions

# Run Removal Script first in the event that a previous version is installed or in the event of a failed installation.
Write-Log -EntryType Information -EventId 3 -Message 'Running removal script in case of previous installs or failures.'
& "$Script:Dir\Remove-KioskSettings.ps1" -Reinstall

#endregion Previous Version Removal

#region Remove Apps

# Remove Built-in Windows 10 Apps on non LTSC builds of Windows
If (!$LTSC) {
    Write-Log -EntryType Information -EventId 25 -Message "Starting Remove Apps Script."
    & "$DirConfigurationScripts\Remove-BuiltinApps.ps1"
}
# Remove OneDrive
If (Test-Path -Path "$env:SystemRoot\Syswow64\onedrivesetup.exe") {
    Write-Log -EntryType Information -EventId 26 -Message "Removing Per-User installation of OneDrive."
    Start-Process -FilePath "$env:SystemRoot\Syswow64\onedrivesetup.exe" -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
} ElseIf (Test-Path -Path "$env:ProgramFiles\Microsoft OneDrive") {
    Write-Log -EntryType Information -EventId 26 -Message "Removing Per-Machine Installation of OneDrive."
    $OneDriveSetup = Get-ChildItem -Path "$env:ProgramFiles\Microsoft OneDrive" -Filter 'onedrivesetup.exe' -Recurse
    If ($OneDriveSetup) {
        Start-Process -FilePath $OneDriveSetup[0].FullName -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
    }
}

#endregion Remove Apps

#region STIGs

If ($ApplySTIGs) {
    Write-Log -EntryType Information -EventId 27 -Message "Running Script to apply the latest STIG group policy settings via LGPO for Windows 10, Internet Explorer, Microsoft Edge, Windows Firewall, and Defender AntiVirus."
    & "$DirConfigurationScripts\Apply-LatestSTIGs.ps1"
    If ($AutoLogon) {
        # Remove Logon Banner
        Write-Log -EntryType Information -EventId 28 -Message "Running Script to remove the logon banner because this is an autologon kiosk."
        & "$DirConfigurationScripts\Apply-STIGAutoLogonExceptions.ps1"
    } Else {        
        Write-Log -EntryType Information -EventId 28 -Message "Running Script to allow PKU2U online identities required for AAD logon."
        & "$DirConfigurationScripts\Apply-STIGDirectSignOnExceptions.ps1"
    }
}

#endregion STIGs

#region Install AVD Client

# Install AVD Client if parameter is set

If ($installAVDClient) {
    Write-Log -EntryType Information -EventID 30 -Message "Running Script to install or update Visual C++ Redistributables."
    & "$DirConfigurationScripts\Install-VisualC++Redistributables.ps1"
    Write-Log -EntryType Information -EventId 31 -Message "Running Script to install or update AVD Client."
    & "$DirConfigurationScripts\Install-AVDClient.ps1"
}

#endregion

#region KioskSettings Directory

#Create the KioskSettings Directory
Write-Log -EntryType Information -EventId 40 -Message "Creating KioskSettings Directory at root of system drive."
If (-not (Test-Path $DirKiosk)) {
    New-Item -Path $DirKiosk -ItemType Directory -Force | Out-Null
}

# Setting ACLs on the Kiosk Settings directory to prevent Non-Administrators from changing files. Defense in Depth.
Write-Log -EntryType Information -EventId 41 -Message "Configuring Kiosk Directory ACLs"
$Group = New-Object System.Security.Principal.NTAccount("Builtin", "Administrators")
$ACL = Get-ACL $DirKiosk
$ACL.SetOwner($Group)
Set-ACL -Path $DirKiosk -AclObject $ACL
Update-ACL -Path $DirKiosk -Identity 'BuiltIn\Administrators' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'BuiltIn\Users' -FileSystemRights 'ReadAndExecute' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'System' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACLInheritance -Path $DirKiosk -DisableInheritance $true -PreserveInheritedACEs $false

# Copy Client Launch Scripts.
Write-Log -EntryType Information -EventId 42 -Message "Copying Launch AVD Client Scripts from '$DirConfigurationScripts' to '$DirKiosk'"
Copy-Item -Path "$DirConfigurationScripts\Launch-AVDClient.ps1" -Destination $DirKiosk -Force
Copy-Item -Path "$DirConfigurationScripts\Launch-AVDClient.vbs" -Destination $DirKiosk -Force
# dynamically update parameters of launch script.
$FileToUpdate = "$DirKiosk\Launch-AVDClient.ps1"
$Content = Get-Content -Path $FileToUpdate
$Content = $Content.Replace('<SubscribeUrl>', $SubscribeUrl)
If ($Yubikey) { $Content = $Content.Replace('$Yubikey = $false', '$Yubikey = $true') }
If ($AutoLogon) { $Content = $Content.Replace('$AutoLogon = $false', '$AutoLogon = $true') }
$Content | Set-Content -Path $FileToUpdate

$SchedTasksScriptsDir = Join-Path -Path $DirKiosk -ChildPath 'ScheduledTasks'
If (-not (Test-Path $SchedTasksScriptsDir)) {
    $null = New-Item -Path $SchedTasksScriptsDir -ItemType Directory -Force
}
Write-Log -EntryType Information -EventId 43 -Message "Copying Scheduled Task Scripts from '$DirSchedTasksScripts' to '$SchedTasksScriptsDir'"
Get-ChildItem -Path $DirSchedTasksScripts -filter '*.*' | Copy-Item -Destination $SchedTasksScriptsDir -Force

#endregion KioskSettings Directory

#region Provisioning Packages

$ProvisioningPackages = @()
If ($SharedPC) {
    Write-Log -EntryType Information -EventId 44 -Message "Installing Provisioning Package to enable SharedPC mode"
    $ProvisioningPackages += (Get-ChildItem -Path $DirProvisioningPackages | Where-Object {$_.Name -like '*SharedPC*'}).FullName
}
If (-not $AVDClientShell) {
    # Installing provisioning packages. Currently only one is included to hide the pinned items on the left of the Start Menu.
    # No GPO settings are available to do this.
    Write-Log -EntryType Information -EventId 45 -Message "Installing Provisioning Package to remove pinned items from Start Menu"
    $ProvisioningPackages += (Get-ChildItem -Path $DirProvisioningPackages | Where-Object {$_.Name -like '*PinnedFolders*'}).FullName
    If (!$ShowDisplaySettings) {
        $ProvisioningPackages += (Get-ChildItem -Path $DirProvisioningPackages | Where-Object {$_.Name -like '*Settings*'}).FullName
    }
    If ($AutoLogon) {
        $ProvisioningPackages += (Get-ChildItem -Path $DirProvisioningPackages | Where-Object {$_.Name -like '*Autologon*'}).FullName
    } 
    New-Item -Path "$DirKiosk\ProvisioningPackages" -ItemType Directory -Force | Out-Null
    ForEach ($Package in $ProvisioningPackages) {
        Copy-Item -Path $Package -Destination "$DirKiosk\ProvisioningPackages" -Force
        Write-Log -EntryType Information -EventID 46 -Message "Installing $($Package)."
        Install-ProvisioningPackage -PackagePath $Package -ForceInstall -QuietInstall
    }
}

#endregion Provisioning Packages

#region Start Menu

If (-not ($AVDClientShell)) {
    # Create custom Remote Desktop Client shortcut and configure custom start menu for Non-Admins
    Write-Log -EntryType Information -EventId 47 -Message "Removing any existing shortcuts from the All Users (Public) Desktop and Default User Desktop."
    Get-ChildItem -Path "$env:Public\Desktop" -Filter '*.lnk' | Remove-Item -Force
    Get-ChildItem -Path "$env:SystemDrive\Users\Default\Desktop" -Filter '*.lnk' | Remove-Item -Force
    Write-Log -EntryType Information -EventId 48 -Message "Copying Start Menu Layout file for Non Admins to '$DirKiosk' directory."
    Copy-Item -Path "$DirStartMenu\startlayout.xml" -Destination "$DirKiosk\startlayout.xml" -Force
    Write-Log -EntryType Information -EventId 49 -Message "Creating a custom AVD Shortcut in Start Menu."
    [string]$StringVersion = $Version
    $ObjShell = New-Object -ComObject WScript.Shell
    $DirsShortcuts = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    $LinkRemoteDesktop = "Remote Desktop.lnk"
    $PathLinkRD = Join-Path $DirsShortcuts[0] -ChildPath $LinkRemoteDesktop
    $LocationIcon = $ObjShell.CreateShortcut($PathLinkRD).IconLocation
    $LinkAVD = "Azure Virtual Desktop.lnk"

    ForEach($DirShortcut in $DirsShortcuts) {
        $PathLinkAVD = Join-Path $DirShortcut -ChildPath $LinkAVD
        $Shortcut = $ObjShell.CreateShortcut($PathLinkAVD)
        #Set values
        $Shortcut.TargetPath = "wscript.exe"
        $Shortcut.Arguments = "`"$env:SystemDrive\KioskSettings\Launch-AVDClient.vbs`""
        $Shortcut.WorkingDirectory = "$env:ProgramFiles\Remote Desktop"
        $Shortcut.Description = "Launches Remote Desktop Client and logon prompt. Kiosk Configuration Version: $StringVersion"
        $Shortcut.IconLocation = $LocationIcon
        $Shortcut.Save()
    }

    $dirStartup = "$env:SystemDrive\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
    If (-not (Test-Path -Path $dirStartup)) {
        $null = New-Item -Path $dirStartup -ItemType Directory -Force
    }
    Copy-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$LinkAVD" -Destination $dirStartup -Force

    If ($AutoLogon) {
        $TaskName = "(AVD Client) - Hide KioskUser0 Start Button Context Menu"
        Write-Log -EntryType Information -EventId 50 -Message "Creating Scheduled Task: '$TaskName'."
        $TaskScriptEventSource = 'Hide Start Button Context Menu'
        $TaskDescription = "Hide Start Button Right Click Menu"
        $TaskScriptName = 'Hide-StartButtonRightClickMenu.ps1'
        $TaskScriptFullName = Join-Path -Path $SchedTasksScriptsDir -ChildPath $TaskScriptName
        New-EventLog -LogName $EventLog -Source $TaskScriptEventSource -ErrorAction SilentlyContinue   
        $TaskTrigger = New-ScheduledTaskTrigger -AtLogOn -User KioskUser0
        $TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-executionpolicy bypass -file $TaskScriptFullName -TaskName `"$TaskName`" -EventLog `"$EventLog`" -EventSource `"$TaskScriptEventSource`" -AutoLogonUser `"KioskUser0`""
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $TaskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries
        Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $TaskAction -Settings $TaskSettings -Principal $TaskPrincipal -Trigger $TaskTrigger
        If (Get-ScheduledTask | Where-Object {$_.TaskName -eq "$TaskName"}) {
            Write-Log -EntryType Information -EventId 51 -Message "Scheduled Task created successfully."
        } Else {
            Write-Log -EntryType Error -EventId 52 -Message "Scheduled Task not created."
            $ScriptExitCode = 1618
        }
    } Else {
        Write-Log -EntryType Information -EventId 53 -Message "Disabling the Start Button Right Click Menu for all users."
        # Set Default profile to hide Start Menu Right click
        $Groups = @(
            "Group1",
            "Group2",
            "Group3"
        )
        $WinXRoot = "$env:SystemDrive\Users\Default\Appdata\local\Microsoft\Windows\WinX\{0}"
        foreach ($grp in $Groups) { 
            $HideDir = Get-ItemProperty -Path ($WinXRoot -f $grp )
            $HideDir.Attributes = [System.IO.FileAttributes]::Hidden
        }
    }
}

#endregion Start Menu

#region User Logos

$null = cmd /c lgpo.exe /t "$DirGPO\computer-userlogos.txt" '2>&1'
Write-Log -EntryType Information -EventId 55 -Message "Configured User Logos to use default via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
Write-Log -EntryType Information -EventId 56 -Message "Backing up current User Logo files to '$DirKiosk\UserLogos'."
Copy-Item -Path "$env:ProgramData\Microsoft\User Account Pictures" -Destination "$DirKiosk\UserLogos" -Force
Write-Log -EntryType Information -EventId 57 -Message "Copying User Logo files to '$env:ProgramData\Microsoft\User Account Pictures'."
Get-ChildItem -Path $DirUserLogos | Copy-Item -Destination "$env:ProgramData\Microsoft\User Account Pictures" -Force

#endregion User Logos

#region Local GPO Settings

# Apply Non-Admin GPO settings
If ($AVDClientShell) {
    $nonAdminsFile = 'nonadmins-AVDClientShell.txt'
    $null = cmd /c lgpo.exe /t "$DirGPO\$nonAdminsFile" '2>&1'
    Write-Log -EntryType Information -EventId 60 -Message "Configured basic Explorer settings for kiosk user via Non-Administrators Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
} Else {
    $nonAdminsFile = 'nonadmins-ExplorerShell.txt'
    $null = cmd /c lgpo.exe /t "$DirGPO\$nonAdminsFile" '2>&1'
    Write-Log -EntryType Information -EventId 60 -Message "Configured basic Explorer settings for kiosk user via Non-Administrators Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"

    if ($ShowDisplaySettings) {
        $null = cmd /c lgpo.exe /t "$DirGPO\nonadmins-ShowDisplaySettings.txt" '2>&1'
        Write-Log -EntryType Information -EventId 61 -Message "Restricted Settings App and Control Panel to allow only Display Settings for kiosk user via Non-Administrators Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
    } Else {
        $null = cmd /c lgpo.exe /t "$DirGPO\nonadmins-HideSettings.txt" '2>&1'
        Write-Log -EntryType Information -EventId 61 -Message "Hid Settings App and Control Panel for kiosk user via Non-Administrators Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
}

# Hide Taskbar Tray if no Wifi Adapter Present.
If (!$WifiAdapter) {
    $null = cmd /c lgpo.exe /t "$DirGPO\nonadmins-noWifi.txt" '2>&1'
    Write-Log -EntryType Information -EventId 65 -Message "No Wi-Fi Adapter Present. Disabled TaskBar tray area via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"    
}

# Configure Feed URL for all Users
$outfile = "$env:Temp\Users-AVDFeedURL.txt"
(Get-Content -Path "$DirGPO\users-AVDFeedUrl.txt").Replace('<url>', $SubscribeUrl) | Out-File $outfile
$null = cmd /c lgpo.exe /t "$outfile" '2>&1'
Write-Log -EntryType Information -EventId 70 -Message "Configured AVD Feed URL for all users via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"

# Disable Cortana, Search, Feeds, Logon Animations, and Edge Shortcuts. These are computer settings only.
$null = cmd /c lgpo.exe /t "$DirGPO\Computer.txt" '2>&1'
Write-Log -EntryType Information -EventId 75 -Message "Disabled Cortana search, feeds, login animations, and Edge desktop shortcuts via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"

If ($AutoLogon) {
    # Disable Password requirement for screen saver lock and wake from sleep.
    $null = cmd /c lgpo.exe /t "$DirGPO\disablePasswordForUnlock.txt" '2>&1'
    Write-Log -EntryType Information -EventId 80 -Message "Disabled password requirement for screen saver lock and wake from sleep via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
    $null = cmd /c lgpo.exe /t "$DirGPO\nonadmins-autologon.txt" '2>&1'
    Write-Log -EntryType Information -EventId 81 -Message "Removed logoff, change password, lock workstation, and fast user switching entry points. `nlgpo.exe Exit Code: [$LastExitCode]"
} Else {
    If (!$Yubikey) {
        $null = cmd /c lgpo /s "$DirGPO\SmartCardLockWorkstation.inf" '2>&1'
        Write-Log -EntryType Information -EventId 82 -Message "Set 'Interactive logon: Smart Card Removal behavior' to 'Lock Workstation' via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
    $null = cmd /c lgpo /s "$DirGPO\MachineInactivityTimeout.inf" '2>&1'
    Write-Log -EntryType Information -EventId 83 -Message "Set 'Interactive logon: Machine inactivity limit' to '900 seconds' via Local Group Policy Object.`nlgpo.exe Exit Code: [$LastExitCode]"
}

#endregion Local GPO Settings

#region Registry Edits

# update the Default User Hive to Hide the search button and task view icons on the taskbar.
$null = cmd /c REG LOAD "HKLM\Default" "$env:SystemDrive\Users\default\ntuser.dat" '2>&1'
Write-Log -EntryType Information -EventId 95 -Message "Loaded Default User Hive Registry Keys via Reg.exe.`nReg.exe Exit Code: [$LastExitCode]"

# Import registry keys file
Write-Log -EntryType Information -EventId 96 -Message "Loading Registry Keys from CSV file for modification of default user hive."
$RegKeys = Import-Csv -Path $FileRegKeys

# create the reg key restore file if it doesn't exist, else load it to compare for appending new rows.
Write-Log -EntryType Information -EventId 97 -Message "Creating a Registry key restore file for Kiosk Mode uninstall."
$FileRestore = "$DirKiosk\RegKeyRestore.csv"
New-Item -Path $FileRestore -ItemType File -Force | Out-Null
Add-Content -Path $FileRestore -Value 'Key,Value,Type,Data,Description'

# Loop through the registry key file and perform actions.
ForEach ($Entry in $RegKeys) {
    #reset from previous values
    $Key = $null
    $Value = $null
    $Type = $null
    $Data = $null
    $Description = $Null
    #set values
    $Key = $Entry.Key
    $Value = $Entry.Value
    $Type = $Entry.Type
    $Data = $Entry.Data
    $Description = $Entry.Description
    Write-Log -EntryType Information -EventId 99 -Message "Processing Registry Value to '$Description'."

    If ($Key -like 'HKCU\*') {
        $Key = $Key.Replace("HKCU\","HKLM\Default\")
    }
    
    If ($null -ne $Data -and $Data -ne '') {
        # Output the Registry Key and value name to the restore csv so it can be deleted on restore.
        Add-Content -Path $FileRestore -Value "$Key,$Value,,"        
        $null = cmd /c REG ADD "$Key" /v $Value /t $Type /d "$Data" /f '2>&1'
        Write-Log -EntryType Information -EventId 100 -Message "Added '$Type' Value '$Value' with Value '$Data' to '$Key' with reg.exe.`nReg.exe Exit Code: [$LastExitCode]"
    }
    Else {
        # This is a delete action
        # Get the current value so we can restore it later if needed.
        $keyTemp = $Key.Replace("HKLM\","HKLM:\")
        If (Get-ItemProperty -Path "$keyTemp" -Name "$Value" -ErrorAction SilentlyContinue) {
            $CurrentRegValue = Get-ItemPropertyValue -Path "$keyTemp" -Name $Value
            If ($CurrentRegValue) {
                Add-Content -Path $FileRestore -Value "$Key,$Value,$type,$CurrentRegValue"        
                Write-Log -EntryType Information -EventId 101 -Message "Stored '$Type' Value '$Value' with value '$CurrentRegValue' to '$Key' to Restore CSV file."
                $null = cmd /c REG DELETE "$Key" /v $Value /f '2>&1'
                Write-Log -EntryType Information -EventId 102 -Message "REG command to delete '$Value' from '$Key' exited with exit code: [$LastExitCode]."
            }
        }        
    }
}
Write-Log -EntryType Information -EventId 105 -Message "Unloading default user hive."
$null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
If ($LastExitCode -ne 0) {
    # sometimes the registry doesn't unload properly so we have to perform powershell garbage collection first.
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 5
    $null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
    If ($LastExitCode -eq 0) {
        Write-Log -EntryType Information -EventId 106 -Message "Hive unloaded successfully."
    }
    Else {
        Write-Log -EntryType Error -EventId 107 -Message "Default User hive unloaded with exit code [$LastExitCode]."
    }
} Else {
    Write-Log -EntryType Information -EventId 106 -Message "Hive unloaded successfully."
}

#endregion Registry Edits

#region Applocker Policy 

Write-Log -EntryType Information -EventId 110 -Message "Applying AppLocker Policy to disable Microsoft Edge, Internet Explorer, Notepad, Windows Search, and Wordpad for the Kiosk User."
# If there is an existing applocker policy, back it up and store its XML for restore.
# Else, copy a blank policy to the restore location.
# Then apply the new AppLocker Policy
[xml]$Policy = Get-ApplockerPolicy -Local -XML
If ($Policy.AppLockerPolicy.RuleCollection) {
    Get-ApplockerPolicy -Local -XML | out-file "$DirKiosk\ApplockerPolicy.xml" -force
}
Else {
    Copy-Item "$FileAppLockerClear" -Destination "$DirKiosk\ApplockerPolicy.xml" -Force
}
Set-AppLockerPolicy -XmlPolicy "$FileAppLockerKiosk"
Write-Log -EntryType Information -EventId 111 -Message "Enabling and Starting Application Identity Service"
Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction SilentlyContinue
# Start the service if not already running
If ((Get-Service -Name AppIDSvc).Status -ne 'Running') {
    Start-Service -Name AppIDSvc
}

#endregion Applocker Policy

#region Shell Launcher

If ($AutoLogon -or $AVDClientShell) {
    Write-Log -EntryType Information -EventId 113 -Message "Starting Shell Launcher Configuration Section."
    . "$DirConfigurationScripts\ShellLauncherWmiBridgeHelpers.ps1"
    If ($AutoLogon -and $AVDClientShell) {
        $configFile = "$DirShellLauncherSettings\embeddedShell_avdclient_autologon.xml"
        Write-Log -EntryType Information -EventId 114 -Message "Enabling AVD Client Shell Launcher Settings with Autologon via WMI MDM bridge."
    } Elseif ($AVDClientShell) {
        $configFile = "$DirShellLauncherSettings\embeddedShell_avdclient.xml"
        Write-Log -EntryType Information -EventId 114 -Message "Enabling AVD Client Shell Launcher Settings via WMI MDM bridge."
    } Else {
        $configFile = "$DirShellLauncherSettings\embeddedShell_explorer_autoLogon.xml"
        Write-Log -EntryType Information -EventID 114 -Message "Enabling Explorer Shell Launcher Settings with Autologon via the WMI MDM bridge."
    }

    $ShellLauncherFile = Join-Path -Path $DirKiosk -ChildPath "ShellLauncher.xml"
    Copy-Item -Path $configFile -Destination $ShellLauncherFile -Force

    Set-ShellLauncherBridgeWMI -FilePath "$DirKiosk\ShellLauncher.xml"
    If (Get-ShellLauncherBridgeWMI) {
        Write-Log -EntryType Information -EventId 115 -Message "Shell Launcher configuration successfully applied."
    } Else {
        Write-Log -EntryType Error -EventId 116 -Message "Shell Launcher configuration failed. Computer should be restarted first."
        Stop-Transcript
        Exit 1
    }
}

#endregion Shell Launcher

#region Keyboard Filter

Write-Log -EntryType Information -EventID 117 -Message "Enabling Keyboard filter."
Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart

# Configure Keyboard Filter after reboot
$TaskName = "(AVD Client) - Configure Keyboard Filter"
Write-Log -EntryType Information -EventId 118 -Message "Creating Scheduled Task: '$TaskName'."
$TaskScriptEventSource = 'Keyboard Filter Configuration'
$TaskDescription = "Configures the Keyboard Filter"
$TaskScriptName = 'Set-KeyboardFilterConfiguration.ps1'
$TaskScriptFullName = Join-Path -Path $SchedTasksScriptsDir -ChildPath $TaskScriptName
New-EventLog -LogName $EventLog -Source $TaskScriptEventSource -ErrorAction SilentlyContinue     
$TaskTrigger = New-ScheduledTaskTrigger -AtStartup
$TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-executionpolicy bypass -file $TaskScriptFullName -TaskName `"$TaskName`" -EventLog `"$EventLog`" -EventSource `"$TaskScriptEventSource`""
$TaskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$TaskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $TaskAction -Settings $TaskSettings -Principal $TaskPrincipal -Trigger $TaskTrigger
If (Get-ScheduledTask | Where-Object {$_.TaskName -eq "$TaskName"}) {
    Write-Log -EntryType Information -EventId 119 -Message "Scheduled Task created successfully."
} Else {
    Write-Log -EntryType Error -EventId 120 -Message "Scheduled Task not created."
    $ScriptExitCode = 1618
}

#endregion Keyboard Filter

#region Prevent Microsoft AAD Broker Timeout

If ($AutoLogon) {
    $TaskName = "(AVD Client) - Restart AAD Sign-in"
    $TaskDescription = 'Restarts the AAD Sign-in process if there are no active connections to prevent a stale sign-in attempt.'
    Write-Log -EntryType Information -EventId 135 -Message "Creating Scheduled Task: '$TaskName'."
    $TaskScriptEventSource = 'AAD Sign-in Restart'
    New-EventLog -LogName $EventLog -Source $TaskScriptEventSource -ErrorAction SilentlyContinue
    $TaskTrigger = New-ScheduledTaskTrigger -AtLogOn -User KioskUser0
    $TaskTrigger.Delay = 'PT15M'
    $TaskTrigger.Repetition = (New-ScheduledTaskTrigger -Once -At "12:00 AM" -RepetitionInterval (New-TimeSpan -Minutes 15)).Repetition
    $TaskAction = New-ScheduledTaskAction -Execute "wscript.exe" `
        -Argument "$SchedTasksScriptsDir\Restart-AADSignIn.vbs"
    # Set up scheduled task to run interactively (only when user is logged in)
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId KioskUser0 -LogonType Interactive
    $TaskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -Compatibility Win8 -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Description $TaskDescription -Principal $TaskPrincipal -Settings $TaskSettings -Trigger $TaskTrigger
    If (Get-ScheduledTask | Where-Object {$_.TaskName -eq "$TaskName"}) {
        Write-Log -EntryType Information -EventId 119 -Message "Scheduled Task created successfully."
    } Else {
        Write-Log -EntryType Error -EventId 120 -Message "Scheduled Task not created."
        $ScriptExitCode = 1618
    }
}

#endregion Prevent Microsoft AAD Broker Timeout

If ($ScriptExitCode -eq 1618) {
    Write-Log -EntryType Error -EventId 135 -Message "At least one critical failure occurred. Exiting Script and restarting computer."
    Stop-Transcript
    Restart-Computer -Force
} Else {
    $ScriptExitCode -eq 1641
}

Write-Log -EntryType Information -EventId 150 -Message "Updating Group Policy"
$gpupdate = Start-Process -FilePath 'GPUpdate' -ArgumentList '/force' -Wait -PassThru
Write-Log -EntryType Information -EventID 151 -Message "GPUpdate Exit Code: [$($GPUpdate.ExitCode)]"
$null = cmd /c reg add 'HKLM\Software\Kiosk' /v Version /d "$($version.ToString())" /t REG_SZ /f
Write-Log -EntryType Information -EventId 199 -Message "Ending Kiosk Mode Configuration version '$($version.ToString())' with Exit Code: $ScriptExitCode"
Stop-Transcript
Exit $ScriptExitCode
#endregion Main Script
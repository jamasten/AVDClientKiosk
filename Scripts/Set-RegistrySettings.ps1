$Settings = @(

    # Disable Search from Task Bar
    [PSCustomObject]@{
        Name = 'SearchBoxTaskBarMode'
        Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Task View Button on Task Bar
    [PSCustomObject]@{
        Name = 'ShowTaskViewButton'
        Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Ink Workspace on Task Bar
    [PSCustomObject]@{
        Name = 'PenWorkspaceButtonDesiredVisibility'
        Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\PenWorkspace'
        PropertyType = 'DWord'
        Value = 0
    },

    # Remove OneDriveSetup from starting for each user
    [PSCustomObject]@{
        Name = 'OneDriveSetup'
        Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
        PropertyType = 'String'
        Value = ''
    },

    # Disable Remote Desktop client telemetry data
    [PSCustomObject]@{
        Name = 'EnableMSRDCTelemetry'
        Path = 'HKCU\Software\Microsoft\RDclientRadc'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Updates and Notifications in Remote Desktop Client application
    [PSCustomObject]@{
        Name = 'AutomaticUpdates'
        Path = 'HKLM:\SOFTWARE\Microsoft\MSRDC\Policies'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Sleep in Power Options
    [PSCustomObject]@{
        Name = 'ShowSleepOption'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Hibernate in Power Options
    [PSCustomObject]@{
        Name = 'ShowHibernateOption'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Lock in Power Options
    [PSCustomObject]@{
        Name = 'ShowLockOption'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable 'Stay Signed in to all your apps' pop-up
    [PSCustomObject]@{
        Name = 'BlockAADWorkplaceJoin'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
        PropertyType = 'DWord'
        Value = 1
    },

    # Disable the Windows Security system tray icon
    [PSCustomObject]@{
        Name = 'SecurityHealth'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        PropertyType = 'MultiString'
        Value = ''
    },

    # Apply the default account picture to all users
    [PSCustomObject]@{
        Name = 'UseDefaultTile'
        Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        PropertyType = 'DWord'
        Value = 1
    },

    # Hide first sign-in animation
    [PSCustomObject]@{
        Name = 'EnableFirstLogonAnimation'
        Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable widgets
    [PSCustomObject]@{
        Name = 'AllowNewsAndInterests'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        PropertyType = 'DWord'
        Value = 0
    },

    # Create Desktop Shortcut upon install default
    [PSCustomObject]@{
        Name = 'CreateDesktopShortcutDefault'
        Path = 'HKLM:\Software\Policies\Microsoft\EdgeUpdate'
        PropertyType = 'DWord'
        Value = 0
    },

    # Remove Desktop Shortcut upon update default
    [PSCustomObject]@{
        Name = 'RemoveDesktopShortcutDefault'
        Path = 'HKLM:\Software\Policies\Microsoft\EdgeUpdate'
        PropertyType = 'DWord'
        Value = 1
    },

    # Turn off Microsoft consumer experiences
    [PSCustomObject]@{
        Name = 'DisableWindowsConsumerFeatures'
        Path = 'HKLM:\Software\Policies\Microsoft\Windows\CloudContent'
        PropertyType = 'DWord'
        Value = 1
    },

    # Remove Recommended section from Start Menu
    [PSCustomObject]@{
        Name = 'HideRecommendedSection'
        Path = 'HKCU\Software\Policies\Microsoft\Windows\Explorer'
        PropertyType = 'DWord'
        Value = 1
    },

    # Don't launch privacy settings experience on user logon
    [PSCustomObject]@{
        Name = 'DisablePrivacyExperience'
        Path = 'HKCU\Software\Policies\Microsoft\Windows\OOBE'
        PropertyType = 'DWord'
        Value = 1
    },

    # Disable cross-device experiences on this device
    [PSCustomObject]@{
        Name = 'EnableCdp'
        Path = 'HKLM:\Software\Policies\Microsoft\Windows\System'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable new and interests on the taskbar
    [PSCustomObject]@{
        Name = 'EnableFeeds'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Cortana
    [PSCustomObject]@{
        Name = 'AllowCortana'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable Cortana above lock screen
    [PSCustomObject]@{
        Name = 'AllowCortanaAboveLock'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        PropertyType = 'DWord'
        Value = 0
    },

    # Disable search and Cortana to use location
    [PSCustomObject]@{
        Name = 'AllowSearchToUseLocation'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        PropertyType = 'DWord'
        Value = 0
    },

    # Fully disable Search UI
    [PSCustomObject]@{
        Name = 'DisableSearch'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        PropertyType = 'DWord'
        Value = 1
    },

    # Hide search on the taskbar
    [PSCustomObject]@{
        Name = 'SearchOnTaskbarMode'
        Path = 'HKLM:\Software\Policies\Microsoft\Windows\Windows Search'
        PropertyType = 'DWord'
        Value = 0
    },

    # Do not allow applications to prevent automatic sleep (plugged in)
    [PSCustomObject]@{
        Name = 'ACSettingIndex'
        Path = 'HKLM:\Software\Policies\Microsoft\Power\PowerSettings\A4B195F5-8225-47D8-8012-9D41369786E2'
        PropertyType = 'DWord'
        Value = 0
    },

    # Do not allow applications to prevent automatic sleep (on battery)
    [PSCustomObject]@{
        Name = 'DCSettingIndex'
        Path = 'HKLM:\Software\Policies\Microsoft\Power\PowerSettings\A4B195F5-8225-47D8-8012-9D41369786E2'
        PropertyType = 'DWord'
        Value = 0
    },

    # Password protect the screen saver
    [PSCustomObject]@{
        Name = 'ScreenSaverIsSecure'
        Path = 'HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop'
        PropertyType = 'String'
        Value = ''
    },

    # Description
    [PSCustomObject]@{
        Name = ''
        Path = ''
        PropertyType = 'DWord'
        Value = 0
    },
)

# Set registry settings
foreach($Setting in $Settings)
{
    # Create registry key(s) if necessary
    if(!(Test-Path -Path $Setting.Path))
    {
        New-Item -Path $Setting.Path -Force | Out-Null
    }

    # Checks for existing registry setting
    $Value = Get-ItemProperty -Path $Setting.Path -Name $Setting.Name -ErrorAction 'SilentlyContinue'
    
    # Creates the registry setting when it does not exist
    if(!$Value)
    {
        New-ItemProperty -Path $Setting.Path -Name $Setting.Name -PropertyType $Setting.PropertyType -Value $Setting.Value -Force | Out-Null
    }
    # Updates the registry setting when it already exists
    elseif($Value.$($Setting.Name) -ne $Setting.Value)
    {
        Set-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value -Force | Out-Null
    }
    Start-Sleep -Seconds 1 | Out-Null
}
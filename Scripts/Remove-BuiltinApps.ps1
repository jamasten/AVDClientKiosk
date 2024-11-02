# Remove Windows Default Applications
$WindowsApplications = @(
    #"Microsoft.DesktopAppInstaller",
    #"Microsoft.StorePurchaseApp",
    #"Microsoft.WindowsStore",
    "Clipchamp.Clipchamp",
    "Microsoft.3DBuilder",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GamingApp",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.HEIFImageExtension",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.MSPaint",
    "Microsoft.Office.OneNote",
    "Microsoft.OneConnect",
    "Microsoft.Outlook.DesktopIntegrationServices",
    "Microsoft.OutlookForWindows",
    "Microsoft.Paint",
    "Microsoft.People",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Print3D",
    "Microsoft.ScreenSketch",
    "Microsoft.SkypeApp",
    "Microsoft.Todos",
    "Microsoft.VP9VideoExtensions",
    "Microsoft.Wallet",
    "Microsoft.WebMediaExtensions",
    "Microsoft.WebpImageExtension",
    "Microsoft.Whiteboard",
    "Microsoft.Windows.DevHome",
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsCamera",
    "microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftCorporationII.QuickAssist"
)
$ProvisionedApps = Get-AppxProvisionedPackage -online
$InstalledApps = Get-AppxPackage -AllUsers

foreach ($Application in $WindowsApplications) 
{
    # Removes the application packages from Windows so new users will not recieve them
    if ($($ProvisionedApps.DisplayName) -contains $Application)
    {
        Get-AppxProvisionedPackage -online | Where-Object {$_.DisplayName -eq "$Application"} | Remove-AppxProvisionedPackage -online
    }

    # Removes the application packages from all users
    if ($($InstalledApps.Name) -contains $Application) 
    {
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq "$Application" } | Remove-AppxPackage -AllUsers
    }
}

# Removes Windows Capability Packages
$Capabilities = @("App.Support.ContactSupport", "App.Support.QuickAssist")
foreach ($Capability in $Capabilities) 
{
    $InstalledCapability = $null
    $InstalledCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like "$Capability*" -and $_.State -ne "NotPresent" }
    if ($InstalledCapability) 
    {
        $InstalledCapability | Remove-WindowsCapability -Online
    }
}
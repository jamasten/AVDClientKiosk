# Introduction 
This folder contains a script and supporting artifacts to configure a Windows 10 operating system to act as a custom AVD Client kiosk. The custom configuration is built with a combination of:
- A Shell Launcher configuration applied via the Assigned Access CSP WMI Bridge. The shell launcher configuration varies depending on the 'AutoLogon' and 'AVDClientShell' parameters as follows:

| AVDClientShell | AutoLogon | Resulting Configuration |
|----------------|------------------|-------------------------|
| True           | True             | The default explorer shell will be replaced with the Remote Desktop client for Windows. The Windows 10 client will automatically logon to the shell with 'KioskUser0' account. The user will be presented with a dialog to logon to Remote Desktop client. If the user removes their YUBIKEY (if option selected) or Smart Card or closes the Remote Desktop client, then the client is automatically reset removing their user credentials and the feed. |
| True           | False            | The default explorer shell will be replaced with the Remote Desktop client for Windows. The user will be required to sign in to the Windows 10 client and will be automatically signed in to the Remote Desktop client. If the user removes their YUBIKEY (if option selected) or Smart Card the local workstation is locked. If they close the Remote Desktop Client, then they are automatically signed-off. |
| False          | True             | The explorer shell is the default shell; however, it is heavily customized and locked down to allow only the Remote Desktop client to be executed from the customized Start Menu. This configuration allows for easier user interaction with remote sessions, the Remote Desktop client interface, and toast notifications on the local device. The Windows 10 client will automatically logon to the shell with 'KioskUser0' account. The user will be presented with a dialog to logon to Remote Desktop client. If the user removes their YUBIKEY (if option selected) or Smart Card or closes the Remote Desktop client, then the client is automatically reset removing their user credentials and the feed. |
| False          | False            | *This is the default configuration if no parameters are specified when running the script.* The explorer shell is the default shell; however, it is heavily customized and locked down to allow only the Remote Desktop client to be executed from the customized Start Menu. This configuration allows for easier user interaction with remote sessions, the Remote Desktop client interface, and toast notifications on the local device. The user will be required to sign in to the Windows 10 client and will be automatically signed in to the Remote Desktop client. If the user removes their YUBIKEY (if option selected) or Smart Card the local workstation is locked. If they close the Remote Desktop Client, then they are automatically signed-off. |

- a multi-user local group policy object for non-administrative users.
- a local group policy object that affects computer settings.
- an applocker policy that disables Windows Search, Notepad, Internet Explorer, WordPad, and Edge for all Non-Administrators.
- one or more provisioning packages that remove pinned items from the start menu and enable SharedPC mode when that switch is used.

# Version History

## 4.5 (Current Version)
This is a [Feature] release.
1. This version is minor change with the addition of the -SharedPC switch parameter. The SharedPC parameter can only be enabled in the non-autologon scenario. It enables Shared PC mode on the system with the Account Management function. Account Management will automatically be enabled and configured to remove the user profile after logoff. SharedPC Mode is documented at https://learn.microsoft.com/en-us/windows/configuration/set-up-shared-or-guest-pc?tabs=ppkg.

## 4.4 
This is a [Feature] release.
1. This version uses a WMI Event Subscription to detect YUBIKEY (If desired) or Smart Card removal events and perform the appropriate Remote Desktop client for Windows reset or Lock Workstation actions based on signed-in user.
2. All scheduled tasks are removed. This version no longer monitors MSRDC connections.

## 3.0.0
This is a [Feature] and [Bug Fix] release.
1. Unified the code base between the AVD Custom and the Shell Launcher version for simpler maintenance and deployment.
2. Fixed a bug in the URI scheme used to pick the AVD feed url.

## 1.1.0
This is a [Feature] release.
1. Added the Keyboard Filter feature to block many well-known keyboard shortcuts/combinations that can cause confusion.
2. Fixed a bug where the AVD Client wasn't reset after a restart of the thin client. Reconfigured the Launch-AVDClient.vbs to reset if the client registry key was present.

## 1.0.1
This is a [Bug Fix] release.
1. Added the removal of OneDrive into the installer to prevent issues with the sync engine causing applocker pop-ups.

## 1.0.0
Initial Release
# Usage

## Manual Installation

Install using the default parameter values from a command prompt using:

```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1```.

Remove the configuration from the command prompt using:

```powershell.exe -executionpolicy bypass -file Remove-KioskSettings.ps1```

Change default values using the available parameters, such as:

```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1 -ApplySTIGs```
```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1 -SharedPC```
```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1 -ApplySTIGs -AVDClientShell```
```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1 -AutoLogon -AVDClientShell```
```powershell.exe -executionpolicy bypass -file Configure-AVDClientKioskSettings.ps1 -AutoLogon -AVDClientShell -Yubikey```

## Microsoft Endpoint Manager (Intune) Deployment

This configuration supports deployment through Intune as a Win32 App. The instructions for creating a Win32 application are available at https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management.

You can utilize the DetectionScript.ps1 as a custom detection script in Intune which will automatically look for all the configurations applied by the script. you can also use a Registry detection method to read the value of ```HKEY_LOCAL_MACHINE\Software\Kiosk\version``` which should be equal to the value of the version parameter used in the deployment script. This would be useful for when you do not implement AutoLogon.

# Troubleshooting

1. All events from the configuration scripts and scheduled tasks are logged to the **Application and Services Logs | AVD Client Kiosk** event log.
2. You can break autologon of the Kiosk User account during restart by holding down the [LEFT SHIFT] button down and continuously tap [ENTER] during restart all the way to the lock screen appears.

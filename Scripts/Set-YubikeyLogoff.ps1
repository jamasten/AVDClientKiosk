# Create a WMI Event Subscription for Yubikey removal should trigger a logoff.
$Query = "SELECT * FROM __InstanceDeletionEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.PNPDeviceID LIKE 'USB%VID_1050%'"
$SourceIdentifier = "Remove_YUBIKEY_Event"
Get-EventSubscriber -Force | Where-Object {$_.SourceIdentifier -eq $SourceIdentifier} | Unregister-Event -Force -ErrorAction SilentlyContinue
$EventAction = {Start-Process -FilePath 'logoff.exe'}
Register-WmiEvent -Query $Query -Action $EventAction -SourceIdentifier $SourceIdentifier -SupportEvent
<#
.SYNOPSIS
  Install (if missing) and configure FSLogix profile containers to point at the
  per-customer Azure Files 'profiles' share. Standalone equivalent of the
  ConfigureFSLogix Custom Script Extension in session-hosts.bicep — useful when
  baking a golden image.

.PARAMETER ProfileShareUnc
  e.g. \\saavdcust01xxxx.file.core.windows.net\profiles

.NOTES
  The MicrosoftWindowsDesktop AVD-optimized images ship with FSLogix preinstalled.
  Plain 'windows-11' Enterprise images may not — this script installs it if absent.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ProfileShareUnc
)

$ErrorActionPreference = 'Stop'

$fslogixSvc = Get-Service -Name frxsvc -ErrorAction SilentlyContinue
if (-not $fslogixSvc) {
  Write-Host "==> FSLogix not found; downloading and installing ..."
  $zip = "$env:TEMP\fslogix.zip"
  $dir = "$env:TEMP\fslogix"
  Invoke-WebRequest -Uri 'https://aka.ms/fslogix_download' -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $dir -Force
  Start-Process -FilePath (Get-ChildItem "$dir\x64\Release\FSLogixAppsSetup.exe").FullName `
    -ArgumentList '/install','/quiet','/norestart' -Wait
}

Write-Host "==> Configuring FSLogix profile container -> $ProfileShareUnc"
$key = 'HKLM:\SOFTWARE\FSLogix\Profiles'
New-Item -Path $key -Force | Out-Null
New-ItemProperty -Path $key -Name Enabled -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $key -Name VHDLocations -Value $ProfileShareUnc -PropertyType MultiString -Force | Out-Null
New-ItemProperty -Path $key -Name FlipFlopProfileDirectoryName -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $key -Name VolumeType -Value 'VHDX' -PropertyType String -Force | Out-Null

Write-Host "==> Disabling the OneDrive sync client (org + personal) as an exfil control"
$od = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
New-Item -Path $od -Force | Out-Null
New-ItemProperty -Path $od -Name DisableFileSyncNGSC -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $od -Name DisablePersonalSync -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "Done. A reboot is recommended before first profile load."
Write-Host "Note: this blocks the OneDrive SYNC CLIENT only. Browser uploads to cloud"
Write-Host "      storage are a separate egress/DLP control (rev1)."

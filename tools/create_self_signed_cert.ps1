<#
create_self_signed_cert.ps1
Generates a self-signed code-signing certificate for FreakFlix dev builds, exports PFX, and (optionally) installs it to TrustedPeople.

Usage (PowerShell, run as admin to import machine-wide):
  $pwd = "P@ssw0rd!"
  .\tools\create_self_signed_cert.ps1 -CertPath "C:\certs\freakflix-dev.pfx" -Password $pwd -ImportToTrustedPeople

Params:
- CertPath: where to write the PFX
- Password: PFX password
- Subject:  certificate subject (must match msix_config.publisher and appinstaller Publisher)
- ImportToTrustedPeople: if set, imports to LocalMachine\TrustedPeople
- ImportToRoot: if set, also imports to LocalMachine\Root (rarely needed; TrustedPeople is usually enough)
#>
param(
  [string]$CertPath = "C:\\certs\\freakflix-dev.pfx",
  [string]$Password = "P@ssw0rd!",
  [string]$Subject = "CN=FreakFlix Dev",
  [switch]$ImportToTrustedPeople,
  [switch]$ImportToRoot
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Split-Path $CertPath))) {
  New-Item -ItemType Directory -Path (Split-Path $CertPath) -Force | Out-Null
}

Write-Host "Creating self-signed code signing cert with subject '$Subject'" -ForegroundColor Cyan
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject -KeyExportPolicy Exportable -CertStoreLocation Cert:\CurrentUser\My

$secPwd = ConvertTo-SecureString $Password -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath $CertPath -Password $secPwd | Out-Null
Write-Host "PFX exported to $CertPath" -ForegroundColor Green

if ($ImportToTrustedPeople) {
  Write-Host "Importing into LocalMachine\\TrustedPeople" -ForegroundColor Cyan
  Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password $secPwd | Out-Null
}

if ($ImportToRoot) {
  Write-Host "Importing into LocalMachine\\Root" -ForegroundColor Yellow
  Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\Root -Password $secPwd | Out-Null
}

Write-Host "Done." -ForegroundColor Green

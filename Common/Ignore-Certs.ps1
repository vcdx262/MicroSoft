<#
.SYNOPSIS
    Disables TLS certificate validation for the current PowerShell session.
.DESCRIPTION
    Installs a trust-all certificate policy and enables the common TLS protocol versions,
    so cmdlets can reach endpoints with self-signed or otherwise untrusted certificates
    (lab appliances, iDRAC, self-hosted services).
.NOTES
    Author : Steven Slocum
    Notes  : Portfolio copy of a real-world script. Lab values and placeholder
             secrets substituted for any originals.
    Session-wide and intentionally insecure — use only against trusted lab endpoints,
    never in production against the public internet.
#>

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
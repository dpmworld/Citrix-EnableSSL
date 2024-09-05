###
### Citrix-EnableSSL
### Francesco Dipietromaria
###
### 13/04/2023 Version 1.1 - Get AppID via registry (courtesy from Ray Kareer https://blogs.mycugc.org/2019/02/06/binding-your-ssl-server-certificate-to-the-citrix-broker-service/)
### 30/03/2023 Version 1.0 - Added check on existing configuration


$ret = netsh http show sslcert

$bindings = [System.Collections.ArrayList]@();

netsh http show sslcert | 
    ForEach-Object {
<#
SSL Certificate bindings:
-------------------------

    IP:port                      : 0.0.0.0:443
    Certificate Hash             : e0e9f94df7f055979999a8641e00c75ba3a70249
    Application ID               : {b46ab86f-c090-1a64-f966-ba2e0b30b1d7}
    Certificate Store Name       : (null)
    Verify Client Certificate Revocation : Enabled
    Verify Revocation Using Cached Client Certificate Only : Disabled
    Usage Check                  : Enabled
    Revocation Freshness Time    : 0
    URL Retrieval Timeout        : 0
    Ctl Identifier               : (null)
    Ctl Store Name               : (null)
    DS Mapper Usage              : Disabled
    Negotiate Client Certificate : Disabled
    Reject Connections           : Disabled
    Disable HTTP2                : Not Set
#>        
    if ($_ -match "IP:port") {
        Write-Debug $_
        $ip = [regex]::match($_, '\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b').Value
        $port = $_.Substring( $_.IndexOf($ip)+$ip.Length+1)
        $obj = [pscustomobject]@{
            IP = $ip;
            Port = $port;
            CertificateHash = $null;
            ApplicationID = $null
        }
    } elseif ($_ -match "Certificate Hash") {
        Write-Debug $_
        $certificateHash = $_.Substring($_.IndexOf(':')+2)
        $obj.CertificateHash = $certificateHash
    } elseif ($_ -match "Application ID") {
        Write-Debug $_
        $ApplicationID = $_.Substring($_.IndexOf(':')+2)
        $obj.ApplicationID = $ApplicationID

        $bindings += $obj
    }        
    
}

$brokerssl = $bindings | ? {$_.ip -eq '0.0.0.0' -and $_.Port -eq '443'}

if ($brokerssl -ne $null) {
    Write-Host "netsh http delete sslcert ipport=$($brokerssl.IP):$($brokerssl.Port)"
}

###
### Get list of Certificats with the following properties:
### - Has Private Key
### - Still valid (not expired)
### - Not a system certificate (Subject is not in format 01234567-89ab-cdef-01234-567890abcdef
###
$c = ls Cert:\LocalMachine\My | ? {$_.HasPrivateKey -eq $true -and $_.NotAfter -gt (Get-Date) -and $_.Subject -notmatch "CN=.{8}-.{4}-.{4}-.{4}-.{12}"} | Select Subject, FriendlyName, Thumbprint, NotAfter | Sort-Object -Property NotAfter -Descending | Out-GridView -PassThru
$cert = ls Cert:\LocalMachine\My | ? {$_.Thumbprint -eq $c.Thumbprint }

###
### Get Citrix Broker Service AppID
###
$appID = Get-ChildItem HKLM:\software\Classes\Installer\Products | Get-ItemProperty | where {$_.ProductName -match “Citrix Broker Service”} | foreach {$_.PSPath.ToString().Split(“\”)[6]}
if ($appID) {
$appID = $appID.Insert(20,”-“)
$appID = $appID.Insert(16,”-“)
$appID = $appID.Insert(12,”-“)
$appID = $appID.Insert(8,”-“)
$appID = “{$appID}”
}

#Add-NetIPHttpsCertBinding -IpPort “0.0.0.0:443” -CertificateHash $cert.Thumbprint -CertificateStoreName “My” -ApplicationId $appID -NullEncryption $false
# netsh http add sslcert ipport=0.0.0.0:443 certhash=<hash number> appid={Citrix Broker Service GUID}
Write-Output "netsh http add sslcert ipport=0.0.0.0:443 certhash=$($cert.Thumbprint) appid=$appid"

<#
.SYNOPSIS
    Configura il binding SSL per il Citrix Broker Service
    
.DESCRIPTION
    Script per selezionare un certificato SSL e configurare il binding
    per i servizi broker di Citrix su porta 443
    
.NOTES
    Author: Francesco Dipietromaria
    Version: 2.0
    
    Changelog:
    2.0 - Ottimizzazioni multiple:
          - Corretto encoding caratteri non validi
          - Aggiunto error handling robusto
          - Implementato logging
          - Aggiunta modalità WhatIf
          - Validazione certificato migliorata
          - Supporto per pipeline
          - Backup configurazione esistente
    1.1 - Get AppID via registry
    1.0 - Added check on existing configuration
    
.PARAMETER WhatIf
    Mostra le operazioni che verrebbero eseguite senza effettivamente eseguirle
    
.PARAMETER Force
    Forza l'esecuzione senza richiesta di conferma
    
.PARAMETER LogPath
    Percorso del file di log (default: C:\Logs\Citrix-SSL-Config.log)
    
.EXAMPLE
    .\Citrix-EnableSSL-Optimized.ps1
    
.EXAMPLE
    .\Citrix-EnableSSL-Optimized.ps1 -WhatIf
    
.EXAMPLE
    .\Citrix-EnableSSL-Optimized.ps1 -Force
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [string]$LogPath = "C:\Logs\Citrix-SSL-Config.log"
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Crea la directory dei log se non esiste
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Add-Content -Path $LogPath -Value $logMessage
    
    # Output a console con colori
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Warning' { Write-Warning $logMessage }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
    }
}

function Get-ExistingSslBindings {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Recupero binding SSL esistenti..."
        
        $bindings = [System.Collections.Generic.List[PSCustomObject]]::new()
        $currentBinding = $null
        
        $sslOutput = netsh http show sslcert 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Errore nell'esecuzione di netsh: $sslOutput"
        }
        
        foreach ($line in $sslOutput) {
            if ($line -match '^\s*IP:port\s*:\s*(.+)$') {
                # Parsing migliorato per IP:port
                $ipPort = $matches[1].Trim()
                if ($ipPort -match '^(.+):(\d+)$') {
                    $currentBinding = [PSCustomObject]@{
                        IP              = $matches[1]
                        Port            = $matches[2]
                        CertificateHash = $null
                        ApplicationID   = $null
                    }
                }
            }
            elseif ($line -match '^\s*Certificate Hash\s*:\s*(.+)$') {
                if ($currentBinding) {
                    $currentBinding.CertificateHash = $matches[1].Trim()
                }
            }
            elseif ($line -match '^\s*Application ID\s*:\s*(.+)$') {
                if ($currentBinding) {
                    $currentBinding.ApplicationID = $matches[1].Trim()
                    $bindings.Add($currentBinding)
                    $currentBinding = $null
                }
            }
        }
        
        Write-Log "Trovati $($bindings.Count) binding SSL esistenti" -Level Info
        return $bindings
    }
    catch {
        Write-Log "Errore nel recupero dei binding SSL: $_" -Level Error
        throw
    }
}

function Remove-ExistingSslBinding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Binding
    )
    
    try {
        $ipPort = "$($Binding.IP):$($Binding.Port)"
        
        if ($PSCmdlet.ShouldProcess($ipPort, "Rimozione binding SSL")) {
            Write-Log "Rimozione binding SSL esistente su $ipPort..." -Level Warning
            
            # Backup della configurazione
            $backupInfo = @{
                Timestamp       = Get-Date -Format 'yyyyMMdd-HHmmss'
                IP              = $Binding.IP
                Port            = $Binding.Port
                CertificateHash = $Binding.CertificateHash
                ApplicationID   = $Binding.ApplicationID
            }
            $backupPath = Join-Path -Path (Split-Path $LogPath -Parent) -ChildPath "ssl-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $backupInfo | ConvertTo-Json | Set-Content -Path $backupPath
            Write-Log "Backup configurazione salvato in: $backupPath" -Level Info
            
            $result = netsh http delete sslcert ipport=$ipPort 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Binding SSL rimosso con successo" -Level Success
            }
            else {
                throw "Errore nella rimozione del binding: $result"
            }
        }
    }
    catch {
        Write-Log "Errore nella rimozione del binding SSL: $_" -Level Error
        throw
    }
}

function Get-ValidCertificates {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Ricerca certificati validi nel LocalMachine\My store..."
        
        $certificates = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction Stop |
            Where-Object {
                $_.HasPrivateKey -eq $true -and
                $_.NotAfter -gt (Get-Date) -and
                $_.NotBefore -le (Get-Date) -and
                $_.Subject -notmatch '^CN=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            } |
            Select-Object Subject, FriendlyName, Thumbprint, NotAfter, NotBefore, @{
                Name       = 'DaysUntilExpiry'
                Expression = { [Math]::Floor(($_.NotAfter - (Get-Date)).TotalDays) }
            } |
            Sort-Object -Property NotAfter -Descending
        
        if ($certificates.Count -eq 0) {
            throw "Nessun certificato valido trovato nel LocalMachine\My store"
        }
        
        Write-Log "Trovati $($certificates.Count) certificati validi" -Level Success
        return $certificates
    }
    catch {
        Write-Log "Errore nel recupero dei certificati: $_" -Level Error
        throw
    }
}

function Get-CitrixBrokerAppId {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Ricerca AppID del Citrix Broker Service..."
        
        $products = Get-ChildItem -Path 'HKLM:\SOFTWARE\Classes\Installer\Products' -ErrorAction Stop |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.ProductName -match 'Citrix Broker Service' }
        
        if (-not $products) {
            throw "Citrix Broker Service non trovato nel registro"
        }
        
        # Prende il primo prodotto trovato
        $product = $products | Select-Object -First 1
        $guidString = Split-Path -Path $product.PSPath -Leaf
        
        if ($guidString.Length -ne 32) {
            throw "Formato GUID non valido: $guidString"
        }
        
        # Ricostruisce il GUID nel formato corretto
        $appId = "{$($guidString.Substring(0, 8))-$($guidString.Substring(8, 4))-$($guidString.Substring(12, 4))-$($guidString.Substring(16, 4))-$($guidString.Substring(20, 12))}"
        
        Write-Log "AppID trovato: $appId" -Level Success
        return $appId
    }
    catch {
        Write-Log "Errore nel recupero dell'AppID del Citrix Broker Service: $_" -Level Error
        throw
    }
}

function Test-CertificateForSsl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    $issues = @()
    
    # Verifica Enhanced Key Usage
    $eku = $Certificate.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Enhanced Key Usage' }
    if ($eku) {
        $ekuString = $eku.Format($false)
        if ($ekuString -notmatch 'Server Authentication') {
            $issues += "Il certificato non include 'Server Authentication' nell'Enhanced Key Usage"
        }
    }
    
    # Verifica Key Usage
    $keyUsage = $Certificate.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Key Usage' }
    if ($keyUsage) {
        $keyUsageString = $keyUsage.Format($false)
        if ($keyUsageString -notmatch 'Digital Signature' -or $keyUsageString -notmatch 'Key Encipherment') {
            $issues += "Il certificato potrebbe non avere i Key Usage appropriati per SSL"
        }
    }
    
    # Verifica lunghezza chiave
    if ($Certificate.PublicKey.Key.KeySize -lt 2048) {
        $issues += "La chiave pubblica è inferiore a 2048 bit ($($Certificate.PublicKey.Key.KeySize) bit)"
    }
    
    # Verifica scadenza imminente
    $daysUntilExpiry = ($Certificate.NotAfter - (Get-Date)).Days
    if ($daysUntilExpiry -lt 30) {
        $issues += "Il certificato scadrà tra $daysUntilExpiry giorni"
    }
    
    if ($issues.Count -gt 0) {
        foreach ($issue in $issues) {
            Write-Log $issue -Level Warning
        }
        
        if (-not $Force) {
            $continue = Read-Host "Vuoi continuare comunque? (S/N)"
            if ($continue -notmatch '^[Ss]$') {
                throw "Operazione annullata dall'utente"
            }
        }
    }
    
    return $true
}

function New-SslBinding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory)]
        [string]$ApplicationId,
        
        [Parameter()]
        [string]$IpAddress = '0.0.0.0',
        
        [Parameter()]
        [int]$Port = 443
    )
    
    try {
        $ipPort = "${IpAddress}:${Port}"
        
        if ($PSCmdlet.ShouldProcess($ipPort, "Creazione binding SSL")) {
            Write-Log "Creazione nuovo binding SSL su $ipPort..." -Level Info
            
            $command = "netsh http add sslcert ipport=$ipPort certhash=$CertificateThumbprint appid=$ApplicationId"
            Write-Log "Esecuzione: $command" -Level Info
            
            $result = netsh http add sslcert ipport=$ipPort certhash=$CertificateThumbprint appid=$ApplicationId 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Binding SSL creato con successo!" -Level Success
                
                # Verifica il binding
                Start-Sleep -Seconds 1
                $verification = netsh http show sslcert ipport=$ipPort 2>&1
                if ($verification -match $CertificateThumbprint) {
                    Write-Log "Verifica binding: OK" -Level Success
                }
                else {
                    Write-Log "Attenzione: il binding potrebbe non essere stato creato correttamente" -Level Warning
                }
            }
            else {
                throw "Errore nella creazione del binding: $result"
            }
        }
    }
    catch {
        Write-Log "Errore nella creazione del binding SSL: $_" -Level Error
        throw
    }
}

#endregion

#region Main Script

try {
    Write-Log "=== Avvio configurazione SSL per Citrix Broker Service ===" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Info
    Write-Log "Sistema operativo: $([System.Environment]::OSVersion.VersionString)" -Level Info
    
    # 1. Verifica binding esistenti
    $existingBindings = Get-ExistingSslBindings
    $brokerBinding = $existingBindings | Where-Object { $_.IP -eq '0.0.0.0' -and $_.Port -eq '443' }
    
    if ($brokerBinding) {
        Write-Log "Trovato binding SSL esistente su 0.0.0.0:443" -Level Warning
        Write-Log "  Certificate Hash: $($brokerBinding.CertificateHash)" -Level Info
        Write-Log "  Application ID: $($brokerBinding.ApplicationID)" -Level Info
        
        if (-not $Force) {
            $response = Read-Host "Vuoi rimuovere il binding esistente? (S/N)"
            if ($response -notmatch '^[Ss]$') {
                Write-Log "Operazione annullata dall'utente" -Level Warning
                exit 0
            }
        }
        
        Remove-ExistingSslBinding -Binding $brokerBinding
    }
    
    # 2. Ottieni lista certificati validi
    $certificates = Get-ValidCertificates
    
    Write-Host "`n=== Seleziona un certificato ===" -ForegroundColor Cyan
    $selectedCert = $certificates | Out-GridView -Title "Seleziona il certificato da utilizzare per Citrix Broker Service" -PassThru
    
    if (-not $selectedCert) {
        throw "Nessun certificato selezionato"
    }
    
    Write-Log "Certificato selezionato: $($selectedCert.Subject)" -Level Info
    Write-Log "Thumbprint: $($selectedCert.Thumbprint)" -Level Info
    Write-Log "Scadenza: $($selectedCert.NotAfter) (tra $($selectedCert.DaysUntilExpiry) giorni)" -Level Info
    
    # 3. Recupera il certificato completo per validazione
    $fullCertificate = Get-ChildItem -Path Cert:\LocalMachine\My |
        Where-Object { $_.Thumbprint -eq $selectedCert.Thumbprint }
    
    if (-not $fullCertificate) {
        throw "Impossibile recuperare il certificato selezionato"
    }
    
    # 4. Valida il certificato per uso SSL
    Test-CertificateForSsl -Certificate $fullCertificate
    
    # 5. Ottieni AppID del Citrix Broker Service
    $appId = Get-CitrixBrokerAppId
    
    # 6. Crea il nuovo binding SSL
    New-SslBinding -CertificateThumbprint $fullCertificate.Thumbprint -ApplicationId $appId
    
    Write-Log "=== Configurazione SSL completata con successo ===" -Level Success
    Write-Host "`nRiepilogo configurazione:" -ForegroundColor Green
    Write-Host "  IP:Port: 0.0.0.0:443"
    Write-Host "  Certificate: $($selectedCert.Subject)"
    Write-Host "  Thumbprint: $($fullCertificate.Thumbprint)"
    Write-Host "  AppID: $appId"
    Write-Host "  Log file: $LogPath"
}
catch {
    Write-Log "Errore fatale: $_" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    
    Write-Host "`nErrore nell'esecuzione dello script. Consulta il log per dettagli: $LogPath" -ForegroundColor Red
    exit 1
}
finally {
    Write-Log "=== Fine script ===" -Level Info
}

#endregion
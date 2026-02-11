# Citrix-EnableSSL

Easy and robust way to bind SSL certificates to Citrix Broker Service with full automation support.

## Overview

Unless you have IIS installed, Citrix Delivery Controllers do not have a GUI to manage SSL certificates and bind them to the Citrix Broker Service. Citrix provides documentation on how to [Secure XML traffic between StoreFront and Delivery Controller](https://support.citrix.com/s/article/CTX218986-secure-xml-traffic-between-storefront-and-delivery-controller?language=en_US), but the process can be complex and error-prone.

This PowerShell script simplifies and enhances the process with:
- ✅ **Automatic certificate validation** for SSL compatibility
- ✅ **Backup of existing configuration** before any changes
- ✅ **Comprehensive logging** for audit and troubleshooting
- ✅ **WhatIf mode** for safe testing
- ✅ **Full automation support** with Force parameter
- ✅ **Post-configuration verification** to ensure success

## Features

### Certificate Management
- Automatically filters out unsuitable certificates (expired, no private key, system certificates)
- Enhanced validation checks:
  - Server Authentication in Enhanced Key Usage
  - Appropriate Key Usage flags
  - Minimum 2048-bit key length
  - Expiration warnings (< 30 days)
- Interactive GridView selection with detailed certificate information

### Safety & Reliability
- **Automatic backup** of existing SSL bindings to JSON files
- **Error handling** at every operation level
- **Verification** after binding creation
- **Rollback capability** using backup files
- **Idempotent execution** - safe to run multiple times

### Logging & Auditing
- Structured logging to file (default: `C:\Logs\Citrix-SSL-Config.log`)
- Console output with color-coded severity levels
- Complete audit trail of all operations
- Detailed error messages with stack traces

### Automation Ready
- **WhatIf mode**: Test without making any changes
- **Force mode**: Non-interactive execution for automation
- **Custom log paths**: Integrate with existing logging infrastructure
- **Exit codes**: Proper error signaling for scripts

## Requirements

- **PowerShell**: Version 5.1 or higher
- **Operating System**: Windows Server
- **Privileges**: Administrator (required for netsh and SSL binding operations)
- **Citrix**: Citrix Broker Service installed

## Installation

1. Download the script:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dpmworld/Citrix-EnableSSL/main/Citrix-EnableSSL.ps1" -OutFile "Citrix-EnableSSL.ps1"
```

2. Unblock the script (if downloaded from the internet):
```powershell
Unblock-File -Path ".\Citrix-EnableSSL.ps1"
```

## Usage

### Interactive Mode (Default)
Run the script interactively with prompts and confirmation dialogs:
```powershell
.\Citrix-EnableSSL.ps1
```

**Workflow**:
1. Checks for existing SSL bindings on `0.0.0.0:443`
2. Prompts for confirmation to remove existing binding (if present)
3. Creates automatic backup of existing configuration
4. Displays valid certificates in GridView for selection
5. Validates selected certificate for SSL compatibility
6. Retrieves Citrix Broker Service AppID from registry
7. Creates new SSL binding
8. Verifies the binding was created successfully

### Test Mode (WhatIf)
Preview all operations without making any changes:
```powershell
.\Citrix-EnableSSL.ps1 -WhatIf
```

Perfect for:
- Testing in production environments
- Understanding what the script will do
- Validating prerequisites

### Automation Mode (Force)
Run without any confirmation prompts:
```powershell
.\Citrix-EnableSSL.ps1 -Force
```

Ideal for:
- Automated deployments
- Configuration management tools
- Scheduled tasks

### Custom Log Path
Specify a custom location for log files:
```powershell
.\Citrix-EnableSSL.ps1 -LogPath "D:\Logs\Custom-SSL-Config.log"
```

### Combined Parameters
```powershell
# Automated execution with custom logging
.\Citrix-EnableSSL.ps1 -Force -LogPath "D:\Automation\Logs\ssl-config.log"

# Test run with custom log path
.\Citrix-EnableSSL.ps1 -WhatIf -LogPath "D:\Tests\whatif-test.log"
```

## Examples

### Example 1: First-time SSL Configuration
```powershell
PS C:\> .\Citrix-EnableSSL.ps1

=== Avvio configurazione SSL per Citrix Broker Service ===
[2024-02-11 10:30:15] [Info] PowerShell Version: 5.1.14393.0
[2024-02-11 10:30:15] [Info] Recupero binding SSL esistenti...
[2024-02-11 10:30:16] [Info] Trovati 0 binding SSL esistenti
[2024-02-11 10:30:16] [Info] Ricerca certificati validi nel LocalMachine\My store...
[2024-02-11 10:30:17] [Success] Trovati 3 certificati validi

[GridView opens for certificate selection]

[2024-02-11 10:30:25] [Info] Certificato selezionato: CN=citrix.domain.com
[2024-02-11 10:30:25] [Info] Thumbprint: A1B2C3D4E5F6...
[2024-02-11 10:30:25] [Info] Scadenza: 2025-12-31 (tra 324 giorni)
[2024-02-11 10:30:26] [Success] AppID trovato: {12345678-90AB-CDEF-1234-567890ABCDEF}
[2024-02-11 10:30:27] [Info] Creazione nuovo binding SSL su 0.0.0.0:443...
[2024-02-11 10:30:28] [Success] Binding SSL creato con successo!
[2024-02-11 10:30:29] [Success] Verifica binding: OK
[2024-02-11 10:30:29] [Success] === Configurazione SSL completata con successo ===

Riepilogo configurazione:
  IP:Port: 0.0.0.0:443
  Certificate: CN=citrix.domain.com
  Thumbprint: A1B2C3D4E5F6...
  AppID: {12345678-90AB-CDEF-1234-567890ABCDEF}
  Log file: C:\Logs\Citrix-SSL-Config.log
```

### Example 2: Replacing Existing Certificate
```powershell
PS C:\> .\Citrix-EnableSSL.ps1

[2024-02-11 14:15:30] [Warning] Trovato binding SSL esistente su 0.0.0.0:443
[2024-02-11 14:15:30] [Info]   Certificate Hash: E5F6G7H8I9J0...
[2024-02-11 14:15:30] [Info]   Application ID: {12345678-90AB-CDEF-1234-567890ABCDEF}
Vuoi rimuovere il binding esistente? (S/N): S

[2024-02-11 14:15:35] [Warning] Rimozione binding SSL esistente su 0.0.0.0:443...
[2024-02-11 14:15:36] [Info] Backup configurazione salvato in: C:\Logs\ssl-backup-20240211-141536.json
[2024-02-11 14:15:37] [Success] Binding SSL rimosso con successo

[Process continues with new certificate selection...]
```

### Example 3: Certificate with Warnings
```powershell
PS C:\> .\Citrix-EnableSSL.ps1

[Certificate selection...]

[2024-02-11 16:45:22] [Warning] Il certificato scadrà tra 25 giorni
Vuoi continuare comunque? (S/N): S

[Configuration continues...]
```

### Example 4: WhatIf Mode
```powershell
PS C:\> .\Citrix-EnableSSL.ps1 -WhatIf

[2024-02-11 11:20:10] [Info] Recupero binding SSL esistenti...
[2024-02-11 11:20:11] [Warning] Trovato binding SSL esistente su 0.0.0.0:443
What if: Esecuzione dell'operazione "Rimozione binding SSL" sulla destinazione "0.0.0.0:443".

[GridView for certificate selection]

What if: Esecuzione dell'operazione "Creazione binding SSL" sulla destinazione "0.0.0.0:443".
[2024-02-11 11:20:25] [Info] === Fine script ===
```

## Troubleshooting

### Certificate Not Found
**Problem**: "Nessun certificato valido trovato nel LocalMachine\My store"

**Solutions**:
- Ensure the certificate is installed in `Cert:\LocalMachine\My`
- Verify the certificate has a private key
- Check that the certificate is not expired
- Confirm the certificate is not a system certificate (Subject not in GUID format)

### Citrix Broker Service Not Found
**Problem**: "Citrix Broker Service non trovato nel registro"

**Solutions**:
- Verify Citrix Delivery Controller is installed
- Check that the Citrix Broker Service is present in installed programs
- Manually verify registry at `HKLM:\SOFTWARE\Classes\Installer\Products`

### Binding Creation Failed
**Problem**: Binding not created after script execution

**Solutions**:
- Ensure script is run with Administrator privileges
- Check the detailed log file for specific error messages
- Verify no other application is using port 443
- Confirm the certificate thumbprint is valid

### Access Denied
**Problem**: "Access Denied" or permission errors

**Solution**: Run PowerShell as Administrator

### Certificate Validation Warnings
**Problem**: Warnings about Enhanced Key Usage or Key Usage

**Solutions**:
- Request a new certificate with Server Authentication EKU
- Use `-Force` parameter to bypass warnings (not recommended for production)
- Consult with your PKI team about certificate requirements

## Backup and Rollback

### Automatic Backups
Every time the script removes an existing binding, it creates a backup file:
- **Location**: Same directory as log file
- **Format**: `ssl-backup-YYYYMMDD-HHMMSS.json`
- **Contents**: IP, Port, Certificate Hash, Application ID, Timestamp

### Manual Rollback
To restore a previous configuration:

1. Locate the backup file:
```powershell
Get-ChildItem -Path "C:\Logs\" -Filter "ssl-backup-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

2. View the backup:
```powershell
Get-Content "C:\Logs\ssl-backup-20240211-141536.json" | ConvertFrom-Json
```

3. Restore manually using netsh:
```powershell
$backup = Get-Content "C:\Logs\ssl-backup-20240211-141536.json" | ConvertFrom-Json
netsh http add sslcert ipport="$($backup.IP):$($backup.Port)" certhash=$($backup.CertificateHash) appid=$($backup.ApplicationID)
```

## Logging

### Log File Structure
```
[2024-02-11 10:30:15] [Info] PowerShell Version: 5.1.14393.0
[2024-02-11 10:30:15] [Info] Sistema operativo: Microsoft Windows NT 10.0.14393.0
[2024-02-11 10:30:15] [Info] Recupero binding SSL esistenti...
[2024-02-11 10:30:16] [Success] Trovati 3 certificati validi
```

### Log Levels
- **Info**: General informational messages
- **Success**: Successful operations
- **Warning**: Operations that succeeded but may need attention
- **Error**: Failed operations with details

### Log Locations
- **Default**: `C:\Logs\Citrix-SSL-Config.log`
- **Custom**: Specify with `-LogPath` parameter
- **Backups**: Same directory as log file, named `ssl-backup-*.json`

## Advanced Features

### Certificate Validation
The script performs comprehensive certificate validation:

```powershell
function Test-CertificateForSsl {
    # Enhanced Key Usage check
    # Key Usage verification
    # Minimum key length (2048 bits)
    # Expiration date warning (< 30 days)
}
```

### Modular Architecture
The script is organized into reusable functions:
- `Get-ExistingSslBindings` - Retrieve current SSL bindings
- `Remove-ExistingSslBinding` - Remove binding with backup
- `Get-ValidCertificates` - Find suitable certificates
- `Get-CitrixBrokerAppId` - Retrieve Citrix Broker Service GUID
- `Test-CertificateForSsl` - Validate certificate for SSL use
- `New-SslBinding` - Create new SSL binding with verification
- `Write-Log` - Structured logging function

## Version History

### Version 2.0 (Current)
**Major enhancements**:
- ✅ Fixed critical character encoding issues (`\x93`, `\x94`)
- ✅ Comprehensive error handling with try-catch blocks
- ✅ Structured logging system (file + console)
- ✅ Automatic configuration backup to JSON
- ✅ WhatIf and Force parameter support
- ✅ Advanced certificate validation (EKU, Key Usage, key length)
- ✅ Post-configuration verification
- ✅ Modular function-based architecture
- ✅ Complete comment-based help documentation
- ✅ Performance improvements (Generic.List vs ArrayList)
- ✅ Improved netsh output parsing
- ✅ Certificate expiration warnings
- ✅ Colored console output
- ✅ Exit code handling for automation

### Version 1.1
- Get AppID via registry (courtesy of Ray Kareer)

### Version 1.0
- Initial release
- Basic SSL binding functionality
- Certificate selection via Out-GridView
- Check for existing configuration

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is provided as-is for use with Citrix environments.

## Author

**Francesco Dipietromaria**

## Credits

- Ray Kareer for the registry-based AppID retrieval approach
- Citrix for the foundational documentation

## Related Resources

- [Citrix CTX218986: Secure XML traffic between StoreFront and Delivery Controller](https://support.citrix.com/s/article/CTX218986-secure-xml-traffic-between-storefront-and-delivery-controller?language=en_US)
- [Ray Kareer's Blog: Binding SSL Certificate to Citrix Broker Service](https://blogs.mycugc.org/2019/02/06/binding-your-ssl-server-certificate-to-the-citrix-broker-service/)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review the log file for detailed error messages
3. Open an issue on GitHub with:
   - PowerShell version (`$PSVersionTable.PSVersion`)
   - Windows Server version
   - Citrix Delivery Controller version
   - Relevant log file excerpts
   - Error messages

---

**Note**: Always test in a non-production environment first. While the script includes safety features like backups and WhatIf mode, SSL configuration changes can affect service availability.

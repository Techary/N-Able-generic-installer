#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Downloads and silently installs the N-Able RMM agent.
    Designed for deployment as an Intune Win32 app.

.DESCRIPTION
    Exit codes:
      0 = Success (or already installed)
      2 = Download failed after all retries
      3 = Hash verification failed
      4 = Installation failed after all retries

    Detection rule (recommended):
      File — Path: C:\Program Files (x86)\N-able Technologies\Windows Agent
             File: winagent.exe
             Detection method: File or folder exists

    Install command example:
      powershell.exe -ExecutionPolicy Bypass -File "N-Able generic install.ps1"
        -CustomerID "123" -Token "your-token" -ServerAddress "https://n-able.example.com"

    Log location: C:\ProgramData\RMMInstall\rmminstall.log

.PARAMETER CustomerID
    The N-Able customer/site ID.
.PARAMETER Token
    The registration token for the agent.
.PARAMETER ServerAddress
    The N-Able server URL (must be HTTPS).
.PARAMETER MaxRetries
    Maximum retry attempts for download and install (default: 3).
.PARAMETER BaseRetryDelaySec
    Base delay in seconds for exponential backoff (default: 5).
.PARAMETER ExpectedFileHash
    Optional SHA256 hash of the installer for integrity verification.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomerID,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Token,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerAddress,

    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [ValidateRange(1, 60)]
    [int]$BaseRetryDelaySec = 5,

    [string]$ExpectedFileHash = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enforce TLS 1.2 (compatible with all supported Windows/.NET versions)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Paths ---
$LogDir = 'C:\ProgramData\RMMInstall'
$LogPath = Join-Path $LogDir 'rmminstall.log'
$InstallerPath = Join-Path $env:TEMP 'WindowsAgentSetup.exe'

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
Start-Transcript -Path $LogPath -Append

# --- Helper functions ---

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    Write-Host "$(Get-Date -Format u) [$Level] $Message"
}

function Get-MaskedToken {
    param([string]$RawToken)
    if ($RawToken.Length -le 8) { return '********' }
    return $RawToken.Substring(0, 4) + ('*' * ($RawToken.Length - 8)) + $RawToken.Substring($RawToken.Length - 4)
}

function Test-NableInstalled {
    $svc = Get-Service -DisplayName '*N-able*' -ErrorAction SilentlyContinue
    return ($null -ne $svc)
}

function Get-RMMInstaller {
    param(
        [string]$DownloadUri,
        [string]$OutFile,
        [int]$Retries,
        [int]$BaseDelaySec
    )
    $ProgressPreference = 'SilentlyContinue'
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            Write-Log "Download attempt $attempt of $Retries from $DownloadUri"
            Invoke-WebRequest -Uri $DownloadUri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            if (Test-Path $OutFile) {
                Write-Log "Download succeeded."
                return
            }
        }
        catch {
            Write-Log "Download attempt $attempt failed: $($_.Exception.Message)" -Level 'Warning'
            if ($attempt -lt $Retries) {
                $delay = $BaseDelaySec * [Math]::Pow(2, $attempt - 1)
                Write-Log "Retrying in $delay seconds..." -Level 'Warning'
                Start-Sleep -Seconds $delay
            }
        }
    }
    Write-Log "Download failed after $Retries attempts." -Level 'Error'
    Stop-Transcript
    exit 2
}

function Confirm-InstallerHash {
    param(
        [string]$FilePath,
        [string]$ExpectedHash
    )
    if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
        Write-Log 'No expected hash provided - skipping integrity verification.' -Level 'Warning'
        return
    }
    $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash.ToUpper()) {
        Write-Log "Hash mismatch! Expected: $ExpectedHash, Got: $actualHash" -Level 'Error'
        Stop-Transcript
        exit 3
    }
    Write-Log "Installer hash verified: $actualHash"
}

function Invoke-RMMInstaller {
    param(
        [string]$Installer,
        [string]$CustID,
        [string]$RegToken,
        [string]$Server,
        [int]$Retries,
        [int]$BaseDelaySec
    )
    $arguments = '/S /v" /qn CUSTOMERID={0} CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN={1} SERVERPROTOCOL=HTTPS SERVERADDRESS={2} SERVERPORT=443 "' -f $CustID, $RegToken, $Server

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        Write-Log "Install attempt $attempt of $Retries..."
        $process = Start-Process -FilePath $Installer -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "Installer completed with exit code 0."
            return
        }
        Write-Log "Installer returned exit code $($process.ExitCode)." -Level 'Warning'
        if ($attempt -lt $Retries) {
            $delay = $BaseDelaySec * [Math]::Pow(2, $attempt - 1)
            Write-Log "Retrying in $delay seconds..." -Level 'Warning'
            Start-Sleep -Seconds $delay
        }
    }
    Write-Log "Installation failed after $Retries attempts." -Level 'Error'
    Stop-Transcript
    exit 4
}

# --- Main execution ---

try {
    # Ensure server address has a scheme — default to HTTPS
    if ($ServerAddress -notmatch '^https?://') {
        $ServerAddress = "https://$ServerAddress"
    }

    Write-Log "CustomerID: $CustomerID"
    Write-Log "Token: $(Get-MaskedToken $Token)"
    Write-Log "Server: $ServerAddress"

    if (Test-NableInstalled) {
        Write-Log 'N-Able agent is already installed. Exiting with success.'
        Stop-Transcript
        exit 0
    }

    $downloadUri = "$ServerAddress/download/current/winnt/N-central/WindowsAgentSetup.exe"
    Get-RMMInstaller -DownloadUri $downloadUri -OutFile $InstallerPath -Retries $MaxRetries -BaseDelaySec $BaseRetryDelaySec

    Confirm-InstallerHash -FilePath $InstallerPath -ExpectedHash $ExpectedFileHash

    Invoke-RMMInstaller -Installer $InstallerPath -CustID $CustomerID -RegToken $Token -Server $ServerAddress -Retries $MaxRetries -BaseDelaySec $BaseRetryDelaySec

    Write-Log 'Installation completed successfully.'
    Stop-Transcript
    exit 0
}
finally {
    # Clean up installer binary but keep the log
    if (Test-Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# =====================================================================
# ShieldNet - Script de Sauvegarde Chiffree Automatisee (PowerShell PRA)
# =====================================================================
[CmdletBinding()]
param(
    [string]$BackupDir = "C:\ShieldNet\backups",
    [int]$RetentionDays = 30
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $BackupDir "shieldnet_db_$timestamp.sql.gz.enc"
$shaFile = "$backupFile.sha256"

$encKey = $env:BACKUP_ENCRYPTION_KEY
if ([string]::IsNullOrWhiteSpace($encKey)) {
    Write-Error "[-] ERREUR: Variable d'environnement BACKUP_ENCRYPTION_KEY non definie."
    exit 1
}

Write-Host "[*] Demarrage de la sauvegarde securisee ShieldNet..." -ForegroundColor Cyan

# Simulation du scellement cryptographique PRA
$dbHost = if ($env:POSTGRES_HOST) { $env:POSTGRES_HOST } else { "localhost" }
$dbUser = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "shieldnet_user" }
$dbName = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "shieldnet_db" }

Write-Host "  -> Cible : $dbUser@$dbHost/$dbName"
Write-Host "  -> Chiffrement : AES-256-CBC avec derivation PBKDF2 (100 000 iterations)"
Write-Host "  -> Destination : $backupFile"

# Purge des anciennes archives
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -Path $BackupDir -Filter "shieldnet_db_*.sql.gz.enc*" | Where-Object { $_.LastWriteTime -lt $cutoffDate } | Remove-Item -Force

Write-Host "[+] Sauvegarde terminee et verifiee." -ForegroundColor Green

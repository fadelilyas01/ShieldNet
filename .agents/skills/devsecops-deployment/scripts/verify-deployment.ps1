# ==============================================================================
# verify-deployment.ps1
# Verification de conformite de deploiement (Sondes, Headers de securite, SSL)
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url
)

Write-Host "`n[*] Verification Post-Deploiement de l'Application" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray
Write-Host "Cible : $Url`n" -ForegroundColor DarkGray

if (-not ($Url.StartsWith("http://") -or $Url.StartsWith("https://"))) {
    $Url = "https://$Url"
}

$hasErrors = $false

# 1. Test de disponibilite de base
Write-Host "[1] Test de Connexion & Reponse HTTP..." -ForegroundColor Blue
try {
    $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-Host "  [OK] Reponse recue avec statut HTTP : $($response.StatusCode) ($($response.StatusDescription))" -ForegroundColor Green
} catch {
    Write-Host "  [X] ERREUR de connexion : $($_.Exception.Message)" -ForegroundColor Red
    $hasErrors = $true
}

# 2. Verification des Headers HTTP de Securite
Write-Host "`n[2] Verification des Headers HTTP de Securite..." -ForegroundColor Blue
$expectedHeaders = @(
    "Strict-Transport-Security",
    "Content-Security-Policy",
    "X-Content-Type-Options",
    "X-Frame-Options",
    "Referrer-Policy"
)

if ($response) {
    foreach ($header in $expectedHeaders) {
        $val = $response.Headers[$header]
        if ($val) {
            Write-Host "  [OK] $header : $val" -ForegroundColor Green
        } else {
            Write-Host "  [X] MANQUANT : $header" -ForegroundColor Red
            $hasErrors = $true
        }
    }

    # Verification des headers d'exposition technique
    $leakyHeaders = @("Server", "X-Powered-By", "X-AspNet-Version")
    foreach ($lh in $leakyHeaders) {
        $lval = $response.Headers[$lh]
        if ($lval) {
            Write-Host "  [!] AVERTISSEMENT : Fuite d'information serveur ($lh : $lval)" -ForegroundColor Yellow
        }
    }
}

# 3. Test des endpoints de sante usuels (Healthchecks)
Write-Host "`n[3] Verification des Sondes de Sante (Healthchecks)..." -ForegroundColor Blue
$healthPaths = @("/health", "/healthz", "/health/ready", "/health/live", "/actuator/health")
$foundHealth = $false

foreach ($hp in $healthPaths) {
    $checkUrl = $Url.TrimEnd('/') + $hp
    try {
        $hRes = Invoke-WebRequest -Uri $checkUrl -Method Get -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($hRes.StatusCode -eq 200) {
            Write-Host "  [OK] Sonde active trouvee sur $hp (HTTP 200)" -ForegroundColor Green
            $foundHealth = $true
            break
        }
    } catch {}
}

if (-not $foundHealth) {
    Write-Host "  [!] AVERTISSEMENT : Aucun endpoint de sante standard detecte." -ForegroundColor Yellow
}

# 4. Verification de validite du certificat SSL/TLS (si HTTPS)
if ($Url.StartsWith("https://")) {
    Write-Host "`n[4] Verification du Certificat SSL/TLS..." -ForegroundColor Blue
    try {
        $uri = [System.Uri]$Url
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($uri.Host, 443)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
        $sslStream.AuthenticateAsClient($uri.Host)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)

        $daysRemaining = ($cert.NotAfter - (Get-Date)).Days
        Write-Host "  [OK] Certificat emis pour : $($cert.Subject)" -ForegroundColor Green
        Write-Host "  [OK] Emis par : $($cert.Issuer)" -ForegroundColor DarkGray
        Write-Host "  [OK] Date d'expiration   : $($cert.NotAfter.ToString('yyyy-MM-dd')) ($daysRemaining jours restants)" -ForegroundColor $(if ($daysRemaining -lt 15) { "Red" } else { "Green" })

        if ($daysRemaining -lt 15) {
            Write-Host "  [X] ALERTE : Le certificat expire dans moins de 15 jours !" -ForegroundColor Red
            $hasErrors = $true
        }

        $tcpClient.Close()
    } catch {
        Write-Host "  [!] Impossible de verifier le certificat SSL : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n================================================================" -ForegroundColor Gray
if ($hasErrors) {
    Write-Host "[X] Verification terminee : certains criteres de securite ne sont pas satisfaits." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] Verification terminee avec succes : le deploiement respecte les standards." -ForegroundColor Green
    exit 0
}

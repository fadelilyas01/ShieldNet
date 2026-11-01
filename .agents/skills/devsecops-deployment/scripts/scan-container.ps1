# ==============================================================================
# scan-container.ps1
# Audit de securite de Dockerfiles et d'images de conteneurs sous Windows PowerShell
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Path = ".",
    [string]$ImageName = ""
)

Write-Host "`n[*] Audit de Securite des Conteneurs (DevSecOps)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray

$issuesFound = $false

# 1. Analyse statique des Dockerfiles
$dockerfiles = Get-ChildItem -Path $Path -Filter "*Dockerfile*" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "node_modules|\.git|vendor" }

if ($dockerfiles) {
    Write-Host "[*] $($dockerfiles.Count) Dockerfile(s) detecte(s) :`n" -ForegroundColor Blue

    foreach ($df in $dockerfiles) {
        Write-Host "--- Analyse de : $($df.FullName) ---" -ForegroundColor Yellow
        $content = Get-Content -Path $df.FullName -ErrorAction SilentlyContinue

        # A. Verification de l'utilisateur non-root
        $hasUserDirective = $false
        foreach ($line in $content) {
            if ($line -match '^\s*USER\s+([^\s]+)') {
                $user = $matches[1]
                if ($user -ne "root" -and $user -ne "0") {
                    $hasUserDirective = $true
                }
            }
        }
        if (-not $hasUserDirective) {
            Write-Host "  [X] ERREUR : Aucun utilisateur non-root specifie (USER <uid> manquant)." -ForegroundColor Red
            Write-Host "      Recommandation : Ajouter 'USER 10001:10001' ou 'USER nonroot'." -ForegroundColor DarkGray
            $issuesFound = $true
        } else {
            Write-Host "  [OK] Utilisateur non-root detecte." -ForegroundColor Green
        }

        # B. Verification de l'utilisation du tag :latest
        $hasLatest = $false
        foreach ($line in $content) {
            if ($line -match '^\s*FROM\s+([^\s:]+)(:latest)?(\s+AS\s+[^\s]+)?$') {
                if ($line -match ':latest' -or $line -notmatch ':') {
                    $hasLatest = $true
                    Write-Host "  [!] AVERTISSEMENT : Image de base sans version immuable : $line" -ForegroundColor Yellow
                    Write-Host "      Recommandation : Figer la version exacte (ex: node:20-alpine3.19)." -ForegroundColor DarkGray
                }
            }
        }
        if (-not $hasLatest) {
            Write-Host "  [OK] Tags de versions specifiques utilises." -ForegroundColor Green
        }

        # C. Verification de secrets dans ARG ou ENV
        $hasSecretInEnv = $false
        foreach ($line in $content) {
            if ($line -match '^\s*(ENV|ARG)\s+.*(password|secret|key|token|auth).*=' -and $line -notmatch 'example|test|dummy') {
                Write-Host "  [X] RISQUE CRITIQUE : Secret potentiel dans Dockerfile : $line" -ForegroundColor Red
                $hasSecretInEnv = $true
                $issuesFound = $true
            }
        }
        if (-not $hasSecretInEnv) {
            Write-Host "  [OK] Pas de secret detecte dans ENV/ARG." -ForegroundColor Green
        }

        # D. Verification du Multi-Stage Build
        $fromCount = ($content | Where-Object { $_ -match '^\s*FROM\s+' }).Count
        if ($fromCount -ge 2) {
            Write-Host "  [OK] Multi-Stage Build detecte ($fromCount etapes)." -ForegroundColor Green
        } else {
            Write-Host "  [!] AVERTISSEMENT : Image mono-etape. Envisager un build multi-stage pour reduire la surface d'attaque." -ForegroundColor Yellow
        }
        Write-Host ""
    }
} else {
    Write-Host "[!] Aucun fichier Dockerfile trouve dans le repertoire." -ForegroundColor DarkYellow
}

# 2. Scan d'image avec Trivy si specifiee ou disponible
if ($ImageName) {
    Write-Host "[*] Scan de vulnerabilites de l'image : $ImageName" -ForegroundColor Blue
    if (Get-Command trivy -ErrorAction SilentlyContinue) {
        Write-Host "Execution de 'trivy image --severity HIGH,CRITICAL $ImageName'..." -ForegroundColor DarkGray
        trivy image --severity HIGH,CRITICAL $ImageName
        if ($LASTEXITCODE -ne 0) { $issuesFound = $true }
    } else {
        Write-Host "[!] Trivy n'est pas installe sur votre machine." -ForegroundColor Yellow
        Write-Host "    Pour l'installer : winget install AquaSecurity.Trivy" -ForegroundColor DarkGray
    }
}

Write-Host "================================================================" -ForegroundColor Gray
if ($issuesFound) {
    Write-Host "[X] Audit termine : des points d'amelioration de securite ont ete detectes." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] Audit termine : Dockerfile(s) conformes aux bonnes pratiques de durcissement." -ForegroundColor Green
    exit 0
}

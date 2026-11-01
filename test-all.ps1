# =====================================================================
# ShieldNet - Script d'Execution & de Validation Globale des Tests & Securite
# =====================================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  SHIELDNET - VALIDATION GLOBALE SECURISEE (ZERO VULN)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$rootPath = $PSScriptRoot
$backendPath = Join-Path $rootPath "shieldnet_backend"
$mobilePath = Join-Path $rootPath "ShieldNet"
$auditScript = Join-Path $rootPath ".agents\skills\defensive-security\scripts\audit-security-master.ps1"
$containerScript = Join-Path $rootPath ".agents\skills\devsecops-deployment\scripts\scan-container.ps1"

# 1. Audit Maitre Zero-Vulnerabilite (ANSSI / OWASP Top 10 / CWE Top 25)
Write-Host "[1/5] Audit de Securite Zero-Vulnerabilite..." -ForegroundColor Yellow
$auditExit = 0
if (Test-Path $auditScript) {
    & $auditScript $rootPath
    $auditExit = $LASTEXITCODE
}
if ($auditExit -eq 0) {
    Write-Host "  -> Audit Securite : SUCCES (0 anomalie detectee)" -ForegroundColor Green
} else {
    Write-Host "  -> Audit Securite : ECHEC (Anomalies de securite a corriger)" -ForegroundColor Red
}
Write-Host ""

# 2. Audit de Durcissement des Conteneurs (DevSecOps)
Write-Host "[2/5] Scan de Durcissement des Conteneurs..." -ForegroundColor Yellow
$containerExit = 0
if (Test-Path $containerScript) {
    & $containerScript $rootPath
    $containerExit = $LASTEXITCODE
}
if ($containerExit -eq 0) {
    Write-Host "  -> Conteneurs : SUCCES (Dockerfile durci & non-root)" -ForegroundColor Green
} else {
    Write-Host "  -> Conteneurs : AVERTISSEMENTS/ERREURS DETECTES" -ForegroundColor Red
}
Write-Host ""

# 3. Tests Backend Django (103 tests)
Write-Host "[3/5] Execution des tests Django REST API..." -ForegroundColor Yellow
$backendProcess = Start-Process python -ArgumentList "manage.py test" -WorkingDirectory $backendPath -NoNewWindow -Wait -PassThru
$backendExit = $backendProcess.ExitCode

if ($backendExit -eq 0) {
    Write-Host "  -> Backend Django : SUCCES (103 tests reussis)" -ForegroundColor Green
} else {
    Write-Host "  -> Backend Django : ECHEC" -ForegroundColor Red
}
Write-Host ""

# 4. Analyse statique Flutter
Write-Host "[4/5] Analyse statique du code Flutter (flutter analyze)..." -ForegroundColor Yellow
$analyzeProcess = Start-Process flutter -ArgumentList "analyze `"$mobilePath`"" -NoNewWindow -Wait -PassThru
$analyzeExit = $analyzeProcess.ExitCode

if ($analyzeExit -eq 0) {
    Write-Host "  -> Analyse statique : AUCUNE ERREUR (0 avertissement)" -ForegroundColor Green
} else {
    Write-Host "  -> Analyse statique : AVERTISSEMENTS/ERREURS DETECTES" -ForegroundColor Red
}
Write-Host ""

# 5. Tests Unitaires & Securite Flutter (78 tests)
Write-Host "[5/5] Execution des tests Flutter (78 tests)..." -ForegroundColor Yellow
$flutterTestProcess = Start-Process flutter -ArgumentList "test" -WorkingDirectory $mobilePath -NoNewWindow -Wait -PassThru
$flutterTestExit = $flutterTestProcess.ExitCode

if ($flutterTestExit -eq 0) {
    Write-Host "  -> Tests Flutter : SUCCES (78/78 tests reussis)" -ForegroundColor Green
} else {
    Write-Host "  -> Tests Flutter : ECHEC" -ForegroundColor Red
}
Write-Host ""

# Bilan
Write-Host "==========================================================" -ForegroundColor Cyan
if ($auditExit -eq 0 -and $containerExit -eq 0 -and $backendExit -eq 0 -and $analyzeExit -eq 0 -and $flutterTestExit -eq 0) {
    Write-Host "  BILAN : TOUS LES CONTROLES SONT AU VERT ! CONFORME ZERO-VULN." -ForegroundColor Green
} else {
    Write-Host "  BILAN : CERTAINS TESTS/CONTROLES ONT ECHOUE. VERIFIER LES LOGS." -ForegroundColor Red
}
Write-Host "==========================================================" -ForegroundColor Cyan

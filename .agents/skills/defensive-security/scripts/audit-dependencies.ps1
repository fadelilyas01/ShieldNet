# ==============================================================================
# audit-dependencies.ps1
# Audit des dependances multi-ecosystemes sous Windows PowerShell
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$ProjectDir = "."
)

$ErrorActionPreference = "Continue"

Write-Host "`n[*] Audit des Dependances Multi-Langages (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray
Write-Host "Repertoire cible : $ProjectDir`n" -ForegroundColor DarkGray

$foundIssues = $false

# 1. Node.js (npm / pnpm / yarn)
$packageJson = Join-Path $ProjectDir "package.json"
$packageLock = Join-Path $ProjectDir "package-lock.json"
$pnpmLock = Join-Path $ProjectDir "pnpm-lock.yaml"
$yarnLock = Join-Path $ProjectDir "yarn.lock"

if (Test-Path $packageJson) {
    Write-Host "[*] Node.js detecte" -ForegroundColor Blue
    if ((Test-Path $packageLock) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "Execution de 'npm audit' (Zero-Tolerance: Low, Moderate, High, Critical)..." -ForegroundColor DarkGray
        Push-Location $ProjectDir
        npm audit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites npm detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] 0 vulnerabilite npm detectee" -ForegroundColor Green
        }
        Pop-Location
    } elseif ((Test-Path $pnpmLock) -and (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Host "Execution de 'pnpm audit' (Zero-Tolerance)..." -ForegroundColor DarkGray
        Push-Location $ProjectDir
        pnpm audit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites pnpm detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] 0 vulnerabilite pnpm detectee" -ForegroundColor Green
        }
        Pop-Location
    }
}

# 2. Python (pip-audit / safety)
$reqTxt = Join-Path $ProjectDir "requirements.txt"
$pyproject = Join-Path $ProjectDir "pyproject.toml"
$pipfile = Join-Path $ProjectDir "Pipfile.lock"

if ((Test-Path $reqTxt) -or (Test-Path $pyproject) -or (Test-Path $pipfile)) {
    Write-Host "`n[*] Python detecte" -ForegroundColor Blue
    if (Get-Command pip-audit -ErrorAction SilentlyContinue) {
        Write-Host "Execution de 'pip-audit'..." -ForegroundColor DarkGray
        Push-Location $ProjectDir
        pip-audit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites Python detectees par pip-audit" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] Dependances Python saines" -ForegroundColor Green
        }
        Pop-Location
    } elseif (Get-Command safety -ErrorAction SilentlyContinue) {
        Push-Location $ProjectDir
        safety check
        if ($LASTEXITCODE -ne 0) { $foundIssues = $true }
        Pop-Location
    } else {
        Write-Host "[!] pip-audit non installe. Installer avec : pip install pip-audit" -ForegroundColor Yellow
    }
}

# 3. .NET (dotnet list package --vulnerable)
$csprojFiles = Get-ChildItem -Path $ProjectDir -Filter "*.csproj" -Recurse -Depth 2 -ErrorAction SilentlyContinue
if ($csprojFiles) {
    Write-Host "`n[*] .NET detecte ($($csprojFiles.Count) projet(s))" -ForegroundColor Blue
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Push-Location $ProjectDir
        dotnet list package --vulnerable --include-transitive
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites .NET detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] Dependances .NET saines" -ForegroundColor Green
        }
        Pop-Location
    }
}

# 4. PHP (composer audit)
$composerLock = Join-Path $ProjectDir "composer.lock"
if (Test-Path $composerLock) {
    Write-Host "`n[*] PHP Composer detecte" -ForegroundColor Blue
    if (Get-Command composer -ErrorAction SilentlyContinue) {
        Push-Location $ProjectDir
        composer audit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites Composer detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] Dependances PHP saines" -ForegroundColor Green
        }
        Pop-Location
    }
}

# 5. Go (govulncheck)
$goSum = Join-Path $ProjectDir "go.sum"
if (Test-Path $goSum) {
    Write-Host "`n[*] Go detecte" -ForegroundColor Blue
    if (Get-Command govulncheck -ErrorAction SilentlyContinue) {
        Push-Location $ProjectDir
        govulncheck ./...
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites Go detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] Dependances Go saines" -ForegroundColor Green
        }
        Pop-Location
    } else {
        Write-Host "[!] govulncheck non installe. Installer avec : go install golang.org/x/vuln/cmd/govulncheck@latest" -ForegroundColor Yellow
    }
}

# 6. Rust (cargo audit)
$cargoLock = Join-Path $ProjectDir "Cargo.lock"
if (Test-Path $cargoLock) {
    Write-Host "`n[*] Rust Cargo detecte" -ForegroundColor Blue
    if (Get-Command cargo-audit -ErrorAction SilentlyContinue) {
        Push-Location $ProjectDir
        cargo audit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Vulnerabilites Rust detectees" -ForegroundColor Red
            $foundIssues = $true
        } else {
            Write-Host "[OK] Dependances Rust saines" -ForegroundColor Green
        }
        Pop-Location
    } else {
        Write-Host "[!] cargo-audit non installe. Installer avec : cargo install cargo-audit" -ForegroundColor Yellow
    }
}

Write-Host "`n================================================================" -ForegroundColor Gray
if ($foundIssues) {
    Write-Host "[X] Audit termine : des vulnerabilites necessitent votre attention." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] Audit termine : aucune vulnerabilite critique detectee." -ForegroundColor Green
    exit 0
}

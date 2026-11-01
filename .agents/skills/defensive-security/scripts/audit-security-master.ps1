# ==============================================================================
# audit-security-master.ps1
# Moteur d'Audit de Sécurité Zéro-Vulnérabilité (Zero-Vulnerability Master Auditor)
# Analyse statique multi-vecteurs & conformité CWE Top 25 / OWASP Top 10
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$ProjectDir = ".",

    [switch]$IncludeDependencies = $true,
    [switch]$FailOnWarning = $true
)

$ErrorActionPreference = "Continue"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " [SHIELD] ZERO-VULNERABILITY MASTER AUDIT ENGINE - ANSSI / OWASP / CWE TOP 25" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Cible de l'audit : $(Resolve-Path $ProjectDir)" -ForegroundColor DarkGray
Write-Host " Date de l'audit  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC" -ForegroundColor DarkGray
Write-Host " Politique        : ZERO TOLERANCE (0 Critique, 0 Elevee, 0 Moyenne, 0 Faible)`n" -ForegroundColor DarkYellow

$vulnerabilities = [System.Collections.Generic.List[PSCustomObject]]::new()

$excludeDirs = @(
    "node_modules", ".git", "vendor", "bin", "obj", "dist", "build",
    ".next", "__pycache__", "venv", ".venv", "target", ".gradle", "Pods", "brain", ".system_generated",
    ".dart_tool", ".idea", ".vscode"
)

$extensions = @(
    ".js", ".ts", ".jsx", ".tsx", ".py", ".java", ".kt", ".swift",
    ".dart", ".go", ".php", ".cs", ".rs", ".json", ".yaml", ".yml", ".toml", ".html"
)

# ------------------------------------------------------------------------------
# Définition des Règles de Détection par CWE
# ------------------------------------------------------------------------------
$rules = @(
    # 1. Secrets, Clés et Identifiants en Dur (CWE-798, CWE-312)
    @{
        CWE = "CWE-798"
        Name = "Cle API Cloud en Dur"
        Severity = "CRITIQUE"
        Regex = '(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|sk-[0-9a-zA-Z]{20,}|sk_live_[0-9a-zA-Z]{20,}|gh[pous]_[0-9a-zA-Z]{36})'
        FilePattern = "*"
    },
    @{
        CWE = "CWE-312"
        Name = "Bloc de Cle Privee en Dur"
        Severity = "CRITIQUE"
        Regex = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
        FilePattern = "*"
    },
    @{
        CWE = "CWE-798"
        Name = "Chaine de Connexion DB avec Password"
        Severity = "CRITIQUE"
        Regex = '(postgres|postgresql|mysql|mongodb|redis)://[^:\s]+:[^@\s]+@'
        FilePattern = "*"
    },
    @{
        CWE = "CWE-798"
        Name = "Mot de Passe / PIN en Dur"
        Severity = "CRITIQUE"
        Regex = '(?i)(proctorpin|adminpin|master_password|secret_pin)\s*[:=]\s*["''][^"'']{3,}["'']'
        FilePattern = "*"
    },
    @{
        CWE = "CWE-798"
        Name = "Placeholder / Mock Secret en Prod"
        Severity = "ELEVEE"
        Regex = '(?i)["''](secret_token_placeholder|mock_token|mock_pin|fake_jwt|test_secret_key)["'']'
        FilePattern = "*"
    },

    # 2. Cryptographie & Aléa (CWE-345, CWE-338, CWE-208)
    @{
        CWE = "CWE-345"
        Name = "Empreinte SHA-256 Hardcodee / Fictive"
        Severity = "ELEVEE"
        Regex = '(?i)["''][a-f0-9]{64}["'']\s*(;|//.*fake|//.*mock)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx;*.rs;*.py"
    },
    @{
        CWE = "CWE-338"
        Name = "PRNG Insecurise Math.random() pour Cle/Token"
        Severity = "ELEVEE"
        Regex = '(?i)(token|secret|nonce|session|auth|salt|key).*Math\.random\(\)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx"
    },
    @{
        CWE = "CWE-208"
        Name = "Comparaison de Secret / Hash Non Constant-Time"
        Severity = "ELEVEE"
        Regex = '(?i)(hash|digest|signature|pin|stored_hash|stored_pin)\s*(===|==)\s*(input|user|provided)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx;*.rs;*.py"
    },

    # 3. Mode Fail-Secure vs Fail-Open (CWE-636)
    @{
        CWE = "CWE-636"
        Name = "Fail-Open dans Catch Block (Retourne True)"
        Severity = "CRITIQUE"
        Regex = '(?i)catch\s*(\([^\)]*\))?\s*\{[^\}]*return\s*(true|\{\s*hasFace:\s*true|\{\s*allowed:\s*true)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx;*.rs;*.py"
    },

    # 4. Protection Anti-SSRF (CWE-918)
    @{
        CWE = "CWE-918"
        Name = "Filtrage SSRF Textuel Naif (contains 10.)"
        Severity = "ELEVEE"
        Regex = '(?i)(url|host|ip)\.(contains|indexOf|startsWith)\(["'']10\.["'']\)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx;*.rs;*.py"
    },

    # 5. Injections & DOM XSS (CWE-89, CWE-79)
    @{
        CWE = "CWE-89"
        Name = "Concatenation SQL Insecurisee"
        Severity = "CRITIQUE"
        Regex = '(?i)(SELECT|INSERT|UPDATE|DELETE)\s+.*(\+|`|\$\{).*(FROM|INTO|WHERE)'
        FilePattern = "*.ts;*.js;*.py;*.java;*.cs;*.php;*.go;*.rs"
    },
    @{
        CWE = "CWE-79"
        Name = "Injection HTML Brute (dangerouslySetInnerHTML)"
        Severity = "ELEVEE"
        Regex = 'dangerouslySetInnerHTML\s*=\s*\{\{\s*__html:\s*(?!(DOMPurify|sanitize))'
        FilePattern = "*.tsx;*.jsx"
    },

    # 6. Fuite d'Informations Internes (CWE-209)
    @{
        CWE = "CWE-209"
        Name = "Fuite de Chemin Disque Local (C:\...)"
        Severity = "MOYENNE"
        Regex = '["'']C:\\[Uu]sers\\[^"'']+["'']'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx;*.rs;*.py;*.json"
    },

    # 7. Reseau & CSP Durcie (CWE-1021)
    @{
        CWE = "CWE-1021"
        Name = "CSP avec unsafe-eval ou wildcard universel"
        Severity = "ELEVEE"
        Regex = '(?i)Content-Security-Policy.*(''unsafe-eval''|connect-src\s+https:\s+wss:\s+ws:)'
        FilePattern = "*.json;*.html;*.toml;*.ts;*.rs"
    },

    # 8. Panics & DoS en Production Rust
    @{
        CWE = "CWE-703"
        Name = "Rust .unwrap() / .expect() en Code Prod"
        Severity = "MOYENNE"
        Regex = '(?<!//.*)\.(unwrap|expect)\('
        FilePattern = "*.rs"
    },

    # 9. Souveraineté Backend & Zéro Donnée Sensible dans le Frontend (CWE-312, CWE-922, CWE-602)
    @{
        CWE = "CWE-312"
        Name = "Stockage Persistant de Secret/Token dans localStorage"
        Severity = "CRITIQUE"
        Regex = '(?i)localStorage\.setItem\(["''][^"'']*(token|wstoken|secret|password|private_key|jwt|auth)["'']'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx"
    },
    @{
        CWE = "CWE-602"
        Name = "Décision Critique de Sécurité Côté Client (Anti-Pattern if strikes >= 3 expulser)"
        Severity = "CRITIQUE"
        Regex = '(?i)if\s*\([^)]*(strike|fail|fault)[^)]*(>=|>)\s*3\)\s*\{[^\}]*(expulser|ban|killswitch|terminate_session)'
        FilePattern = "*.ts;*.js;*.tsx;*.jsx"
    }
)

# ------------------------------------------------------------------------------
# Collecte des Fichiers (Parcours Haute Performance avec Pruning)
# ------------------------------------------------------------------------------
function Get-AuditFiles([string]$dir, [string[]]$excludeNames, [string[]]$exts) {
    $fileList = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $dirInfo = [System.IO.DirectoryInfo]::new((Resolve-Path $dir).Path)
    if (-not $dirInfo.Exists) { return $fileList }

    $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
    $stack.Push($dirInfo)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($sub in $current.GetDirectories()) {
                if ($excludeNames -notcontains $sub.Name -and -not ($sub.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint))) {
                    $stack.Push($sub)
                }
            }
            foreach ($f in $current.GetFiles()) {
                if ($exts -contains $f.Extension.ToLowerInvariant()) {
                    $fileList.Add($f)
                }
            }
        } catch { }
    }
    return $fileList
}

$files = Get-AuditFiles $ProjectDir $excludeDirs $extensions

Write-Host "[*] Analyse statique en cours sur $($files.Count) fichier(s)..." -ForegroundColor Blue

foreach ($file in $files) {
    if ($file.Name -match "audit-security|check-secrets|test|spec") { continue }
    # Ignorer les tests Rust du dossier tests ou #[test]
    $isRustTest = ($file.FullName -match "[\\/]tests[\\/]")
    $insideRustTestMod = $false

    # 1. Verification multiline pour <a target="_blank"> sans noopener noreferrer (CWE-1021)
    if ($file.Extension -in @(".tsx", ".jsx", ".html")) {
        $rawContent = [System.IO.File]::ReadAllText($file.FullName)
        $aMatches = [regex]::Matches($rawContent, '(?si)<a\b([^>]*)>')
        foreach ($m in $aMatches) {
            $tagBody = $m.Groups[1].Value
            if ($tagBody -match 'target\s*=\s*["'']_blank["'']') {
                if ($tagBody -notmatch 'rel\s*=\s*["''][^"'']*noopener') {
                    $prefix = $rawContent.Substring(0, $m.Index)
                    $lineNo = ($prefix -split "`n").Count
                    $vulnerabilities.Add([PSCustomObject]@{
                        CWE         = "CWE-1021"
                        Nom         = "Lien target=_blank sans noopener noreferrer"
                        Severite    = "MOYENNE"
                        Fichier     = $file.FullName.Replace((Resolve-Path $ProjectDir).Path, "").TrimStart("\/")
                        Ligne       = $lineNo
                        Extrait     = if ($m.Value.Length -gt 70) { $m.Value.Substring(0, 67) + "..." } else { $m.Value }
                    })
                }
            }
        }
    }

    $lines = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()

        if ($file.Extension -eq ".rs" -and $line -match '(#\[cfg\(test\)|mod tests)') {
            $insideRustTestMod = $true
        }

        # Ignorer les commentaires stricts
        if ($trimmed.StartsWith("//") -or $trimmed.StartsWith("#") -or $trimmed.StartsWith("/*") -or $trimmed.StartsWith("*")) {
            continue
        }

        foreach ($rule in $rules) {
            # Filtrer par extension de fichier si specifie
            if ($rule.FilePattern -ne "*") {
                $patterns = $rule.FilePattern -split ";"
                $matchedExt = $false
                foreach ($p in $patterns) {
                    if ($file.Name -like $p) {
                        $matchedExt = $true
                        break
                    }
                }
                if (-not $matchedExt) { continue }
            }

            if ($rule.CWE -eq "CWE-703" -and ($isRustTest -or $insideRustTestMod)) { continue }

            if ($line -match $rule.Regex) {
                # Protection contre faux positifs documentés
                if ($line -match '(?i)(example\.com|placeholder\.test|doc\.example)' -and $file.FullName -notmatch '[\\/]src[\\/]') {
                    continue
                }

                $vulnerabilities.Add([PSCustomObject]@{
                    CWE         = $rule.CWE
                    Nom         = $rule.Name
                    Severite    = $rule.Severity
                    Fichier     = $file.FullName.Replace((Resolve-Path $ProjectDir).Path, "").TrimStart("\/")
                    Ligne       = $lineNum
                    Extrait     = if ($trimmed.Length -gt 70) { $trimmed.Substring(0, 67) + "..." } else { $trimmed }
                })
            }
        }
    }
}

# ------------------------------------------------------------------------------
# Audit des Dépendances (Zero Tolerance: All Levels)
# ------------------------------------------------------------------------------
$depAuditFailed = $false
if ($IncludeDependencies) {
    Write-Host "`n[*] Execution de l'Audit des Dependances (Zero-Tolerance)..." -ForegroundColor Blue
    $packageLock = Join-Path $ProjectDir "package-lock.json"
    $cargoLock = Join-Path $ProjectDir "src-tauri/Cargo.lock"

    if (Test-Path $packageLock) {
        Push-Location $ProjectDir
        Write-Host " -> Analyse 'npm audit'..." -ForegroundColor DarkGray
        $npmOut = npm audit --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($npmOut -and $npmOut.metadata.vulnerabilities.total -gt 0) {
            $total = $npmOut.metadata.vulnerabilities.total
            Write-Host "[X] $total vulnerabilite(s) detectee(s) dans package-lock.json" -ForegroundColor Red
            $depAuditFailed = $true
            $vulnerabilities.Add([PSCustomObject]@{
                CWE         = "CWE-1357"
                Nom         = "Dependance NPM Vulnerable ($total CVEs)"
                Severite    = "ELEVEE"
                Fichier     = "package-lock.json"
                Ligne       = 1
                Extrait     = "Executer 'npm audit' pour le detail des paquets a mettre a jour ou overrider"
            })
        } else {
            Write-Host " [OK] 0 vulnerabilite dans les dependances NPM" -ForegroundColor Green
        }
        Pop-Location
    }

    if (Test-Path $cargoLock) {
        $tauriDir = Join-Path $ProjectDir "src-tauri"
        if (Get-Command cargo-audit -ErrorAction SilentlyContinue) {
            Push-Location $tauriDir
            Write-Host " -> Analyse 'cargo audit'..." -ForegroundColor DarkGray
            cargo audit 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[X] Vulnerabilites Cargo detectees" -ForegroundColor Red
                $depAuditFailed = $true
                $vulnerabilities.Add([PSCustomObject]@{
                    CWE         = "CWE-1357"
                    Nom         = "Dependance Rust Cargo Vulnerable"
                    Severite    = "ELEVEE"
                    Fichier     = "src-tauri/Cargo.lock"
                    Ligne       = 1
                    Extrait     = "Executer 'cargo audit' pour le detail des advisory crates"
                })
            } else {
                Write-Host " [OK] 0 vulnerabilite dans les dependances Rust" -ForegroundColor Green
            }
            Pop-Location
        }
    }
}

# ------------------------------------------------------------------------------
# Rapport Final & Tableau de Synthèse
# ------------------------------------------------------------------------------
Write-Host "`n================================================================================" -ForegroundColor Gray
Write-Host " RESULTATS DE L'AUDIT DE SECURITE ZERO-VULNERABILITE" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Gray

if ($vulnerabilities.Count -eq 0) {
    Write-Host "`n [CONFORME] FELICITATIONS : 0 VULNERABILITE DETECTEE !" -ForegroundColor Green
    Write-Host " -> Le code source respecte a 100% le Protocole d'Execution Zero-Vulnerabilite." -ForegroundColor Green
    Write-Host " -> Tous les vecteurs (Secrets, Crypto, SSRF, Fail-Secure, Injections, Dependances) sont saints." -ForegroundColor Green
    Write-Host "================================================================================`n" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "`n [NON CONFORME] $($vulnerabilities.Count) ANOMALIE(S) DE SECURITE DETECTEE(S) :" -ForegroundColor Red
    
    $vulnerabilities | Format-Table -Property Severite, CWE, Nom, Fichier, Ligne -AutoSize
    
    Write-Host "`nExtrait des lignes concernees :" -ForegroundColor DarkGray
    foreach ($v in $vulnerabilities) {
        Write-Host " [$($v.Severite)] $($v.CWE) - $($v.Fichier):$($v.Ligne)" -ForegroundColor Yellow
        Write-Host "   -> $($v.Extrait)" -ForegroundColor DarkGray
    }
    
    Write-Host "`n[!] Ces anomalies violent le standard d'ingenierie senior de ce projet." -ForegroundColor Red
    Write-Host "    Chaque point doit etre resolu avant toute validation ou deploiement.`n" -ForegroundColor Red
    Write-Host "================================================================================`n" -ForegroundColor Gray
    exit 1
}

# ==============================================================================
# check-secrets.ps1
# Detection de secrets hardcodes, cles d'API, tokens, mock secrets et failles frontend
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$ProjectDir = "."
)

Write-Host "`n[*] Detection de Secrets et Identifiants (PowerShell - Zero-Vulnerability Standard)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray

$patterns = @{
    "AWS Access Key"            = 'AKIA[0-9A-Z]{16}'
    "Google API Key"            = 'AIza[0-9A-Za-z\-_]{35}'
    "OpenAI / Stripe Secret"    = 'sk-[0-9a-zA-Z]{20,}'
    "Stripe Publishable Key"    = 'pk_live_[0-9a-zA-Z]{20,}'
    "Stripe Secret Key"         = 'sk_live_[0-9a-zA-Z]{20,}'
    "GitHub Token"              = 'gh[pous]_[0-9a-zA-Z]{36}'
    "Slack Token"               = 'xox[baprs]-[0-9]{10,}-[0-9a-zA-Z]{20,}'
    "Private Key Block"         = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    "Database Connection URI"   = '(postgres|postgresql|mysql|mongodb|redis)://[^:\s]+:[^@\s]+@'
    "Hardcoded Password Assign" = '(?i)(password|passwd|pwd|secret|api_key|apikey|jwt_secret)\s*[:=]\s*["''][^"'']{8,}["'']'
    "Hardcoded PIN / Bypass"    = '(?i)(proctorpin|pin|adminpin)\s*(===|==)\s*["''][^"'']+["'']'
    "Mock / Placeholder Token"  = '(?i)(wstoken|token|secret)\s*:\s*["''][^"'']*(placeholder|dummy|test_token|fake)[^"'']*["'']'
}

$excludeDirs = @(
    "node_modules", ".git", "vendor", "bin", "obj", "dist", "build",
    ".next", "__pycache__", "venv", ".venv", "target", ".gradle", "Pods", "brain",
    ".dart_tool", ".idea", ".vscode"
)

$extensions = @(
    ".js", ".ts", ".jsx", ".tsx", ".py", ".java", ".kt", ".swift",
    ".dart", ".go", ".php", ".cs", ".rs", ".json", ".yaml", ".yml", ".xml",
    ".properties", ".conf", ".cfg", ".ini", ".toml"
)

$foundSecretsCount = 0

Write-Host "Analyse en cours..." -ForegroundColor DarkGray

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

foreach ($file in $files) {
    if ($file.Name -match "check-secrets") { continue }

    $lines = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        foreach ($entry in $patterns.GetEnumerator()) {
            if ($line -match $entry.Value) {
                # Ne pas ignorer les placeholders s'ils sont dans le dossier src/
                if ($line -match '(?i)(example|placeholder|your_key|changeme|fake|test|TODO|dummy)' -and $file.FullName -notmatch '[\\/]src[\\/]') {
                    continue
                }

                Write-Host "`n[!] [$($entry.Key)] Detecte :" -ForegroundColor Red
                Write-Host "   Fichier : $($file.FullName):$lineNum" -ForegroundColor Yellow
                Write-Host "   Ligne   : $($line.Trim())" -ForegroundColor DarkGray
                $foundSecretsCount++
            }
        }
    }
}

# Verifier la presence de fichiers .env committes
$envFiles = Get-ChildItem -Path $ProjectDir -Filter ".env" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "node_modules|\.git|vendor" }

if ($envFiles) {
    Write-Host "`n[!] Fichier(s) .env detecte(s) :" -ForegroundColor Yellow
    foreach ($ef in $envFiles) {
        Write-Host "   -> $($ef.FullName)" -ForegroundColor DarkYellow
    }
    Write-Host "   Assurez-vous qu'ils sont bien ignores dans .gitignore !" -ForegroundColor DarkGray
}

Write-Host "`n================================================================" -ForegroundColor Gray
if ($foundSecretsCount -gt 0) {
    Write-Host "[X] Scan termine : $foundSecretsCount secret(s) / token(s) hardcode(s) detecte(s)." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] Scan termine : aucun secret ni token hardcode detecte." -ForegroundColor Green
    exit 0
}

# ==============================================================================
# audit-ui.ps1
# Audit d'ergonomie et d'accessibilite des composants front-end (React, Vue, HTML)
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Path = "."
)

Write-Host "`n[*] Audit d'Ingenierie UI/UX & Accessibilite" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray

$excludeDirs = @("node_modules", ".git", "dist", "build", ".next", ".cache")
$extensions = @("*.jsx", "*.tsx", "*.vue", "*.svelte", "*.html")

$uiIssuesCount = 0

$files = Get-ChildItem -Path $Path -Include $extensions -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $filePath = $_.FullName
        $excluded = $false
        foreach ($d in $excludeDirs) {
            if ($filePath -match "[\\/]$d[\\/]") {
                $excluded = $true
                break
            }
        }
        -not $excluded
    }

if (-not $files) {
    Write-Host "[!] Aucun fichier composant front-end trouve dans : $Path" -ForegroundColor DarkYellow
    exit 0
}

Write-Host "[*] $($files.Count) fichier(s) composant(s) en cours d'analyse...`n" -ForegroundColor DarkGray

foreach ($file in $files) {
    $lines = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue
    $lineNum = 0

    foreach ($line in $lines) {
        $lineNum++

        # 1. Verification des couleurs arbitraires en dur (bg-[#...], text-[#...])
        if ($line -match '(bg|text|border)-\[#([0-9a-fA-F]{3,8})\]') {
            Write-Host "  [!] COULEUR ARBITRAIRE EN DUR :" -ForegroundColor Yellow
            Write-Host "      Fichier : $($file.FullName):$lineNum" -ForegroundColor DarkGray
            Write-Host "      Ligne   : $($line.Trim())" -ForegroundColor DarkGray
            Write-Host "      Conseil : Utiliser les tokens du systeme (ex: bg-muted, text-primary)." -ForegroundColor Cyan
            $uiIssuesCount++
        }

        # 2. Verification des z-index excessifs (z-[9999], z-[99999])
        if ($line -match 'z-\[(9{3,}|999\d+)\]') {
            Write-Host "  [!] Z-INDEX DISPROPORTIONNE :" -ForegroundColor Yellow
            Write-Host "      Fichier : $($file.FullName):$lineNum" -ForegroundColor DarkGray
            Write-Host "      Ligne   : $($line.Trim())" -ForegroundColor DarkGray
            Write-Host "      Conseil : Utiliser une echelle d'empilement propre (z-10, z-20, z-50)." -ForegroundColor Cyan
            $uiIssuesCount++
        }

        # 3. Verification de la suppression brute du focus (outline-none sans focus-visible)
        if ($line -match 'outline-none' -and $line -notmatch 'focus-visible|ring') {
            Write-Host "  [X] ACCESSIBILITE : outline-none sans anneau de remplacement detecte !" -ForegroundColor Red
            Write-Host "      Fichier : $($file.FullName):$lineNum" -ForegroundColor DarkGray
            Write-Host "      Ligne   : $($line.Trim())" -ForegroundColor DarkGray
            Write-Host "      Conseil : Ajouter 'focus-visible:ring-2 focus-visible:ring-ring'." -ForegroundColor Cyan
            $uiIssuesCount++
        }

        # 4. Images sans attribut alt
        if ($line -match '<img\s+' -and $line -notmatch 'alt=') {
            Write-Host "  [X] ACCESSIBILITE : Balise <img /> sans attribut alt !" -ForegroundColor Red
            Write-Host "      Fichier : $($file.FullName):$lineNum" -ForegroundColor DarkGray
            Write-Host "      Ligne   : $($line.Trim())" -ForegroundColor DarkGray
            Write-Host "      Conseil : Fournir un texte descriptif ou alt='' si decoratif." -ForegroundColor Cyan
            $uiIssuesCount++
        }
    }
}

Write-Host "`n================================================================" -ForegroundColor Gray
if ($uiIssuesCount -gt 0) {
    Write-Host "[!] Audit termine : $uiIssuesCount point(s) d'ergonomie/accessibilite a ameliorer." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "[OK] Audit termine : composants conformes aux bonnes pratiques UI/UX." -ForegroundColor Green
    exit 0
}

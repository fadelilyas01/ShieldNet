# ==============================================================================
# verify-vercel.ps1
# Validation DevSecOps des configurations de déploiement Vercel Zéro-Erreur
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Path = "."
)

Write-Host "`n[*] Audit de Deploiement Cloud Vercel Zero-Erreur" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Gray

$issuesCount = 0

$resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Host "[X] Chemin de projet introuvable : $Path" -ForegroundColor Red
    exit 1
}

$projectDir = $resolvedPath.Path
Write-Host "[*] Analyse du projet : $projectDir`n" -ForegroundColor DarkGray

# ------------------------------------------------------------------------------
# 1. Verification de vercel.json
# ------------------------------------------------------------------------------
$vercelJsonPath = Join-Path $projectDir "vercel.json"
if (-not (Test-Path $vercelJsonPath)) {
    Write-Host "  [X] FICHIER MANQUANT : vercel.json absent a la racine du projet !" -ForegroundColor Red
    Write-Host "      Action : Creer vercel.json avec configuration framework et rewrites SPA." -ForegroundColor Cyan
    $issuesCount++
} else {
    try {
        $vercelContent = Get-Content -Raw -Path $vercelJsonPath
        $vercelConfig = $vercelContent | ConvertFrom-Json
        Write-Host "  [OK] vercel.json syntaxe JSON valide." -ForegroundColor Green

        # Verification des rewrites SPA (Attention aux regex incompatibles avec path-to-regexp)
        $hasInvalidRegex = $false
        $hasCatchAll = $false

        if ($vercelConfig.rewrites) {
            foreach ($rw in $vercelConfig.rewrites) {
                if ($rw.source -match '\(\?!') {
                    $hasInvalidRegex = $true
                }
                if ($rw.source -eq "/(.*)" -or $rw.source -eq "/:path*") {
                    $hasCatchAll = $true
                }
            }
        }

        if ($hasInvalidRegex) {
            Write-Host "  [X] REGEX INVALIDE POUR VERCEL : Les assertions negatives (?!...) ne sont pas supportees par le moteur path-to-regexp de Vercel !" -ForegroundColor Red
            Write-Host "      Action : Remplacer par 'source: /(.*)' ou '/:path*' (Vercel sert les fichiers statiques en priorite automatique)." -ForegroundColor Cyan
            $issuesCount++
        } elseif ($hasCatchAll) {
            Write-Host "  [OK] Regle de rewrite SPA conforme au standard officiel Vercel ('/(.*)')." -ForegroundColor Green
        } else {
            Write-Host "  [!] REWRITE MANQUANTE : Aucune regle de redirection SPA vers /index.html." -ForegroundColor Yellow
            $issuesCount++
        }

        # Verification des headers de securite et Permissions-Policy
        $hasPermissionsPolicy = $false
        if ($vercelConfig.headers) {
            foreach ($hGroup in $vercelConfig.headers) {
                if ($hGroup.headers) {
                    foreach ($h in $hGroup.headers) {
                        if ($h.key -eq "Permissions-Policy" -and $h.value -match "camera") {
                            $hasPermissionsPolicy = $true
                            break
                        }
                    }
                }
            }
        }

        if ($hasPermissionsPolicy) {
            Write-Host "  [OK] Permissions-Policy configuree pour les peripheriques (camera, microphone)." -ForegroundColor Green
        } else {
            Write-Host "  [!] PERMISSIONS MANQUANTES : Permissions-Policy non configuree dans vercel.json." -ForegroundColor Yellow
            Write-Host "      Conseil : Ajouter Permissions-Policy: camera=*, microphone=*." -ForegroundColor Cyan
            $issuesCount++
        }

        # Verification de ignoreCommand (Evite les builds echoues sur des branches annexes comme gh-pages)
        if ($vercelConfig.ignoreCommand) {
            Write-Host "  [OK] ignoreCommand configure pour filtrer les branches de deploiement." -ForegroundColor Green
        } else {
            Write-Host "  [i] INFO : ignoreCommand non defini dans vercel.json (recommande pour ignorer les branches non-production)." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  [X] ERREUR DE SYNTAXE dans vercel.json : $($_.Exception.Message)" -ForegroundColor Red
        $issuesCount++
    }
}

# ------------------------------------------------------------------------------
# 2. Verification de package.json
# ------------------------------------------------------------------------------
$packageJsonPath = Join-Path $projectDir "package.json"
if (Test-Path $packageJsonPath) {
    try {
        $pkg = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
        
        $hasVercelCli = $false
        if ($pkg.devDependencies -and $pkg.devDependencies.vercel) {
            $hasVercelCli = $true
        }
        if ($pkg.dependencies -and $pkg.dependencies.vercel) {
            $hasVercelCli = $true
        }

        if ($hasVercelCli) {
            Write-Host "  [!] PAQUET INUTILE : 'vercel' est liste dans package.json." -ForegroundColor Yellow
            Write-Host "      Conseil : Supprimer 'vercel' des dependances (Vercel Cloud integre deja sa propre CLI)." -ForegroundColor Cyan
            $issuesCount++
        } else {
            Write-Host "  [OK] package.json epure (aucun CLI Vercel redondant)." -ForegroundColor Green
        }

        if ($pkg.scripts -and $pkg.scripts.build) {
            Write-Host "  [OK] Script de build present : 'npm run $($pkg.scripts.build)'" -ForegroundColor Green
        } else {
            Write-Host "  [X] SCRIPT MANQUANT : Aucun script 'build' dans package.json !" -ForegroundColor Red
            $issuesCount++
        }
    } catch {
        Write-Host "  [!] Impossible de parser package.json." -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 3. Verification de vite.config.ts (Base path)
# ------------------------------------------------------------------------------
$viteConfigPath = Join-Path $projectDir "vite.config.ts"
if (Test-Path $viteConfigPath) {
    $viteContent = Get-Content -Raw -Path $viteConfigPath
    if ($viteContent -match 'base:\s*["'']\./["'']' -and $viteContent -notmatch 'process\.env') {
        Write-Host "  [!] CHEMIN RELATIF DANGEREUX : 'base: ./' en dur dans vite.config.ts !" -ForegroundColor Yellow
        Write-Host "      Action : Utiliser 'base: process.env.VITE_BASE_PATH || \"/\"' pour Vercel." -ForegroundColor Cyan
        $issuesCount++
    } else {
        Write-Host "  [OK] Configuration de base path securisee pour Vercel." -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 4. Synthese Finale
# ------------------------------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Gray

if ($issuesCount -eq 0) {
    Write-Host "[OK] Configuration Vercel conforme et validee : Pret pour deploiement zero-erreur !`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[X] $issuesCount anomalie(s) detectee(s). Corrigez les points ci-dessus avant de deployer.`n" -ForegroundColor Red
    exit 1
}

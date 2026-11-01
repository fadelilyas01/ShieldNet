#!/bin/bash
# ==============================================================================
# check-secrets.sh
# Détection de secrets dans le code source
# Recherche des patterns courants de secrets hardcodés
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Détection de secrets dans le code source${NC}"
echo "================================================================"

PROJECT_DIR="${1:-.}"
FOUND_SECRETS=0

# Patterns de secrets à rechercher
declare -a PATTERNS=(
    # API Keys
    'AKIA[0-9A-Z]{16}'                          # AWS Access Key
    'AIza[0-9A-Za-z\-_]{35}'                     # Google API Key
    'sk-[0-9a-zA-Z]{20,}'                        # OpenAI / Stripe Secret Key
    'pk_live_[0-9a-zA-Z]{20,}'                   # Stripe Publishable Key
    'sk_live_[0-9a-zA-Z]{20,}'                   # Stripe Secret Key
    'ghp_[0-9a-zA-Z]{36}'                        # GitHub Personal Access Token
    'gho_[0-9a-zA-Z]{36}'                        # GitHub OAuth Token
    'xoxb-[0-9]{10,}-[0-9a-zA-Z]{20,}'          # Slack Bot Token
    'xoxp-[0-9]{10,}-[0-9a-zA-Z]{20,}'          # Slack User Token

    # Secrets génériques
    'password\s*[:=]\s*["\x27][^"\x27]{8,}'      # password = "..."
    'secret\s*[:=]\s*["\x27][^"\x27]{8,}'        # secret = "..."
    'api_key\s*[:=]\s*["\x27][^"\x27]{8,}'       # api_key = "..."
    'apikey\s*[:=]\s*["\x27][^"\x27]{8,}'        # apikey = "..."
    'access_token\s*[:=]\s*["\x27][^"\x27]{8,}'  # access_token = "..."
    'auth_token\s*[:=]\s*["\x27][^"\x27]{8,}'    # auth_token = "..."
    'private_key\s*[:=]\s*["\x27][^"\x27]{8,}'   # private_key = "..."

    # Clés privées
    '-----BEGIN RSA PRIVATE KEY-----'
    '-----BEGIN PRIVATE KEY-----'
    '-----BEGIN EC PRIVATE KEY-----'
    '-----BEGIN OPENSSH PRIVATE KEY-----'

    # Connection strings
    'mongodb(\+srv)?://[^\s"]{10,}'              # MongoDB
    'postgres://[^\s"]{10,}'                      # PostgreSQL
    'mysql://[^\s"]{10,}'                         # MySQL
    'redis://[^\s"]{10,}'                         # Redis
)

# Extensions à scanner
EXTENSIONS="js,ts,jsx,tsx,py,java,kt,swift,dart,rb,go,php,cs,json,yaml,yml,xml,env,properties,conf,cfg,ini,toml"

# Fichiers/dossiers à exclure
EXCLUDE_DIRS="node_modules,.git,vendor,build,dist,.next,__pycache__,venv,.venv,target,.gradle,Pods"

echo -e "${BLUE}Répertoire scanné : ${PROJECT_DIR}${NC}"
echo ""

for pattern in "${PATTERNS[@]}"; do
    # Recherche du pattern
    RESULTS=$(grep -rnE "$pattern" "$PROJECT_DIR" \
        --include="*.{$EXTENSIONS}" \
        $(echo "$EXCLUDE_DIRS" | tr ',' '\n' | sed 's/^/--exclude-dir=/') \
        2>/dev/null || true)

    if [ -n "$RESULTS" ]; then
        echo -e "${RED}❌ Secret potentiel trouvé (pattern: ${pattern:0:30}...):${NC}"
        echo "$RESULTS" | head -10
        echo ""
        FOUND_SECRETS=1
    fi
done

# Vérifier les fichiers .env committés
echo -e "${BLUE}Vérification des fichiers .env...${NC}"
ENV_FILES=$(find "$PROJECT_DIR" -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)
if [ -n "$ENV_FILES" ]; then
    echo -e "${YELLOW}⚠️ Fichiers .env trouvés (vérifier qu'ils ne contiennent pas de secrets en production) :${NC}"
    echo "$ENV_FILES"
    echo ""
fi

# Vérifier que .env est dans .gitignore
if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q "^\.env" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ '.env' n'est pas dans .gitignore${NC}"
        FOUND_SECRETS=1
    else
        echo -e "${GREEN}✅ '.env' est dans .gitignore${NC}"
    fi
fi

echo ""
echo "================================================================"
if [ $FOUND_SECRETS -eq 0 ]; then
    echo -e "${GREEN}✅ Aucun secret potentiel détecté${NC}"
else
    echo -e "${RED}❌ Des secrets potentiels ont été détectés${NC}"
    echo -e "${YELLOW}Recommandations :${NC}"
    echo "  1. Remplacer les secrets par des variables d'environnement"
    echo "  2. Utiliser un gestionnaire de secrets (Vault, AWS Secrets Manager)"
    echo "  3. Révoquer et régénérer les secrets compromis"
    echo "  4. Vérifier l'historique Git : git log --all -p -- <fichier>"
    echo ""
    echo -e "${YELLOW}Outils recommandés pour une analyse plus approfondie :${NC}"
    echo "  - truffleHog : trufflesecurity/trufflehog"
    echo "  - gitleaks  : gitleaks/gitleaks"
    echo "  - detect-secrets : Yelp/detect-secrets"
fi

exit $FOUND_SECRETS


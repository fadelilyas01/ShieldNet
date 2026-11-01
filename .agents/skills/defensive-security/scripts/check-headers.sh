#!/bin/bash
# ==============================================================================
# check-headers.sh
# Vérification des headers de sécurité HTTP d'un site web
# Usage: ./check-headers.sh https://example.com
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

URL="${1:-}"
if [ -z "$URL" ]; then
    echo "Usage: $0 <URL>"
    echo "Exemple: $0 https://example.com"
    exit 1
fi

echo -e "${BLUE}🔍 Vérification des headers de sécurité${NC}"
echo -e "${BLUE}URL: ${URL}${NC}"
echo "================================================================"

# Récupérer les headers
HEADERS=$(curl -sI -L --max-time 10 "$URL" 2>/dev/null || echo "ERREUR")

if [ "$HEADERS" = "ERREUR" ]; then
    echo -e "${RED}❌ Impossible de contacter ${URL}${NC}"
    exit 1
fi

SCORE=0
TOTAL=10

# Fonction de vérification d'un header
check_header() {
    local header_name="$1"
    local expected_value="${2:-}"
    local description="$3"

    local value=$(echo "$HEADERS" | grep -i "^${header_name}:" | head -1 | sed 's/^[^:]*: //' | tr -d '\r')

    if [ -n "$value" ]; then
        echo -e "${GREEN}✅ ${header_name}${NC}"
        echo "   Valeur: ${value}"
        if [ -n "$expected_value" ]; then
            if echo "$value" | grep -qi "$expected_value"; then
                echo -e "   ${GREEN}↳ Configuration recommandée détectée${NC}"
            else
                echo -e "   ${YELLOW}↳ Valeur recommandée: ${expected_value}${NC}"
            fi
        fi
        SCORE=$((SCORE + 1))
    else
        echo -e "${RED}❌ ${header_name} — ABSENT${NC}"
        echo -e "   ${YELLOW}${description}${NC}"
        if [ -n "$expected_value" ]; then
            echo -e "   Valeur recommandée: ${expected_value}"
        fi
    fi
    echo ""
}

echo ""

# Vérifications
check_header "Strict-Transport-Security" \
    "max-age=31536000" \
    "Force HTTPS. Protège contre le SSL-stripping."

check_header "Content-Security-Policy" \
    "default-src" \
    "Contrôle les ressources chargées. Protège contre XSS."

check_header "X-Content-Type-Options" \
    "nosniff" \
    "Empêche le MIME-sniffing."

check_header "X-Frame-Options" \
    "DENY" \
    "Protège contre le clickjacking."

check_header "Referrer-Policy" \
    "strict-origin" \
    "Contrôle les informations de referrer envoyées."

check_header "Permissions-Policy" \
    "" \
    "Contrôle l'accès aux APIs du navigateur (caméra, micro, etc.)."

check_header "Cross-Origin-Opener-Policy" \
    "same-origin" \
    "Isole le contexte de navigation (protection Spectre)."

check_header "Cross-Origin-Embedder-Policy" \
    "require-corp" \
    "Requiert que les ressources accordent la permission d'être chargées."

check_header "Cross-Origin-Resource-Policy" \
    "same-origin" \
    "Empêche d'autres origines de lire vos ressources."

# Vérifier l'absence de headers dangereux
echo -e "${BLUE}--- Headers à NE PAS exposer ---${NC}"
echo ""

BAD_HEADERS=("Server" "X-Powered-By" "X-AspNet-Version" "X-AspNetMvc-Version")
for bad_header in "${BAD_HEADERS[@]}"; do
    bad_value=$(echo "$HEADERS" | grep -i "^${bad_header}:" | head -1 | sed 's/^[^:]*: //' | tr -d '\r')
    if [ -n "$bad_value" ]; then
        echo -e "${YELLOW}⚠️ ${bad_header}: ${bad_value}${NC}"
        echo "   Ce header expose des informations sur la stack technique."
    else
        echo -e "${GREEN}✅ ${bad_header} — Non exposé${NC}"
        SCORE=$((SCORE + 1))
    fi
done

echo ""
echo "================================================================"
TOTAL=$((TOTAL + ${#BAD_HEADERS[@]}))
PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $PERCENTAGE -ge 80 ]; then
    echo -e "${GREEN}Score: ${SCORE}/${TOTAL} (${PERCENTAGE}%) — Bon${NC}"
elif [ $PERCENTAGE -ge 50 ]; then
    echo -e "${YELLOW}Score: ${SCORE}/${TOTAL} (${PERCENTAGE}%) — À améliorer${NC}"
else
    echo -e "${RED}Score: ${SCORE}/${TOTAL} (${PERCENTAGE}%) — Insuffisant${NC}"
fi

echo ""
echo "Références :"
echo "  - https://securityheaders.com/?q=${URL}"
echo "  - https://observatory.mozilla.org/analyze/${URL#https://}"
echo "  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers"


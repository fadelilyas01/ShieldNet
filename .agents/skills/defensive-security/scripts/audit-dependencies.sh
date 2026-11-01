#!/bin/bash
# ==============================================================================
# audit-dependencies.sh
# Audit des dépendances pour vulnérabilités connues
# Détecte automatiquement le gestionnaire de paquets et lance l'audit
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Audit des dépendances - Détection des vulnérabilités${NC}"
echo "================================================================"

PROJECT_DIR="${1:-.}"
FOUND_ISSUES=0

# Node.js (npm)
if [ -f "$PROJECT_DIR/package-lock.json" ] || [ -f "$PROJECT_DIR/package.json" ]; then
    echo -e "\n${BLUE}📦 Node.js (npm) détecté${NC}"
    if command -v npm &> /dev/null; then
        echo "Exécution de 'npm audit --production'..."
        cd "$PROJECT_DIR"
        if npm audit --production 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité npm trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités npm détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ npm non installé, audit ignoré${NC}"
    fi
fi

# Node.js (pnpm)
if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
    echo -e "\n${BLUE}📦 Node.js (pnpm) détecté${NC}"
    if command -v pnpm &> /dev/null; then
        echo "Exécution de 'pnpm audit --production'..."
        cd "$PROJECT_DIR"
        if pnpm audit --production 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité pnpm trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités pnpm détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ pnpm non installé, audit ignoré${NC}"
    fi
fi

# Node.js (yarn)
if [ -f "$PROJECT_DIR/yarn.lock" ]; then
    echo -e "\n${BLUE}📦 Node.js (yarn) détecté${NC}"
    if command -v yarn &> /dev/null; then
        echo "Exécution de 'yarn audit --groups dependencies'..."
        cd "$PROJECT_DIR"
        if yarn audit --groups dependencies 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité yarn trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités yarn détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ yarn non installé, audit ignoré${NC}"
    fi
fi

# Python (pip)
if [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/Pipfile.lock" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    echo -e "\n${BLUE}🐍 Python détecté${NC}"
    if command -v pip-audit &> /dev/null; then
        echo "Exécution de 'pip-audit'..."
        cd "$PROJECT_DIR"
        if pip-audit 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité pip trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités pip détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    elif command -v safety &> /dev/null; then
        echo "Exécution de 'safety check'..."
        cd "$PROJECT_DIR"
        if safety check 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité pip trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités pip détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ pip-audit/safety non installé. Installer avec : pip install pip-audit${NC}"
    fi
fi

# .NET
if find "$PROJECT_DIR" -maxdepth 2 -name "*.csproj" -print -quit 2>/dev/null | grep -q .; then
    echo -e "\n${BLUE}🔷 .NET détecté${NC}"
    if command -v dotnet &> /dev/null; then
        echo "Exécution de 'dotnet list package --vulnerable'..."
        cd "$PROJECT_DIR"
        if dotnet list package --vulnerable 2>/dev/null; then
            echo -e "${GREEN}✅ Audit .NET terminé${NC}"
        else
            echo -e "${YELLOW}⚠️ Impossible de vérifier les dépendances .NET${NC}"
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ dotnet non installé, audit ignoré${NC}"
    fi
fi

# Ruby
if [ -f "$PROJECT_DIR/Gemfile.lock" ]; then
    echo -e "\n${BLUE}💎 Ruby détecté${NC}"
    if command -v bundle-audit &> /dev/null; then
        echo "Exécution de 'bundle-audit check --update'..."
        cd "$PROJECT_DIR"
        if bundle-audit check --update 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité Ruby trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités Ruby détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ bundle-audit non installé. Installer avec : gem install bundler-audit${NC}"
    fi
fi

# Go
if [ -f "$PROJECT_DIR/go.sum" ]; then
    echo -e "\n${BLUE}🐹 Go détecté${NC}"
    if command -v govulncheck &> /dev/null; then
        echo "Exécution de 'govulncheck ./...'..."
        cd "$PROJECT_DIR"
        if govulncheck ./... 2>/dev/null; then
            echo -e "${GREEN}✅ Aucune vulnérabilité Go trouvée${NC}"
        else
            echo -e "${RED}❌ Vulnérabilités Go détectées${NC}"
            FOUND_ISSUES=1
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠️ govulncheck non installé. Installer avec : go install golang.org/x/vuln/cmd/govulncheck@latest${NC}"
    fi
fi

echo ""
echo "================================================================"
if [ $FOUND_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ Audit terminé - Aucune vulnérabilité critique trouvée${NC}"
else
    echo -e "${RED}❌ Audit terminé - Des vulnérabilités ont été détectées${NC}"
    echo -e "${YELLOW}Recommandation : Corriger les vulnérabilités critiques et élevées avant le déploiement${NC}"
fi

exit $FOUND_ISSUES


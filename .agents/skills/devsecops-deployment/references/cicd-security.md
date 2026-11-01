# Sécurisation des Pipelines CI/CD (GitHub Actions & GitLab CI) — Référence

Ce document fournit des configurations concrètes pour bâtir des pipelines de livraison continue intégrant la sécurité à chaque étape (*DevSecOps*).

---

## 📋 Table des matières

1. [Principe du Moindre Privilège pour la CI](#1-principe-du-moindre-privilège-pour-la-ci)
2. [Authentification Cloud sans Clé Long-Terme (OIDC)](#2-authentification-cloud-sans-clé-long-terme-oidc)
3. [Pipeline GitHub Actions Sécurisé Complet (Template)](#3-pipeline-github-actions-sécurisé-complet-template)
4. [Intégration des Scanners de Sécurité (Quality Gates)](#4-intégration-des-scanners-de-sécurité-quality-gates)
   - [Détection de Secrets (Gitleaks)](#détection-de-secrets-gitleaks)
   - [Analyse Statique SAST (Semgrep / CodeQL)](#analyse-statique-sast-semgrep--codeql)
   - [Analyse des Dépendances SCA (Trivy / Audit)](#analyse-des-dépendances-sca-trivy--audit)
   - [Scan des Images Docker](#scan-des-images-docker)
5. [Signature et Intégrité des Artefacts (Cosign)](#5-signature-et-intégrité-des-artefacts-cosign)

---

## 1. Principe du Moindre Privilège pour la CI

Dans GitHub Actions, le jeton par défaut `GITHUB_TOKEN` possède souvent des permissions excessives.

### ✅ Configuration requise en en-tête de chaque workflow :
```yaml
# Restreindre les permissions par défaut à la lecture seule
permissions: read-all
```

Pour les jobs qui nécessitent des actions d'écriture (ex: publier une release ou un package), accorder les permissions explicitement au niveau du job :
```yaml
jobs:
  publish:
    permissions:
      contents: write
      packages: write
      id-token: write # Indispensable pour OIDC
```

---

## 2. Authentification Cloud sans Clé Long-Terme (OIDC)

### ❌ Mauvaise pratique :
Stocker `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` statiques dans GitHub Secrets. En cas de fuite du repository, la clé reste active et expose le compte cloud.

### ✅ Bonne pratique (GitHub OIDC vers AWS / GCP / Azure) :
Le runner GitHub demande un jeton temporaire JWT signé par GitHub et l'échange contre un rôle IAM temporaire via STS (durée de validité : 1 heure max).

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write # Requis pour demander le token OIDC
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeploymentRole
          aws-region: eu-west-1
          audience: sts.amazonaws.com
```

---

## 3. Pipeline GitHub Actions Sécurisé Complet (Template)

Ce workflow déclenche l'ensemble des contrôles de sécurité avant d'autoriser le build et le déploiement.

```yaml
name: DevSecOps Delivery Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions: read-all

jobs:
  # -------------------------------------------------------------
  # 1. SCAN DES SECRETS (Pré-requis absolu)
  # -------------------------------------------------------------
  secret-scan:
    name: Secret Leak Detection
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # -------------------------------------------------------------
  # 2. ANALYSE STATIQUE (SAST) & AUDIT DES DÉPENDANCES (SCA)
  # -------------------------------------------------------------
  code-security:
    name: SAST & Dependency Audit
    needs: secret-scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      # SAST : Semgrep
      - name: Run Semgrep SAST Scan
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/owasp-top-ten
            p/cwe-top-25

      # SCA : Trivy pour les dépendances
      - name: Run Trivy Dependency Vulnerability Scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1' # Fait échouer le pipeline si vulnérabilité critique trouvée

  # -------------------------------------------------------------
  # 3. BUILD ET SCAN DE L'IMAGE CONTENEUR
  # -------------------------------------------------------------
  container-build-scan:
    name: Container Build & Vulnerability Scan
    needs: code-security
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Linting du Dockerfile avec Hadolint
      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
          failure-threshold: error

      # Build local pour analyse
      - name: Build Local Image
        uses: docker/build-push-action@v5
        with:
          context: .
          load: true
          tags: app:local-test
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # Scan de l'image construite avec Trivy
      - name: Scan Docker Image for Vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:local-test'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
          ignore-unfixed: true
```

---

## 4. Intégration des Scanners de Sécurité (Quality Gates)

### Détection de Secrets (Gitleaks)
Empêche de committer des mots de passe, tokens ou clés privées.
Fichier de configuration `.gitleaks.toml` recommandé :
```toml
[extend]
useDefault = true

[whitelist]
description = "Ignorer les fichiers de tests et mocks"
paths = [
  '''tests/fixtures/.*''',
  '''package-lock\.json'''
]
```

### Analyse Statique SAST (Semgrep)
Semgrep analyse le code source sans l'exécuter pour détecter les failles logiques (injections SQL, mauvaise utilisation d'API crypto, désérialisation non sécurisée).

---

## 5. Signature et Intégrité des Artefacts (Cosign)

Pour garantir que l'image exécutée en production n'a pas été altérée entre le build et le runtime :

```yaml
- name: Install Cosign
  uses: sigstore/cosign-installer@v3

- name: Sign Container Image
  run: |
    cosign sign --yes \
      -a "repo=${{ github.repository }}" \
      -a "commit=${{ github.sha }}" \
      ghcr.io/my-org/my-app:${{ github.sha }}
```

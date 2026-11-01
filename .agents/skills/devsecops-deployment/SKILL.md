---
name: devsecops-deployment
description: >-
  Skill de DevSecOps et déploiement sécurisé pour conteneurs (Docker), Kubernetes,
  Infrastructure-as-Code (Terraform) et pipelines CI/CD (GitHub Actions, GitLab CI).
  Utiliser ce skill pour concevoir des pipelines de livraison sécurisés, durcir des
  Dockerfiles (distroless, non-root), sécuriser des manifests Kubernetes, appliquer
  des stratégies de déploiement à zéro interruption (Blue/Green, Canary) et gérer
  les secrets de production (Vault, AWS Secrets Manager, OIDC).
---

# 🚀 DevSecOps & Secure Deployment Skill

Skill expert couvrant l'ensemble du cycle de livraison continue sécurisé (**CI/CD**, **Conteneurisation**, **Infrastructure-as-Code**, **Déploiement Cloud** et **Observabilité**).

---

## 📋 Table des matières

1. [Phases du Cycle DevSecOps](#phases-du-cycle-devsecops)
2. [Sécurisation des Pipelines CI/CD](#1-sécurisation-des-pipelines-cicd)
3. [Durcissement des Conteneurs (Docker)](#2-durcissement-des-conteneurs-docker)
4. [Infrastructure-as-Code & Kubernetes Sécurisé](#3-infrastructure-as-code--kubernetes-sécurisé)
5. [Stratégies de Déploiement & Gestion des Secrets](#4-stratégies-de-déploiement--gestion-des-secrets)
6. [Observabilité, Monitoring & Rollback](#5-observabilité-monitoring--rollback)
7. [Guides de Référence Détaillés](#guides-de-référence-détaillés)
8. [Scripts d'Automatisation](#scripts-dautomatisation)

---

## Phases du Cycle DevSecOps

Le pipeline DevSecOps intègre des contrôles automatiques à chaque étape sans ralentir la vélocité :

```
[ Code ] ➔ [ Commit ] ➔ [ Build CI ] ➔ [ Container Scan ] ➔ [ Deploy CD ] ➔ [ Runtime Ops ]
   │            │             │                 │                │               │
   ▼            ▼             ▼                 ▼                ▼               ▼
Pre-commit   Secret Scan    SAST + SCA       Trivy / Grype     OIDC Cloud    Audit Logs
Linting      (Gitleaks)    (Semgrep/Audit)   Sign (Cosign)    Zero-Trust    Prometheus
```

---

## 1. Sécurisation des Pipelines CI/CD

### Bonnes Pratiques Obligatoires :
1. **Authentification Cloud par OIDC :** Jamais de clés secrètes d'accès cloud (`AWS_ACCESS_KEY_ID`, `GCP_KEY`) stockées dans GitHub Secrets. Toujours utiliser GitHub OpenID Connect (OIDC) avec un rôle IAM à durée limitée.
2. **Moindre Privilège du Token CI :** Définir systématiquement `permissions: read-all` au niveau du workflow et n'ajouter que les droits strictement indispensables aux jobs nécessaires.
3. **Quality Gates Infranchissables :** Bloquer le merge si :
   - Des secrets sont détectés (Gitleaks).
   - Des CVE critiques/élevées sont présentes dans les dépendances (SCA).
   - Le scan SAST détecte une vulnérabilité (Semgrep / CodeQL).
   - Le Dockerfile n'est pas conforme aux règles de sécurité (Hadolint).

Consulter le guide complet : [Sécurisation CI/CD](./references/cicd-security.md)

---

## 2. Durcissement des Conteneurs (Docker)

### Règles d'Or pour les Dockerfiles de Production :
- **Multi-Stage Builds :** Séparer l'étape de compilation (avec compilateurs, SDKs) de l'image d'exécution finale.
- **Utilisateur Non-Root :** Toujours créer et basculer sur un utilisateur non privilégié (`USER 10001:10001`).
- **Images Minimales :** Préférer les images Distroless (`gcr.io/distroless/*`) ou Alpine/Debian-slim mises à jour.
- **Système de fichiers en lecture seule :** Configurer `read_only: true` lors de l'exécution du conteneur.
- **Pas de secrets dans les layers :** Ne jamais passer de clés ou mots de passe via `ARG` ou `ENV`. Utiliser BuildKit `--mount=type=secret`.

Consulter le guide complet : [Durcissement des Conteneurs](./references/container-hardening.md)

---

## 3. Infrastructure-as-Code & Kubernetes Sécurisé

### Terraform / OpenTofu :
- State distant chiffré avec verrouillage (AWS S3 + KMS + DynamoDB).
- Analyse statique IaC systématique avec Checkov ou tfsec.
- Pas de bloc CIDR `0.0.0.0/0` sur les ports d'administration (SSH, RDP, bases de données).

### Kubernetes (K8s) :
- Application stricte du **Pod Security Standard (PSS)** de niveau `restricted`.
- `securityContext` durci :
  ```yaml
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 10001
    capabilities:
      drop: ["ALL"]
  ```
- **NetworkPolicies :** Isolation par défaut (`default-deny`) et autorisation explicite des flux requis entre microservices.

Consulter le guide complet : [Sécurité IaC & Kubernetes](./references/iac-security.md)

---

## 4. Stratégies de Déploiement & Gestion des Secrets

### Stratégies de Déploiement Zéro-Interruption (Zero-Downtime) :
- **Rolling Update :** Remplacement progressif des pods avec sondes de santé (`readinessProbe`, `livenessProbe`).
- **Blue/Green Deployment :** Deux environnements identiques permettant un basculement instantané via le routeur/ingress et un retour arrière immédiat en cas d'incident.
- **Canary Deployment :** Routage d'une fraction du trafic (ex: 5%, 10%) vers la nouvelle version pour valider les métriques avant la généralisation.

### Gestion des Secrets de Production :
- **Zéro secret dans Git :** Utiliser HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager, ou Azure Key Vault.
- **Synchronisation Kubernetes :** External Secrets Operator (ESO) ou CSI Secret Store Driver.
- **GitOps :** Utilisation de SOPS (Secrets OPerationS) avec chiffrement asymétrique (KMS/PGP) pour versionner les secrets chiffrés.

Consulter le guide complet : [Stratégies de Déploiement & Secrets](./references/deployment-strategies.md)

---

## 5. Observabilité, Monitoring & Rollback

- **Sondes de Santé applicatives :**
  - `/health/live` : L'application est-elle en cours d'exécution ? (sinon redémarrage).
  - `/health/ready` : Les connexions BD et caches sont-ils prêts à recevoir du trafic ? (sinon retrait du load balancer).
- **Métriques & Alerting :** Surveillance du taux d'erreurs HTTP 5xx, du temps de réponse (p95, p99) et de la consommation CPU/Mémoire.
- **Rollback Automatique :** Déclencher automatiquement le retour à la version précédente en cas d'échec des healthchecks ou d'alerte critique après déploiement.

---

## Guides de Référence Détaillés

| Référence | Contenu |
|-----------|---------|
| [Sécurisation CI/CD](./references/cicd-security.md) | GitHub Actions durci, OIDC Cloud, Quality Gates (SAST/SCA/Secrets) |
| [Durcissement des Conteneurs](./references/container-hardening.md) | Dockerfiles durcis multi-langages (Node, Python, Go, Java), distroless, non-root |
| [Sécurité IaC & Kubernetes](./references/iac-security.md) | Terraform sécurisé, Pod Security Standards, NetworkPolicies K8s, Checkov |
| [Stratégies de Déploiement](./references/deployment-strategies.md) | Blue/Green, Canary, Healthchecks, External Secrets, Vault, SOPS |
| [Déploiement Cloud Vercel Zéro-Erreur](./references/vercel-zero-error-deployment.md) | Standards de déploiement Vercel/Netlify, rewrites SPA, base paths, headers et Permissions-Policy |

---

## Scripts d'Automatisation

| Script | Usage |
|--------|-------|
| [scan-container.ps1](./scripts/scan-container.ps1) | Audit et vérification de conformité de Dockerfile et images (non-root, secrets, layers) |
| [verify-deployment.ps1](./scripts/verify-deployment.ps1) | Test des endpoints de santé, vérification des headers de sécurité et validation post-déploiement |
| [verify-vercel.ps1](./scripts/verify-vercel.ps1) | Audit automatisé de la configuration Vercel (vercel.json, base path, rewrites, package.json) |

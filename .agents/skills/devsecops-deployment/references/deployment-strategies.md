# Stratégies de Déploiement & Gestion des Secrets en Production — Référence

Ce document décrit les patterns de déploiement à zéro interruption (*Zero-Downtime*), la gestion des migrations de base de données sans coupure et l'injection sécurisée des secrets.

---

## 📋 Table des matières

1. [Sondes de Santé Kubernetes (Zero-Downtime Prerequisite)](#1-sondes-de-santé-kubernetes-zero-downtime-prerequisite)
2. [Stratégie Rolling Update Durcie](#2-stratégie-rolling-update-durcie)
3. [Stratégie Blue / Green Deployment](#3-stratégie-blue--green-deployment)
4. [Stratégie Canary Release (Argo Rollouts)](#4-stratégie-canary-release-argo-rollouts)
5. [Migrations de Base de Données sans Coupure (Expand & Contract)](#5-migrations-de-base-de-données-sans-coupure-expand--contract)
6. [Gestion des Secrets : External Secrets Operator & Vault](#6-gestion-des-secrets--external-secrets-operator--vault)
7. [Secrets GitOps avec Mozilla SOPS](#7-secrets-gitops-avec-mozilla-sops)

---

## 1. Sondes de Santé Kubernetes (Zero-Downtime Prerequisite)

Pour éviter que des requêtes utilisateurs n'arrivent sur un pod qui n'est pas encore prêt (ou en panne), configurer les 3 sondes :

```yaml
containers:
  - name: app
    image: app:v2.0.0
    ports:
      - containerPort: 8080

    # 1. Startup Probe : Pour les applications lentes à démarrer (Spring Boot, gros modèles)
    startupProbe:
      httpGet:
        path: /health/startup
        port: 8080
      failureThreshold: 30
      periodSeconds: 10

    # 2. Readiness Probe : Reçoit-il le trafic du Load Balancer ?
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 2

    # 3. Liveness Probe : Le processus est-il vivant ou bloqué ?
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
      failureThreshold: 3
```

---

## 2. Stratégie Rolling Update Durcie

Garantit qu'au moins 100% de la capacité nominale reste disponible pendant toute la phase de mise à jour :

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # Démarre 1 pod supplémentaire avant de couper l'ancien
      maxUnavailable: 0    # INTERDIT la destruction d'un ancien pod tant que le nouveau n'est pas "Ready"
```

---

## 3. Stratégie Blue / Green Deployment

Consiste à déployer la nouvelle version (**Green**) à côté de l'ancienne (**Blue**), tester Green en pré-production, puis basculer le routeur/service instantanément.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: production
spec:
  selector:
    app: my-app
    version: v2 # Basculement instantané de v1 (Blue) vers v2 (Green)
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

---

## 4. Stratégie Canary Release (Argo Rollouts)

Achemine progressivement 5%, puis 20%, puis 100% du trafic en vérifiant que le taux d'erreurs HTTP 5xx reste inférieur à 1% :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app-rollout
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 5
        - pause: { duration: 10m } # Observation pendant 10 minutes à 5% de trafic
        - setWeight: 20
        - pause: { duration: 30m }
        - setWeight: 50
        - pause: { duration: 15m }
      analysis:
        templates:
          - templateName: success-rate-check
        args:
          - name: service-name
            value: app-canary-svc
```

---

## 5. Migrations de Base de Données sans Coupure (Expand & Contract)

Ne jamais renommer ou supprimer une colonne en une seule release (car l'ancienne version du code tourne encore pendant le déploiement).

### Pattern en 4 étapes :
1. **Étape 1 (Release N) :** Ajouter la nouvelle colonne en base comme `NULLABLE`. L'application commence à écrire dans l'ancienne ET la nouvelle colonne (double écriture).
2. **Étape 2 (Script asynchrone) :** Backfiller les anciennes données vers la nouvelle colonne.
3. **Étape 3 (Release N+1) :** Basculer la lecture sur la nouvelle colonne.
4. **Étape 4 (Release N+2) :** Supprimer l'ancienne colonne et rendre la nouvelle colonne `NOT NULL`.

---

## 6. Gestion des Secrets : External Secrets Operator & Vault

Plutôt que d'écrire des secrets Kubernetes en dur (qui ne sont encodés qu'en base64), synchroniser les secrets depuis AWS Secrets Manager ou HashiCorp Vault.

```yaml
# 1. Connexion au coffre-fort AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: production
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-west-1
      auth:
        jwt:
          serviceAccountRef:
            name: eso-irsa-serviceaccount

---
# 2. Définition du secret synchronisé
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: "1h" # Rotation automatique
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: db-secret # Nom du K8s Secret créé automatiquement
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: prod/database
        property: password
```

---

## 7. Secrets GitOps avec Mozilla SOPS

Pour versionner des manifests chiffrés directement dans Git :

```bash
# Chiffrement d'un manifest Kubernetes avec une clé AWS KMS ou PGP
sops --encrypt --kms "arn:aws:kms:eu-west-1:123456789012:key/my-key" \
     secret-raw.yaml > secret-enc.yaml
```

FluxCD ou ArgoCD (avec le plugin SOPS) déchiffre automatiquement le secret à la volée avant de l'appliquer dans le cluster.

# Sécurité de l'Infrastructure as Code (Terraform & Kubernetes) — Référence

Ce document détaille les règles et configurations pour durcir l'infrastructure cloud et les clusters Kubernetes.

---

## 📋 Table des matières

1. [Terraform & OpenTofu Sécurisé](#1-terraform--opentofu-sécurisé)
   - [Backend Distant Chiffré avec State Locking](#backend-distant-chiffré-avec-state-locking)
   - [Durcissement des Groupes de Sécurité (Firewall)](#durcissement-des-groupes-de-sécurité-firewall)
   - [Analyse Statique IaC (Checkov / tfsec)](#analyse-statique-iac-checkov--tfsec)
2. [Kubernetes : Pod Security Standards (Niveau Restricted)](#2-kubernetes--pod-security-standards-niveau-restricted)
3. [Kubernetes : NetworkPolicies (Défense Réseau Interne)](#3-kubernetes--networkpolicies-défense-réseau-interne)
4. [Kubernetes : Moindre Privilège RBAC & ServiceAccounts](#4-kubernetes--moindre-privilège-rbac--serviceaccounts)

---

## 1. Terraform & OpenTofu Sécurisé

### Backend Distant Chiffré avec State Locking

Le fichier d'état (`terraform.tfstate`) contient souvent des secrets en clair. Il doit impérativement être stocké dans un bucket distant chiffré avec verrouillage :

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "company-tfstate-prod-secure"
    key            = "services/app/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true               # Chiffrement côté serveur côté S3 obligatoire
    kms_key_id     = "arn:aws:kms:eu-west-1:123456789012:key/my-tf-key"
    dynamodb_table = "terraform-state-lock" # Verrouillage pour empêcher les écritures concurrentes
  }
}
```

### Durcissement des Groupes de Sécurité (Firewall)

#### ❌ Configuration Dangereuse
```hcl
# ❌ DANGEREUX : Exposition de la base de données ou SSH au monde entier
resource "aws_security_group_rule" "bad_postgres" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] # Ouvert à tout Internet !
  security_group_id = aws_security_group.db.id
}
```

#### ✅ Configuration Sécurisée (Moindre Privilège Réseau)
```hcl
# ✅ BON : Accès limité strictement au groupe de sécurité des conteneurs applicatifs
resource "aws_security_group_rule" "secure_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_backend.id
  security_group_id        = aws_security_group.db.id
  description              = "Acces PostgreSQL autorise uniquement depuis le backend"
}
```

---

## 2. Kubernetes : Pod Security Standards (Niveau Restricted)

Pour empêcher un conteneur compromis d'attaquer le nœud hôte ou les autres pods, appliquer le profil **Restricted** :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
  labels:
    app: secure-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      # 1. Ne pas monter le token de l'API Kubernetes si le pod n'en a pas besoin
      automountServiceAccountToken: false

      # 2. Contexte de sécurité au niveau du Pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault # Profil seccomp par défaut du runtime

      containers:
        - name: app
          image: ghcr.io/my-org/secure-app:v1.2.0
          imagePullPolicy: IfNotPresent

          # 3. Contexte de sécurité strict au niveau du conteneur
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL # Supprime TOUTES les capacités root Linux

          # 4. Limites strictes de ressources (Anti-DoS / Anti-OOM)
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"

          # 5. Montage en mémoire temporaire pour les écritures nécessaires
          volumeMounts:
            - name: tmp-volume
              mountPath: /tmp

      volumes:
        - name: tmp-volume
          emptyDir:
            medium: Memory
            sizeLimit: 64Mi
```

---

## 3. Kubernetes : NetworkPolicies (Défense Réseau Interne)

Par défaut dans Kubernetes, tous les pods peuvent communiquer librement entre eux. Une **NetworkPolicy** permet de fermer tout le trafic et de n'ouvrir que les flux légitimes.

### Étape 1 : Default Deny All (Isolation par défaut)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {} # S'applique à tous les pods du namespace
  policyTypes:
    - Ingress
    - Egress
```

### Étape 2 : Autoriser uniquement le backend à interroger la Base de Données
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres-database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: secure-app # Seul le backend a le droit d'entrer
      ports:
        - protocol: TCP
          port: 5432
```

---

## 4. Kubernetes : Moindre Privilège RBAC & ServiceAccounts

1. **Pas de `cluster-admin` pour les applications :** Toujours créer des `Role` et `RoleBinding` limités à un namespace donné.
2. **Éviter les wildcards `*` dans les verbes et ressources RBAC :**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: config-reader
rules:
  # ✅ Accès en lecture seule ciblé sur une ressource précise
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
    resourceNames: ["app-config"]
```

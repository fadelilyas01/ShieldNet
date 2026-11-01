# Durcissement des Conteneurs (Docker Hardening) — Référence

Ce document fournit des templates de Dockerfiles durcis pour la production, intégrant les recommandations du CIS Docker Benchmark et de l'ANSSI.

---

## 📋 Table des matières

1. [Principes Fondamentaux de Sécurité des Conteneurs](#1-principes-fondamentaux-de-sécurité-des-conteneurs)
2. [Dockerfile Node.js Durci (Multi-Stage + Distroless)](#2-dockerfile-nodejs-durci-multi-stage--distroless)
3. [Dockerfile Python Durci (FastAPI / Django)](#3-dockerfile-python-durci-fastapi--django)
4. [Dockerfile Go Durci (Distroless Statique)](#4-dockerfile-go-durci-distroless-statique)
5. [Dockerfile Java / Spring Boot Durci](#5-dockerfile-java--spring-boot-durci)
6. [Sécurisation du Runtime Docker](#6-sécurisation-du-runtime-docker)

---

## 1. Principes Fondamentaux de Sécurité des Conteneurs

1. **Multi-Stage Builds :** Ne jamais embarquer d'outils de compilation (`gcc`, `npm`, `pip`, `maven`, `git`) dans l'image finale d'exécution.
2. **Utilisateur Non-Root :** Par défaut, un conteneur tourne sous `root` (UID 0). Si un attaquant s'échappe du conteneur, il devient root sur l'hôte. Toujours spécifier un UID non privilégié (ex: `10001`).
3. **Images de Base Minimales :** Préférer les images `distroless` (contenant uniquement l'application et ses dépendances d'exécution, sans shell `sh/bash` ni gestionnaire de paquets) ou `alpine`/`debian-slim`.
4. **Pas de Secrets dans les Layers :** Ne jamais utiliser `ARG SECRET_KEY` ou `ENV API_KEY`. Utiliser Docker BuildKit `--mount=type=secret`.
5. **Système de Fichiers en Lecture Seule :** Empêcher l'écriture d'exécutables malveillants dans `/tmp` ou le répertoire de l'application.

---

## 2. Dockerfile Node.js Durci (Multi-Stage + Distroless)

```dockerfile
# -------------------------------------------------------------
# Étape 1 : Build et dépendances
# -------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Copier uniquement les manifests de paquets
COPY package.json package-lock.json ./

# Installation propre des dépendances avec vérification d'intégrité
RUN npm ci --ignore-scripts

# Copie du code source et compilation TypeScript
COPY . .
RUN npm run build && npm prune --production

# -------------------------------------------------------------
# Étape 2 : Image d'exécution minimale Distroless (Sans Shell, Sans Package Manager)
# -------------------------------------------------------------
FROM gcr.io/distroless/nodejs20-debian12:nonroot

WORKDIR /app

# Récupération des artefacts compilés et des modules de production
COPY --from=builder --chown=nonroot:nonroot /app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/package.json ./package.json

# Définition de l'environnement de production
ENV NODE_ENV=production
ENV PORT=3000

# Utilisateur non-root prédéfini (UID 65532)
USER nonroot

EXPOSE 3000

# Démarrage direct sans passer par un script shell
CMD ["dist/main.js"]
```

---

## 3. Dockerfile Python Durci (FastAPI / Django)

```dockerfile
# -------------------------------------------------------------
# Étape 1 : Builder pour la compilation des dépendances C (wheels)
# -------------------------------------------------------------
FROM python:3.12-slim-bookworm AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# -------------------------------------------------------------
# Étape 2 : Image finale d'exécution durcie
# -------------------------------------------------------------
FROM python:3.12-slim-bookworm AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/home/appuser/.local/bin:$PATH"

# Création d'un groupe et utilisateur dédié non-root (UID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -m appuser

# Copie des paquets Python installés depuis le builder
COPY --from=builder --chown=appuser:appgroup /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup . .

# Basculer vers l'utilisateur non privilégié
USER appuser

EXPOSE 8000

# Exécution avec Gunicorn / Uvicorn avec timeouts stricts
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
```

---

## 4. Dockerfile Go Durci (Distroless Statique)

Pour Go, la compilation statique permet d'obtenir un binaire autonome exécutable dans un conteneur complètement vide (`scratch` ou `distroless:static`).

```dockerfile
# -------------------------------------------------------------
# Étape 1 : Compilation statique
# -------------------------------------------------------------
FROM golang:1.22-alpine AS builder

WORKDIR /src

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Compilation statique sans dépendance C (CGO_ENABLED=0) avec suppression des symboles de debug (-s -w)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o /bin/server .

# -------------------------------------------------------------
# Étape 2 : Image finale ultra-minimale
# -------------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copie du binaire compilé
COPY --from=builder /bin/server /app/server

# Exécuté sous nonroot (UID 65532)
USER nonroot

EXPOSE 8080

ENTRYPOINT ["/app/server"]
```

---

## 5. Dockerfile Java / Spring Boot Durci

```dockerfile
# -------------------------------------------------------------
# Étape 1 : Extraction des couches Spring Boot (Layered Jar)
# -------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS builder

WORKDIR /app
COPY target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# -------------------------------------------------------------
# Étape 2 : Image d'exécution durcie
# -------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Création de l'utilisateur non-root
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

# Copie des couches Spring Boot pour optimiser le cache Docker
COPY --from=builder --chown=appuser:appgroup /app/dependencies/ ./
COPY --from=builder --chown=appuser:appgroup /app/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appgroup /app/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appgroup /app/application/ ./

USER appuser

EXPOSE 8080

# Options JVM sécurisées et adaptées aux conteneurs
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "org.springframework.boot.loader.launch.JarLauncher"]
```

---

## 6. Dockerfile Rust Durci (Cargo-Chef & Distroless)

Rust bénéficie du tool `cargo-chef` pour mettre en cache les dépendances compilées (évite de recompiler toutes les crates à chaque changement de code source), combiné à une image d'exécution `distroless/cc-debian12` sans shell ni compilateur :

```dockerfile
# -------------------------------------------------------------
# Étape 1 : Planification du cache de dépendances
# -------------------------------------------------------------
FROM lukemathwalker/cargo-chef:latest-rust-1.80-bookworm AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# -------------------------------------------------------------
# Étape 2 : Compilation des dépendances (couche mise en cache)
# -------------------------------------------------------------
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# Ne recompile les dépendances que si Cargo.lock change
RUN cargo chef cook --release --recipe-path recipe.json

# Compilation du code source applicatif
COPY . .
RUN cargo build --release --bin server

# -------------------------------------------------------------
# Étape 3 : Image finale d'exécution Distroless (Sécurité Maximale)
# -------------------------------------------------------------
FROM gcr.io/distroless/cc-debian12:nonroot

WORKDIR /app

# Copie du binaire release optimisé
COPY --from=builder /app/target/release/server /app/server

# Exécuté sous nonroot (UID 65532)
USER nonroot

EXPOSE 8080

ENTRYPOINT ["/app/server"]
```

---

## 7. Sécurisation du Runtime Docker

Lors de l'exécution en local ou avec Docker Compose, restreindre les privilèges du conteneur :

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  web:
    image: my-app:latest
    restart: unless-stopped
    read_only: true # Système de fichiers en lecture seule
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m # Montage temporaire limité en mémoire
    security_opt:
      - no-new-privileges:true # Empêche l'escalade de privilège via setuid
    cap_drop:
      - ALL # Supprime toutes les capacités Linux du kernel
    user: "10001:10001"
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M # Prévention des attaques par déni de service mémoire (OOM)
```

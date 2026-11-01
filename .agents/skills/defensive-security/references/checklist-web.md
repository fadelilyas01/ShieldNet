# Checklist de sécurité Web — Exhaustive

Checklist complète pour le déploiement sécurisé d'applications web.

---

## 🔐 Transport et Infrastructure

- [ ] HTTPS activé et forcé (redirection HTTP → HTTPS)
- [ ] TLS 1.2+ uniquement (TLS 1.0 et 1.1 désactivés)
- [ ] Certificats SSL/TLS valides, non expirés et provenant d'une CA de confiance
- [ ] HSTS activé (`max-age=31536000; includeSubDomains; preload`)
- [ ] OCSP Stapling activé
- [ ] Cipher suites modernes uniquement (pas de RC4, DES, 3DES)
- [ ] Perfect Forward Secrecy (PFS) activé
- [ ] DNS CAA records configurés

## 🛡️ Headers de sécurité

- [ ] Content-Security-Policy configuré et testé
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY (ou SAMEORIGIN si nécessaire)
- [ ] Referrer-Policy: strict-origin-when-cross-origin
- [ ] Permissions-Policy configuré (camera, microphone, geolocation désactivés si non utilisés)
- [ ] Strict-Transport-Security activé
- [ ] Cross-Origin-Opener-Policy: same-origin
- [ ] Cross-Origin-Embedder-Policy: require-corp
- [ ] Cross-Origin-Resource-Policy: same-origin
- [ ] X-XSS-Protection: 0 (désactivé au profit de CSP)
- [ ] Cache-Control: no-store pour les pages avec données sensibles
- [ ] Pas de header Server ou X-Powered-By (fingerprinting)

## 🔑 Authentification

- [ ] Politique de mots de passe : minimum 8 caractères
- [ ] Vérification contre les listes de mots de passe compromis (HIBP)
- [ ] Hashage avec Argon2id, bcrypt (coût ≥ 10) ou scrypt
- [ ] Salt unique par mot de passe
- [ ] MFA disponible et encouragée
- [ ] Rate limiting sur le login (5 tentatives / 15 min)
- [ ] Lockout temporaire après tentatives échouées
- [ ] Messages d'erreur génériques ("identifiants invalides")
- [ ] Pas d'énumération d'utilisateurs via login/register/reset
- [ ] CAPTCHA après N tentatives échouées
- [ ] Déconnexion fonctionnelle (invalidation côté serveur)

## 🎫 Sessions et Tokens

- [ ] Session IDs générés de manière cryptographiquement sûre
- [ ] Cookies : HttpOnly, Secure, SameSite=Strict/Lax
- [ ] Préfixe __Host- pour les cookies de session
- [ ] Expiration de session configurée (idle + absolute)
- [ ] Régénération du session ID après authentification
- [ ] Invalidation du session ID à la déconnexion
- [ ] JWT : algorithme HS256/RS256 (pas "none")
- [ ] JWT : expiration courte (15 min access token)
- [ ] JWT : vérification de l'issuer et audience
- [ ] Refresh token avec rotation et révocation

## ✅ Validation des entrées

- [ ] Validation côté serveur pour TOUTES les entrées
- [ ] Validation par whitelist (type, longueur, format, plage)
- [ ] Requêtes SQL paramétrées ou ORM
- [ ] Protection contre NoSQL injection
- [ ] Protection contre OS command injection
- [ ] Protection contre LDAP injection
- [ ] Protection contre template injection (SSTI)
- [ ] Protection contre XML External Entity (XXE)
- [ ] Protection contre HTTP Parameter Pollution
- [ ] Limitation de la taille des requêtes
- [ ] Validation du Content-Type
- [ ] Protection contre les mass assignment (whitelist de champs)

## 🖥️ Sorties et affichage

- [ ] Encodage HTML des sorties dans les templates
- [ ] Encodage JavaScript contextuel
- [ ] Encodage URL pour les paramètres d'URL
- [ ] CSP configuré pour bloquer les scripts inline
- [ ] Pas de `dangerouslySetInnerHTML` / `v-html` / `bypassSecurityTrust` non contrôlés
- [ ] Subresource Integrity (SRI) pour les scripts CDN

## 🚫 CSRF

- [ ] Tokens CSRF pour les formulaires (si cookies utilisés)
- [ ] SameSite=Strict ou Lax sur les cookies
- [ ] Vérification de l'header Origin/Referer
- [ ] Double Submit Cookie Pattern (si applicable)

## 🔗 API

- [ ] Tous les endpoints authentifiés (sauf ceux explicitement publics)
- [ ] Autorisation vérifiée à chaque requête
- [ ] Rate limiting global et par endpoint
- [ ] CORS restrictif (pas de wildcard `*` avec credentials)
- [ ] Pagination imposée (max 100 par page)
- [ ] Projection des champs (ne pas exposer tout le modèle)
- [ ] Validation des entrées sur chaque endpoint
- [ ] Versioning de l'API
- [ ] Pas d'information interne dans les erreurs
- [ ] Clés d'idempotence pour les opérations critiques
- [ ] Throttling pour les opérations coûteuses

## 📁 Upload de fichiers

- [ ] Validation du type MIME (whitelist)
- [ ] Validation de l'extension (whitelist)
- [ ] Vérification des magic bytes
- [ ] Limite de taille de fichier
- [ ] Nom de fichier régénéré (aléatoire)
- [ ] Stockage hors du webroot
- [ ] Scan antivirus si possible
- [ ] Pas d'exécution des fichiers uploadés

## 🗃️ Base de données

- [ ] Compte DB avec privilèges minimaux
- [ ] Requêtes paramétrées partout
- [ ] Chiffrement au repos si données sensibles
- [ ] Backups chiffrés et testés
- [ ] Pas de credentials DB dans le code source
- [ ] Connection pooling avec timeouts

## 📝 Logging et Monitoring

- [ ] Connexions (succès/échec) loguées
- [ ] Changements de permissions loguées
- [ ] Accès aux données sensibles logués
- [ ] Erreurs d'autorisation loguées
- [ ] Format structuré (JSON) avec timestamp, userId, IP
- [ ] Pas de données sensibles dans les logs
- [ ] Logs centralisés et protégés contre la modification
- [ ] Alertes automatiques sur patterns anormaux
- [ ] Plan de réponse aux incidents documenté

## 📦 Dépendances

- [ ] Audit de sécurité des dépendances (`npm audit`, etc.)
- [ ] Pas de dépendances avec des CVE critiques
- [ ] Lockfile committé
- [ ] Mises à jour régulières (Dependabot/Renovate)
- [ ] Suppression des dépendances non utilisées

## 🏗️ Build et Déploiement

- [ ] Mode debug/développement désactivé
- [ ] Stack traces masquées en production
- [ ] Source maps non accessibles publiquement
- [ ] Variables d'environnement pour les secrets
- [ ] Pas de fichiers de configuration sensibles dans le repo
- [ ] .gitignore configuré (node_modules, .env, etc.)
- [ ] CI/CD sécurisé avec contrôle d'accès
- [ ] Review de code obligatoire avant merge
- [ ] SAST/DAST intégrés dans le pipeline

## 🌐 DNS et Domaine

- [ ] DNSSEC activé si possible
- [ ] SPF, DKIM, DMARC configurés pour les emails
- [ ] Sous-domaines inutilisés supprimés (subdomain takeover)

## 📜 Conformité

- [ ] Politique de confidentialité à jour
- [ ] Consentement cookies (RGPD)
- [ ] Droit d'accès et de suppression des données
- [ ] DPA (Data Processing Agreement) avec les sous-traitants
- [ ] Minimisation des données collectées


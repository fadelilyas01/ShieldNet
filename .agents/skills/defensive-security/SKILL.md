---
name: defensive-security
description: >-
  Skill de cybersécurité défensive et d'ingénierie logicielle sécurisée (Zero-Vulnerability Standard)
  pour applications web, desktop, mobiles et bases de données, basé sur OWASP Top 10 Web (2021),
  OWASP Mobile Top 10 (2024), CWE Top 25 (2024) et les standards de kiosque sécurisé.
  À utiliser pour l'audit approfondi, la génération de code 100% sécurisé (secure by design),
  l'élimination totale des secrets et tokens hardcodés, l'intégrité cryptographique,
  la sécurisation des bases de données et la vérification automatisée pré-commit multi-langages
  (TypeScript, Python, Java, C#, PHP, Go, Rust, Swift, Kotlin, Flutter, React Native).
---

# 🛡️ Defensive Security Skill — Zero-Vulnerability Standard

Ce skill applique le **Protocole d'Exécution Zéro-Vulnérabilité** sur l'ensemble des interactions du projet actuel et de tous les projets futurs. Il garantit qu'aucun code produit ou modifié ne contient de faille de sécurité, de secret en clair, de composant vulnérable ou de faiblesse architecturale.

---

## 📋 Table des matières

1. [Le Protocole d'Exécution Zéro-Vulnérabilité](#le-protocole-dexécution-zéro-vulnérabilité)
2. [Standard Senior Software Engineer : Anti-Patterns IA & Bonnes Pratiques](#standard-senior-software-engineer--anti-patterns-ia--bonnes-pratiques)
3. [Modes d'intervention (Audit, Génération, Validation)](#modes-dintervention)
4. [Checklist Exhaustive Pré-Commit & Pré-Déploiement](#checklist-exhaustive-pré-commit--pré-déploiement)
5. [Règles Spécifiques par Périmètre Applicatif](#règles-spécifiques-par-périmètre-applicatif)
6. [Scripts et Commandes de Vérification Automatisée](#scripts-et-commandes-de-vérification-automatisée)
7. [Guides et Références Détaillées](#guides-et-références-détaillées)

---

## Le Protocole d'Exécution Zéro-Vulnérabilité

Lors de **chaque génération ou modification de code**, l'agent doit impérativement appliquer ces **10 règles non-négociables** :

### 1. Zéro Secret, Zéro Token & Zéro PIN en Dur (CWE-798 & CWE-312)
- Aucun mot de passe, clé API, jeton d'accès, certificat privé, code PIN (`"2026"`, `"AGORA"`) ou token de session (`wstoken`, JWT) ne doit figurer dans le code source (frontend ou backend).
- Aucun placeholder de test (`"secret_token_placeholder"`, `"mock_token"`, `"fake_key"`) ne doit subsister dans les bundles de production.
- Les secrets doivent être injectés via des variables d'environnement (`.env` documenté dans `.env.example`), un gestionnaire de secrets (Vault, AWS Secrets Manager) ou un hachage salé vérifié.

### 2. Intégrité Cryptographique Réelle & Zéro Faux Hash (CWE-345)
- Interdiction absolue d'écrire des empreintes SHA-256 statiques, fictives ou simulées pour des attestations, reçus ou scellements d'examen.
- Toute empreinte d'intégrité doit être calculée mathématiquement en direct sur le payload canonique (sérialisé et trié) via l'API Web Crypto (`window.crypto.subtle.digest`) ou la crate Rust `sha2`.

### 3. Architecture Fail-Secure Absolue (CWE-636)
- Tout module d'authentification, de contrôle d'accès, d'IA, de détection faciale ou de proctoring doit refuser l'accès par défaut en cas d'erreur ou d'absence (`catch { return { hasFace: false, confidence: 0.0 }; }`).
- Le mode Fail-Open (renvoyer `true` pour contourner une panne réseau ou modèle) est formellement interdit.

### 4. Entropie Cryptographique Certifiée CSPRNG (CWE-338)
- `Math.random()` est STRICTEMENT PROHIBÉ pour toute fonction liée à la sécurité, aux tokens, aux identifiants de session ou aux clés éphémères.
- Utiliser exclusivement `window.crypto.getRandomValues()` côté navigateur / Node, `rand::rngs::OsRng` en Rust, `secrets` en Python ou `crypto/rand` en Go.

### 5. Supply Chain & Dépendances à Zéro CVE (CWE-1357 & OWASP A06:2021)
- Bannir les imports de scripts CDN sur des tags dynamiques non verrouillés (`@latest`). Épingler impérativement la version exacte (`@x.y.z`) et vérifier l'intégrité SRI (`integrity="sha384-..."`).
- `npm audit`, `cargo audit` ou `pip-audit` doivent impérativement afficher **0 vulnérabilité** avant toute livraison. Appliquer les `overrides` / `resolutions` nécessaires et adapter la cible de compilation (`target: "es2022"`).

### 6. CSP & Sécurité Réseau Stricte (CWE-1021)
- `'unsafe-eval'` est banni de toutes les Content-Security-Policy (Web, Tauri, Electron).
- `connect-src` doit être restreint aux domaines d'infrastructure explicites (interdiction des jokers universels `connect-src https: wss: ws:`).
- Tout lien hypertexte externe ouvrant un nouvel onglet (`target="_blank"`) doit comporter obligatoirement `rel="noopener noreferrer"`.

### 7. Protection Anti-SSRF (CWE-918)
- Toute URL distante appelée par le backend doit être validée par une whitelist stricte : schéma `https` obligatoire, blocage de `127.0.0.1`, `localhost`, `::1`, des métadonnées cloud (`169.254.169.254`, `metadata.google.internal`) et des plages privées RFC1918 (`10.0.0.0/8`, `192.168.0.0/16`, `172.16.0.0/12`).

### 8. Protection de la Mémoire Vive & Persistance Sécurisée
- Les secrets en mémoire doivent être effacés dès leur utilisation (`zeroize::ZeroizeOnDrop` en Rust).
- Utiliser `sessionStorage` plutôt que `localStorage` pour les données d'épreuves sensibles afin d'éviter les fuites post-session.

### 9. Rate-Limiting & Anti-Brute Force
- Tout point d'entrée sensible (authentification, code PIN de surveillant, acquittement d'incident) doit être cadencé (3 essais maximum, suivi d'un verrouillage temporisé).

### 10. Zéro Fuite d'Informations Internes (CWE-209)
- Les stack traces, erreurs SQL détaillées et chemins disques locaux (`C:\...`) ne doivent jamais être exposés au client. Renvoyer des messages génériques et journaliser en interne de manière sécurisée.

### 11. Comparaisons en Temps Constant (CWE-208)
- Toute comparaison de hashs cryptographiques, signatures numériques, tokens de session ou codes PIN doit impérativement utiliser un algorithme en temps constant (Constant-Time XOR / `crypto/subtle.ConstantTimeCompare` / crate `subtle::ConstantTimeEq`) afin d'annihiler tout risque d'attaque par canal auxiliaire temporel (Timing Attack).

### 12. Souveraineté Backend & Zéro Donnée Sensible dans le Frontend (Zero-Trust Frontend)
- **Zéro Token / Secret dans le Frontend (CWE-312 & CWE-922) :** Aucun jeton d'accès (`wstoken`, clé API, secret JWT, certificat privé) ne doit être conservé dans le frontend (ni dans React state, ni dans `localStorage`/`sessionStorage`, ni dans les query parameters de l'URL). Tout token d'initialisation doit être immédiatement transféré au backend sécurisé et purgé de l'URL (`window.history.replaceState`).
- **Présomption de Compromission :** Le client est un environnement hostile entièrement modifiable par l'utilisateur (DevTools, extensions, monkeypatching). Le frontend ne prend **JAMAIS** de décision critique de sécurité via des conditions client (`if (strikes >= 3)`).
- **Autorité Souveraine du Backend :** Les états critiques (compteurs d'infractions, temps officiel monotonique, droits RBAC, clôture d'examen, soumission) sont gérés de manière atomique et autonome par le backend.
- **Intégrité Cryptographique & Scellement :** Les horodatages officiels et empreintes d'intégrité (SHA-256) doivent être calculés et scellés exclusivement par le backend natif ou le serveur, jamais par le navigateur.
- **Confinement Réseau :** Toutes les requêtes vers les services d'infrastructure ou APIs distantes s'effectuent par le client HTTP du backend (Rust `reqwest`), éliminant l'interception et le rejeu depuis les DevTools.

---

## Standard Senior Software Engineer : Anti-Patterns IA & Bonnes Pratiques

Ce standard élimine les raccourcis paresseux et les failles récurrentes fréquemment générés par les IA :

| Domaine | ❌ Anti-Pattern Typique d'une IA | ✅ Standard Exigé (Senior / Staff Engineer) |
| :--- | :--- | :--- |
| **Secrets & Clés** | Insère des placeholders `"TODO_REPLACE"`, `"secret_token_placeholder"` ou des hashs statiques. | Zéro placeholder dans le code. Extraction dynamique depuis `.env` validé par Zod/Pydantic/Config crate. Nettoyage RAM avec `zeroize`. |
| **Filtrage IP & SSRF** | Filtrage textuel naïf (`if ip.contains("10.")`), créant des faux positifs sur `univ-paris10.fr` ou vulnérable aux bypasses hex/décimaux. | Résolution DNS et parsing typé strict via `std::net::IpAddr`. Contrôle exhaustif `is_loopback()`, `is_private()`, `is_link_local()` et métadonnées cloud. |
| **Typage Logiciel** | Recours au type `any`, `as unknown as T` ou `@ts-ignore` pour contourner les erreurs du compilateur. | Validation de schéma au runtime (Zod / ArkType / Typebox), typage nominal, discriminated unions et zéro `any`. |
| **Gestion des Panics** | Utilisation compulsive de `.unwrap()` et `.expect()` en Rust, ou `catch {}` vides en TypeScript/Python. | Typage strict des erreurs avec `thiserror` (crates) ou `anyhow::Context` (apps). Aucun panic en production, remédiation explicite. |
| **Concurrence & Cycle de Vie** | Appels `fetch` ou timers sans `AbortController`, causant des Race Conditions et des fuites de mémoire. | Encapsulation propre avec `AbortController`, nettoyage strict (`return () => controller.abort()`) et états immutables. |
| **Architecture** | Monolithes géants ("God Files" > 1000 lignes) mélangeant état, logique métier, IPC et JSX. | Architecture modulaire en couches : Domaine (règles pures), Infrastructure (API/stockage/crypto), Présentation (composants et custom hooks). |
| **Commentaires de Code** | Commentaires pollués d'emojis décoratifs (`🚀`, `💡`, `🔥`) et jargons superflus. | Commentaires techniques sobres, descriptifs et professionnels (JSDoc / TSDoc / Rustdoc) sans emojis décoratifs. |
| **Résilience Réseau & Pannes** | Requêtes réseau sans timeout ni reprise en cas de micro-coupure. | Timeouts stricts (8-10s via `AbortController`), retry avec gigue exponentielle, et tampon hors-ligne chiffré. |
| **Double Soumission** | Clics rapides multiples créant des doublons ou collisions de données. | Verrouillage instantané du bouton au clic (état loading rassurant) + en-tête `Idempotency-Key: UUID`. |
| **Hygiène des Logs** | Inonde la console de `console.log()` pouvant exposer des données sensibles (PII). | `drop_console` actif au build de production. Zéro pollution de console, masquage PII strict. |
| **Souveraineté Backend & Secrets** | Conserve les tokens (ex: wstoken, API keys) en React state ou localStorage, et prend des décisions critiques via des `if (fautes >= 3)` côté client. | Zéro token dans le frontend (purge URL immédiate et séquestre Zeroize en backend). Le backend détient l'autorité absolue sur l'état, les calculs, l'horodatage UTC et les actions de sécurité. |

Consulter le guide complet : [Anti-Patterns IA vs Standard Senior Engineer](./references/senior-engineer-anti-ai-patterns.md)
Consulter le guide d'architecture : [Souveraineté Backend & Zero-Trust Frontend](./references/backend-sovereignty-zero-trust-frontend.md)
Consulter le guide de résilience : [Résilience Industrielle & Offline-First](./references/production-resilience-offline.md)

---

## Modes d'intervention

| Mode | Déclencheur | Action Automatisée |
| :--- | :--- | :--- |
| **Audit** | Demande d'audit ou ré-évaluation | Exécuter `audit-security-master.ps1`, scanner tous les vecteurs CWE/OWASP, auditer les dépendances à 100% et exiger **0 vulnérabilité** |
| **Génération** | Création / modification de code | Appliquer le protocole Zéro-Vulnérabilité dès la première ligne de code (Fail-Secure, Constant-Time, SSRF typé, zéro placeholder) |
| **Validation** | Pré-commit / Pré-déploiement | Vérifier `audit-security-master.ps1` (Code 0), compilation sans erreur (`tsc`, `vite build`, `cargo check`), 0 faille de dépendance |

---

## Mandat Absolu : Tolérance Zéro & Zéro Banalisation des Failles

Dans toute interaction, l'agent doit appliquer le principe d'intransigeance totale :

1. **Zéro Banalisation :** Aucune faille ne doit être ignorée, déclassée ou tolérée sous prétexte qu'elle serait "théorique", "locale", "interne" ou "de faible gravité". Tout risque identifié doit recevoir une remédiation architecturale définitive.
2. **Objectif 0 Vulnérabilité Garanti :** Chaque audit de sécurité doit impérativement afficher un résultat sans appel : **0 Critique, 0 Élevée, 0 Moyenne, 0 Faible**.
3. **Refus de Compromis :** Si une bibliothèque ou dépendance transitive présente une vulnérabilité non corrigée en amont, appliquer immédiatement des `overrides` de versions ou remplacer le paquet défaillant.

---

## Checklist Exhaustive Pré-Commit & Pré-Déploiement

Avant de valider ou committer une modification :

```
[ ] 1. Aucun secret, token ou PIN en clair dans le code source (frontend ou backend)
[ ] 2. Aucun placeholder de secret ("secret_token_placeholder", "mock_pin") dans les fichiers de prod
[ ] 3. Empreintes SHA-256 calculées dynamiquement sur le payload canonique (zéro hash statique)
[ ] 4. Modèles IA et capteurs en mode Fail-Secure (rejet par défaut en cas d'erreur)
[ ] 5. Sas de pré-vol exigeant un capteur réel (!isSimulatedStream pour un examen officiel)
[ ] 6. CSP sans 'unsafe-eval' et connect-src restreint aux domaines autorisés
[ ] 7. Liens target="_blank" protégés par rel="noopener noreferrer"
[ ] 8. Entropie cryptographique issue de window.crypto.getRandomValues() (zéro Math.random())
[ ] 9. Dépendances CDN / WASM épinglées à une version fixe sans @latest
[ ] 10. npm audit / cargo audit = 0 vulnérabilité (tous niveaux confondus)
[ ] 11. tsc --noEmit = 0 erreur TypeScript
[ ] 12. Build de production sans warning ni chunk > 500 kB
[ ] 13. SSRF guard actif sur toute requête HTTP sortante avec parsing strict std::net::IpAddr
[ ] 14. Secrets en RAM protégés par Zeroize
[ ] 15. Comparaison de hashs/PINs en temps constant (Constant-Time XOR)
[ ] 16. Typage strict sans aucun `any` ni `as unknown as T` (validation runtime via Zod)
[ ] 17. Zéro unwrap() / expect() en Rust (propagation propre d'erreurs via Result/thiserror)
[ ] 18. Timeouts stricts avec AbortController sur tout appel asynchrone / réseau
[ ] 19. Boutons protégés contre la double soumission (état de chargement immédiat et clé d'idempotence)
[ ] 20. Zéro log de debug dans la console de production (drop_console actif)
[ ] 21. Zéro token, clé API ou secret dans le frontend (purge URL immédiate et séquestre Zeroize en backend)
[ ] 22. Souveraineté backend sur les calculs, l'horodatage UTC, les compteurs critiques et l'expulsion
[ ] 23. Scellement cryptographique et reçus d'intégrité calculés et signés exclusivement côté backend
[ ] 24. audit-security-master.ps1 validé avec succès (Code 0 - Zéro anomalie)
```

---

## Scripts et Commandes de Vérification Automatisée

Les scripts utilitaires situés dans `./scripts/` doivent être exécutés pour valider l'intégrité du projet :

```powershell
# 1. Audit Maître Zéro-Vulnérabilité (Multi-Vecteurs : Secrets, Crypto, SSRF, Injections, Dépendances)
& ".agents\skills\defensive-security\scripts\audit-security-master.ps1" "."

# 2. Détection ciblée de secrets et tokens hardcodés
& ".agents\skills\defensive-security\scripts\check-secrets.ps1" "."

# 3. Audit exhaustif des dépendances (NPM, Cargo, PIP, etc. - Tolérance Zéro)
& ".agents\skills\defensive-security\scripts\audit-dependencies.ps1" "."

# 4. Validation de typage et compilation frontend
npm run build

# 5. Validation du backend natif Rust (si applicable)
cd src-tauri; cargo check
```

---

## Guides et Références Détaillées

| Référence | Contenu |
| :--- | :--- |
| [Souveraineté Backend & Zero-Trust Frontend](./references/backend-sovereignty-zero-trust-frontend.md) | Zéro secret client, purge URL immédiate, autorité backend sur l'état critique, scellement SHA-256 natif et confinement réseau |
| [Résilience Industrielle & Offline-First](./references/production-resilience-offline.md) | Timeouts stricts, retry exponentiel, anti-double soumission, tampon hors-ligne et hygiène des logs |
| [Anti-Patterns IA vs Standard Senior Engineer](./references/senior-engineer-anti-ai-patterns.md) | Éradication des failles typiques d'IA, typage strict, zéro panic, cycle de vie asynchrone |
| [Sécurité des Bases de Données](./references/secure-patterns-databases.md) | SQL paramétré, NoSQL sanitization, RLS, TLS et moindre privilège |
| [Patterns Multi-Langages](./references/secure-patterns-languages.md) | Rust, TypeScript, Python, Go, Java, C#, PHP |
| [Patterns Mobile](./references/secure-patterns-mobile.md) | Keychain, KeyStore, SQLCipher, WebViews durcies, RASP |
| [OWASP Web Top 10](./references/owasp-web-top10.md) | Synthèse des 10 risques majeurs et remédiations |
| [OWASP Mobile Top 10](./references/owasp-mobile-top10.md) | Risques mobiles M1 à M10 |
| [Headers de Sécurité](./references/security-headers.md) | CSP, HSTS, Referrer-Policy, Permissions-Policy |

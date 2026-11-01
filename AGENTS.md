# Global Security & Engineering Guidelines — Zero-Vulnerability Standard & UI/UX Excellence

Ce fichier définit les règles obligatoires et non-négociables que l'agent doit respecter et appliquer lors de toute génération ou modification de code dans ce workspace et tous ses sous-projets.

---

## 1. Protocole d'Exécution Zéro-Vulnérabilité (Mandat Absolu)

1. **Secure by Default :** Tout code produit doit intégrer la sécurité dès sa conception (défense en profondeur, moindre privilège, refus par défaut).
2. **Zéro Secret en Dur (CWE-798 & CWE-312) :** Aucun mot de passe, clé API, jeton d'accès, certificat privé, code PIN (`"2026"`, `"AGORA"`) ou token de session (`wstoken`, JWT) ne doit être écrit en dur dans le code source (frontend ou backend). Aucun placeholder de test (`"secret_token_placeholder"`, `"mock_token"`) ne doit subsister dans les bundles. Toujours utiliser des variables d'environnement (`.env` documenté via `.env.example`), un service de gestion de secrets ou un hachage cryptographique salé.
3. **Zéro Fausse Empreinte Cryptographique (CWE-345) :** Interdiction de coder en dur des hashs statiques ou simulés pour des reçus, attestations ou signatures d'examen. Les empreintes d'intégrité doivent être calculées dynamiquement sur le payload réel canonique via Web Crypto API (`window.crypto.subtle.digest`) ou crate `sha2`.
4. **Architecture Fail-Secure Obligatoire (CWE-636) :** En cas d'erreur réseau, d'exception, d'indisponibilité d'un modèle d'IA/vision ou d'absence de capteur matériel, refuser l'accès ou signaler immédiatement l'anomalie (`hasFace: false`, rejet par défaut). Le mode Fail-Open (renvoyer `true` pour masquer une panne) est strictement prohibé.
5. **Entropie Cryptographique CSPRNG (CWE-338) :** `Math.random()` est STRICTEMENT INTERDIT pour les fonctions de sécurité, tokens, identifiants de session ou clés éphémères. Utiliser exclusivement `window.crypto.getRandomValues()` ou les générateurs CSPRNG du système d'exploitation.
6. **Supply Chain & Dépendances à Zéro CVE (CWE-1357 & OWASP A06:2021) :** Bannir les imports CDN sur des tags dynamiques (`@latest`). Toujours épingler la version exacte (`@x.y.z`) avec intégrité SRI. Tout projet doit maintenir `npm audit`, `cargo audit` ou `pip-audit` à 0 vulnérabilité. En cas de vulnérabilité transitive, appliquer des `overrides` / `resolutions` immédiats.
7. **Politique CSP & Headers Réseau Durcis (CWE-1021) :** Bannir `'unsafe-eval'` de toutes les CSP. Interdire un `connect-src` permissif non restreint (`connect-src https: wss: ws:`). Whitelister exclusivement les domaines d'infrastructure requis. Tout lien externe `target="_blank"` doit obligatoirement comporter `rel="noopener noreferrer"`.
8. **Rate-Limiting & Protection Anti-Brute Force :** Tout contrôle d'authentification, de code PIN ou de déverrouillage surveillant doit intégrer un rate-limiting matériel/logiciel (ex: 3 tentatives maximum, suivi d'un verrouillage temporisé).
9. **Protection des Données en Mémoire Vive :** Nettoyage automatique des secrets de la RAM à la libération (`zeroize::ZeroizeOnDrop` en Rust). Utiliser `sessionStorage` plutôt que `localStorage` pour les données d'épreuves sensibles afin d'éviter les fuites post-session.
10. **Masquage des Erreurs (CWE-209) :** Ne jamais renvoyer de détails techniques internes (stack traces, messages d'erreurs SQL détaillés, chemins locaux `C:\...`) au client. Renvoyer des messages d'erreur génériques tout en journalisant les détails de manière sécurisée en interne.
11. **Comparaisons Cryptographiques en Temps Constant (CWE-208) :** Toute comparaison de hashs de mots de passe, empreintes d'intégrité, signatures ou codes PIN doit être exécutée en temps constant (Constant-Time XOR / `crypto/subtle.ConstantTimeCompare` / crate `subtle::ConstantTimeEq`) afin d'éliminer toute attaque par canal auxiliaire temporel (Timing Attacks).
12. **Parsing IP Typé Strict pour SSRF (CWE-918) :** Bannir les filtres textuels naïfs (`contains("10.")`). Toujours parser rigoureusement les adresses résolues via `std::net::IpAddr` (Rust) ou modules réseau natifs et vérifier explicitement `is_private()`, `is_loopback()` et les adresses de métadonnées cloud (`169.254.169.254`).
13. **Mandat de Tolérance Zéro & Zéro Banalisation des Failles :** Interdiction formelle de minimiser, déclasser ou ignorer une vulnérabilité sous prétexte qu'elle serait "théorique", "interne", "locale" ou "de sévérité faible". Chaque audit de sécurité doit impérativement valider **0 vulnérabilité** (0 Critique, 0 Élevée, 0 Moyenne, 0 Faible) via `audit-security-master.ps1`.
14. **Souveraineté Backend & Zéro Donnée Sensible dans le Frontend (Zero-Trust Frontend Architecture) :**
    - Interdiction formelle de stocker des jetons d'accès API (`wstoken`, JWT privé, clés secrètes d'infrastructure, certificats ou clés de déchiffrement) ou des données nominatives non masquées dans le frontend : ni dans `localStorage`, ni dans `sessionStorage`, ni dans `IndexedDB`, ni dans l'état global React/Vue/Svelte, et surtout JAMAIS dans les query parameters de l'URL (`?token=...`).
    - Tout secret ou token reçu lors d'un lancement (LMS deep-link, SSO handshake) doit être immédiatement transféré au backend sécurisé (Rust via IPC ou API serveur) et purgé de manière irréversible de l'historique et de l'URL (`window.history.replaceState`).
    - Le backend est la SEULE autorité sur la logique métier critique, les calculs sensibles (prix, quotas, scores, compteurs de fautes, droits d'accès) et les décisions d'exécution (bannissement, clôture d'examen, soumission forcée). Le frontend ne prend JAMAIS de décision critique via des conditions du type `if (strikes >= 3)`.
    - Les horodatages officiels et scellements cryptographiques (SHA-256) doivent être calculés et signés exclusivement côté backend.
    - Toutes les requêtes vers les services d'infrastructure ou APIs distantes s'effectuent par le client HTTP du backend (Rust `reqwest`), éliminant l'interception et le rejeu depuis les DevTools.

---

## 2. Règles pour les Bases de Données (SQL & NoSQL)

1. **Zéro Concaténation SQL :** Interdiction absolue de concaténer ou d'interpoler des variables utilisateur dans des chaînes de requêtes SQL. Toujours utiliser des requêtes préparées paramétrées ou les méthodes natives des ORM.
2. **Moindre Privilège DB :** Ne jamais configurer l'application avec un utilisateur super-administrateur de base de données (`root`, `postgres`, `sa`). Définir des utilisateurs dédiés avec les seuls privilèges nécessaires (`SELECT`, `INSERT`, `UPDATE`).
3. **Row-Level Security (RLS) :** Pour les architectures multi-tenants ou exposées directement, activer et configurer systématiquement les politiques RLS.
4. **Protection NoSQL :** Sanitiser les clés et types d'entrées pour bloquer les injections NoSQL (ex: opérateurs `$gt`, `$ne`, `$where`, `$regex` dans MongoDB).
5. **Chiffrement au Repos & en Transit :** Exiger TLS/SSL pour toute connexion à la base de données. Chiffrer les colonnes contenant des PII (données personnelles) ou données bancaires.

---

## 3. Règles par Langage & Framework

- **JavaScript / TypeScript (Node.js & React) :** Valider avec Zod/Joi, sécuriser les cookies de session (`httpOnly`, `secure`, `sameSite: 'strict'`), utiliser Helmet pour les headers HTTP, zéro `dangerouslySetInnerHTML` non assaini.
- **Rust (Axum / Actix-web / Tokio / Tauri) :**
  - Interdiction absolue des blocs `unsafe` non audités (appliquer `#![forbid(unsafe_code)]` par défaut).
  - Bannir les `unwrap()` ou `expect()` en production qui provoquent des panics DoS ; utiliser le typage d'erreur robuste (`thiserror` / `anyhow` / `Result<T, E>`).
  - Effacer automatiquement les secrets de la mémoire vive (RAM) à la libération avec la crate `zeroize::ZeroizeOnDrop`.
  - Protection anti-SSRF obligatoire sur toute requête HTTP sortante (blocage loopback, RFC1918 et cloud metadata `169.254.169.254`).
  - Préférer la stack TLS 100% Rust (`rustls` / `ring`) aux liaisons C vers OpenSSL.
  - Valider les requêtes SQL à la compilation avec les macros `sqlx::query!`.
- **Python (FastAPI / Django / Flask) :** Utiliser Pydantic pour la validation des schémas, SQLAlchemy avec requêtes paramétrées, `DEBUG = False` en production sur Django, activer le CSRF middleware.
- **Java / Kotlin (Spring Boot) :** Configurer `SecurityFilterChain`, activer `@PreAuthorize`, valider les DTO avec Jakarta Bean Validation (`@Valid`, `@NotNull`, `@Size`), interdire l'évaluation SpEL non assainie.
- **C# / .NET :** Utiliser Entity Framework avec `FromSqlInterpolated` (jamais `FromSqlRaw` non vérifié), activer `[ValidateAntiForgeryToken]`, appliquer l'authentification basée sur les claims/rôles.
- **PHP (Laravel / Symfony) :** Utiliser les Form Requests et Eloquent ORM, désactiver `APP_DEBUG` en production, forcer HTTPS et cookies stricts.
- **Go :** Valider avec `validator/v10`, imposer des timeouts sur `http.Client` et `http.Server`, utiliser `crypto/subtle.ConstantTimeCompare` pour les comparaisons sensibles.

---

## 4. Règles d'Ingénierie UI/UX (Anti-« AI Slop » & Rigueur Produit)

1. **Bannir les Clichés IA :** Interdiction des dégradés violets criards non justifiés, néons superflus, cartes flottantes disproportionnées sans hiérarchie claire.
2. **Design Tokens & Grille 8pt :** Utiliser exclusivement des variables de tokens sémantiques (`background`, `foreground`, `primary`, `muted`, `border`) et des espacements multiples de 4px / 8px. Zéro couleur codée en dur (`#hex` arbitraire).
3. **Les 5 États Obligatoires :** Tout composant de données doit implémenter : état nominal, chargement (skeleton loader épousant la forme), liste vide (empty state avec CTA), erreur (message clair + bouton retry), et focus accessible.
4. **Accessibilité (WCAG AA) :** Contraste minimal de 4.5:1, `focus-visible:ring-2` obligatoire sur tous les éléments cliquables, et `aria-label` sur chaque bouton d'icône.
5. **Ergonomie Mobile :** Respecter les zones tactiles minimales (48x48 dp), intégrer la Safe Area (`useSafeAreaInsets`), et placer les actions clés dans la zone du pouce (Thumb Zone).
6. **Micro-Animations GPU Fluides & 60 FPS :**
   - Animer exclusivement les propriétés GPU (`transform: translate3d/scale/rotate`, `opacity`) avec courbes fluides (`cubic-bezier(0.16, 1, 0.3, 1)`).
   - Bannir formellement les animations de reflow (`width`, `height`, `margin`, `top`, `left`).
   - Respecter impérativement `@media (prefers-reduced-motion: reduce)` pour l'accessibilité mouvement.
7. **Logos Authentiques & Téléchargement d'Assets Officiels :**
   - Interdiction formelle d'utiliser des emojis ou des icônes génériques (chapeau d'étudiant, globe, pictogramme non officiel) comme logos d'universités, d'institutions ou d'outils tiers (Moodle, ministères, entreprises).
   - Exiger systématiquement les véritables logos officiels vectoriels (SVG). Si un logo n'est pas présent dans le dépôt, l'agent doit obligatoirement le télécharger et l'enregistrer dans les assets locaux du projet (ex: `public/logos/`).

---

## 5. Règles DevSecOps, Docker & Déploiement Cloud

1. **Conteneurs Non-Root Obligatoires :** Tout `Dockerfile` de production doit spécifier un utilisateur non privilégié (`USER 10001:10001` ou `USER nonroot`) et utiliser des builds multi-étapes (*multi-stage*).
2. **Images Minimales & Épurées :** Préférer les images Distroless ou Alpine/Debian-slim. Ne jamais embarquer de compilateurs ou de code de debug dans l'image finale.
3. **Moindre Privilège CI/CD :** Tout workflow GitHub Actions doit débuter avec `permissions: read-all`. Déployer vers le cloud exclusivement via OIDC temporaire (jamais de clés AWS/GCP permanentes dans les secrets).
4. **Kubernetes Sécurisé :** Appliquer le profil de sécurité `restricted` (PSS), interdire l'élévation de privilèges (`allowPrivilegeEscalation: false`), monter le système de fichiers en lecture seule (`readOnlyRootFilesystem: true`), et définir des `NetworkPolicies` d'isolation par défaut.
5. **Déploiement Zéro-Interruption (Zero-Downtime) :** Configurer systématiquement les 3 sondes de santé (`startupProbe`, `readinessProbe`, `livenessProbe`) et utiliser des stratégies de déploiement progressives (Rolling Update durci, Blue/Green ou Canary).

---

## 6. Cryptographie & Authentification

- **Mots de passe :** Hashing obligatoire avec **Argon2id** (recommandé), **bcrypt** (work factor ≥ 10), ou **scrypt**. Interdiction totale de MD5, SHA-1, SHA-256 sans salt.
- **PIN & Codes Surveillants :** Hachage cryptographique SHA-256 avec sel ou PBKDF2 avec rate-limiting temporel.
- **Sessions & Tokens :** Access tokens JWT à durée de vie courte (≤ 15 minutes), refresh tokens avec rotation et invalidation lors du logout.
- **Chiffrement symétrique :** **AES-256-GCM** ou **ChaCha20-Poly1305** (chiffrement authentifié uniquement, pas d'AES-ECB ni d'AES-CBC sans HMAC).

---

## 7. Standard Ingénieur Senior : Éradication des Failles et Anti-Patterns IA

Ce référentiel prohibe formellement les raccourcis d'implémentation et négligences logicielles typiquement observés dans le code généré par les IA :

1. **Zéro Évasion de Type (CWE-843 & Type Safety) :**
   - Interdiction totale de `any`, `as unknown as T` ou `@ts-ignore` non justifiés.
   - Toute charge utile externe (API, IPC, localStorage) doit être rigoureusement validée au runtime par schéma (Zod, ArkType ou TypeBox) avant d'être consommée.
2. **Zéro Panic en Production (Rust & Systèmes) :**
   - Interdiction formelle des méthodes `.unwrap()` et `.expect()` sur des opérations I/O, parsing ou réseau en production.
   - Toute erreur doit être typée et gérée via `Result<T, E>` avec `thiserror` (crates) ou enrichie via `anyhow::Context` (binaires/applications).
3. **Gestion Asynchrone Propre & Annulation :**
   - Tout appel asynchrone, fetch ou écouteur de longue durée doit intégrer un `AbortController` et une fonction de nettoyage (*cleanup function*) lors du démontage pour prévenir les *Race Conditions* et les fuites de mémoire.
4. **Architecture Découplée vs Monolithes "God Files" :**
   - Interdiction des fichiers uniques démesurés (> 1000 lignes) mélangeant état global, effets de bord, calculs cryptographiques et rendu JSX.
   - Découpage strict selon les principes de Clean Architecture : Domaine (pur), Infrastructure (adaptateurs API/stockage) et Présentation (composants UI, hooks dédiés).
5. **Résilience et Mode Fail-Secure Universel :**
   - Ne jamais utiliser de blocs `catch` silencieux ou renvoyer un statut permissif par défaut pour masquer un échec réseau ou matériel.
   - Toujours journaliser l'erreur en interne de manière sécurisée et renvoyer un état d'erreur clair et remédiable à l'utilisateur.
6. **Commentaires de Code Professionnels & Zéro Emojis Décoratifs :**
   - Proscrire formellement les emojis décoratifs (`🚀`, `💡`, `🔥`, `⚡`, `🛡️`) et jargons superflus dans les commentaires source.
   - Utiliser des commentaires sobres, concis et professionnels (format standard JSDoc, TSDoc ou Rustdoc) expliquant la logique métier et les décisions d'architecture.
7. **UX Writing & Zéro Jargon Utilisateur :**
   - Interdiction formelle d'exposer des codes d'erreur informatiques bruts (401, 404, 500, 504), des acronymes techniques (SSRF, SHA-256, CORS, IPC) ou des stack traces à l'utilisateur.
   - Tout message d'interface doit répondre en français clair, empathique et constructif aux 3 questions : *Que s'est-il passé ? Quel est l'impact sur mes données ? Quelle est la solution immédiate ?*
8. **Résilience Industrielle, Timeouts Stricts & Mode Hors-Ligne :**
   - Tout appel asynchrone / réseau doit comporter un timeout strict (ex: 8s via `AbortController`) et un retry exponentiel avec gigue (*Jitter*).
   - En cas de perte réseau, mise en tampon locale sécurisée et synchronisation automatique sans perte lors du retour de la connectivité.
9. **Idempotence & Protection Anti-Double Soumission :**
   - Verrouillage instantané des boutons dès le premier clic avec libellé rassurant (« Enregistrement sécurisé... ») pour éliminer les doubles clics.
   - Utilisation de clés d'idempotence (`Idempotency-Key`) pour sécuriser les transactions critiques.
10. **Hygiène des Logs en Production (Zéro Bruit en Console) :**
    - Suppression automatique des `console.log` et `console.debug` lors de la compilation de production (`drop_console: true`).
    - Masquage systématique des informations nominatives et jetons dans les journaux d'erreurs internes.

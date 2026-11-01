---
description: "Règles globales de sécurité défensive, DevSecOps et d'ingénierie UI/UX (Protocole Zéro-Vulnérabilité & Professional UX)"
always_on: true
---

# Règle Globale : Protocole Zéro-Vulnérabilité, DevSecOps & Ingénierie UI/UX

Cette règle s'applique à l'ensemble du projet, à tous les fichiers sources et à chaque interaction de génération ou modification de code.

## Principes Directeurs et Mandat Absolu
1. **Zéro secret dans le code (CWE-798 & CWE-312) :** Aucun mot de passe, token (`wstoken`, JWT), code PIN (`"2026"`), clé API ou placeholder (`"secret_token_placeholder"`) en dur. Utiliser exclusivement des variables d'environnement (`.env`) ou des gestionnaires de secrets.
2. **Intégrité réelle & Zéro faux hash (CWE-345) :** Interdiction totale d'empreintes SHA-256 fictives ou statiques. Toute attestation d'intégrité doit être calculée mathématiquement en temps réel sur le payload canonique.
3. **Fail-Secure par défaut (CWE-636) :** Tout contrôle d'authentification, de rôle ou de vision IA doit refuser l'accès ou signaler l'absence en cas de panne ou d'erreur (`hasFace: false`). Le Fail-Open est strictement banni.
4. **Entropie CSPRNG (CWE-338) :** `Math.random()` est formellement interdit pour toute opération de sécurité. Utiliser `window.crypto.getRandomValues()` ou le CSPRNG de l'OS.
5. **Supply chain & Dépendances à Zéro CVE (CWE-1357) :** Épingler strictement les versions de packages et WASM (pas de `@latest`). Garantir `npm audit`, `cargo audit` ou `pip-audit` à 0 vulnérabilité.
6. **CSP & Réseau durcis (CWE-1021) :** Bannir `'unsafe-eval'`. Whitelister strictement `connect-src`. Protéger tous les `target="_blank"` par `rel="noopener noreferrer"`.
7. **Zéro injection SQL / NoSQL (CWE-89 & CWE-943) :** Toujours paramétrer les requêtes ou passer par des ORMs sécurisés.
8. **Validation stricte côté serveur :** Toujours valider les types, longueurs, formats et plages des données en entrée (whitelist).
9. **Moindre privilège :** Pour les bases de données, les rôles applicatifs, les accès fichiers et les permissions CI/CD (`permissions: read-all`).
10. **Chiffrement moderne & Constant-Time :** TLS 1.2+ obligatoire, mots de passe hashés avec Argon2id ou bcrypt, chiffrement authentifié (AES-256-GCM). Comparaison de hashs cryptographiques et PINs en temps constant exclusif (CWE-208 Timing Attack).
11. **Conteneurs & DevSecOps :** Multi-stage builds, conteneurs non-root (`USER nonroot`), OIDC cloud, pods Kubernetes restreints, sondes de santé pour déploiement sans coupure.
12. **Ingénierie UI/UX Sérieuse (Anti-AI Slop) :** Bannir les dégradés violets criards et néons superflus. Appliquer la grille 8pt, les tokens sémantiques de design system, les 5 états obligatoires (loading skeleton, empty, error, default, focus accessible) et la conformité WCAG AA (contraste ≥ 4.5:1, `focus-visible:ring-2`). Micro-animations légères GPU-accélérées (transform/opacity) avec respect strict de `prefers-reduced-motion`.
13. **Mobile sécurisé :** Keychain/EncryptedSharedPreferences pour le stockage, pas de logs sensibles en production, intégration stricte de la Safe Area et cibles tactiles minimales de 48x48 dp.
14. **Rigueur Senior Software Engineer (Anti-Biais IA) :**
    - Zéro `any`, zéro `as unknown as T` non validé (validation runtime obligatoire avec Zod/Typebox/ArkType).
    - Zéro panic en production : aucun `unwrap()` ou `expect()` en Rust (utiliser `thiserror` / `anyhow` et `Result<T, E>`).
    - Gestion propre du cycle asynchrone : annulation systématique des requêtes via `AbortController` et nettoyage rigoureux des timers/listeners.
    - Masquage des chemins locaux (`C:\...`) et stack traces pour le client (CWE-209).
    - Parsing strict des adresses IP réseau (`std::net::IpAddr::is_private()`) pour la protection anti-SSRF (CWE-918), sans faux positifs.
15. **Logos Réels & Téléchargement d'Assets :** Interdiction formelle des emojis ou des icônes génériques de librairies pour représenter des universités, ministères ou logiciels tiers (Moodle, AWS, etc.). Utiliser exclusivement les vrais logos vectoriels officiels (SVG). Si manquant, obligation de télécharger l'asset SVG officiel et de l'enregistrer localement dans `public/logos/`.
16. **Commentaires de Code Professionnels :** Proscrire formellement tout emoji décoratif (`🚀`, `💡`, `🔥`, `⚡`) dans les commentaires source. Adopter un style sobre d'ingénieur senior (JSDoc, TSDoc ou Rustdoc).
17. **UX Writing & Zéro Jargon Utilisateur :** Aucun code d'erreur brut (401, 500, 504) ni acronyme technique exposé à l'utilisateur. Formulation claire répondant aux 3 questions : *Que s'est-il passé ? Quel est l'impact ? Que faire maintenant ?*
18. **Résilience Réseau & Offline-First :** Timeouts stricts avec AbortController (8-10s max), retry exponentiel avec gigue (*Jitter*), et synchronisation transparente via tampon local sécurisé lors des coupures réseau.
19. **Idempotence & Anti-Double Soumission :** Verrouillage automatique des boutons au clic et génération de clés d'idempotence UUID pour interdire les requêtes dupliquées.
20. **Hygiène Absolue des Logs en Production :** Suppression automatique des `console.log` et `console.debug` au build (`drop_console`), et masquage systématique des données nominatives (PII redaction).
21. **Mandat de Tolérance Zéro & Zéro Banalisation des Failles :** Interdiction absolue d'ignorer, de tolérer ou de déclasser une anomalie sous prétexte qu'elle serait "théorique" ou "locale". Tout projet doit impérativement valider le passage de l'audit maître `audit-security-master.ps1` avec un score de **0 vulnérabilité** (0 Critique, 0 Élevée, 0 Moyenne, 0 Faible).
22. **Souveraineté Backend & Zéro Donnée Sensible dans le Frontend (Zero-Trust Frontend Architecture) :**
    - Interdiction formelle de stocker des jetons d'accès API (`wstoken`, JWT privé, clés secrètes d'infrastructure, certificats ou clés de déchiffrement) ou des données nominatives non masquées dans le frontend : ni dans `localStorage`, ni dans `sessionStorage`, ni dans `IndexedDB`, ni dans l'état global React/Vue/Svelte, et surtout JAMAIS dans les query parameters de l'URL (`?token=...`).
    - Tout secret ou token reçu lors d'un lancement (LMS deep-link, SSO handshake) doit être immédiatement transféré au backend sécurisé (Rust via IPC ou API serveur) et purgé de manière irréversible de l'historique et de l'URL (`window.history.replaceState`).
    - Le backend est la SEULE autorité sur la logique métier critique, les calculs sensibles (prix, quotas, scores, compteurs de fautes, droits d'accès) et les décisions d'exécution (bannissement, clôture d'examen, soumission forcée). Le frontend ne prend JAMAIS de décision critique via des conditions du type `if (strikes >= 3)`.
    - Les horodatages officiels et scellements cryptographiques (SHA-256) doivent être calculés et signés exclusivement côté backend.
    - Toutes les requêtes vers les services d'infrastructure ou APIs distantes s'effectuent par le client HTTP du backend (Rust `reqwest`), éliminant l'interception et le rejeu depuis les DevTools.

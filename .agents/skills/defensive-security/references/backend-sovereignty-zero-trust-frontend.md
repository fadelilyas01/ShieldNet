# Souveraineté Backend & Architecture Zero-Trust Frontend
## Standard d'Ingénierie Logicielle : Zéro Donnée Sensible Côté Client

Ce document de référence établit la doctrine obligatoire pour la conception de toute application logicielle (Web, Desktop Tauri/Electron, Mobile). Il définit le paradigme **Zero-Trust Frontend** : le client ne doit jamais héberger de données sensibles, de secrets d'infrastructure ni exercer d'autorité décisionnelle sur la sécurité.

---

## 1. Le Postulat Fondamental : Le Frontend est un Territoire Hostile

Dans tout système informatique, le frontend (navigateur web, DOM, WebView desktop ou mobile, runtime JavaScript) doit impérativement être considéré comme un **environnement non fiable et potentiellement compromis** :
- L'utilisateur final dispose d'un accès total aux DevTools, au débogueur, à la console JavaScript et à l'arborescence DOM.
- Les scripts peuvent être altérés, les fonctions natives monkeypatchées (`window.fetch = ...`, `EventTarget.prototype.addEventListener = ...`), les extensions de navigateur peuvent intercepter les flux en mémoire et les requêtes réseau peuvent être inspectées, rejouées ou falsifiées.
- **La règle d'or :** *Le frontend n'est qu'une couche de présentation (UI/UX). Le backend (serveur distant ou runtime natif Rust/OS) est la seule et unique autorité de sécurité.*

---

## 2. Éradication des Données Sensibles Côté Client (CWE-312 & CWE-922)

### Ce qui est STRICTEMENT INTERDIT dans le Frontend
1. **Zéro Jeton d'Accès d'Infrastructure :**
   - Interdiction formelle de conserver des tokens d'API de services tiers (`wstoken` Moodle, clés secrètes AWS, tokens d'administration, clés privées Stripe/Paiement) dans les variables d'état (React `useState`, Redux, Zustand) ou dans les objets globaux (`window.config`).
2. **Zéro Stockage Persistant Non Chiffré de Données d'Authentification :**
   - Interdiction d'écrire des tokens ou des secrets dans `localStorage` ou `IndexedDB` (exposés aux attaques XSS et persistants post-session).
   - `sessionStorage` ne doit être utilisé que pour des états de confort UI éphémères non critiques.
3. **Zéro Secret dans les URLs & Query Parameters (CWE-598) :**
   - Aucun token d'accès (`?token=...`, `?wstoken=...`, `?secret=...`) ne doit séjourner dans l'URL, car il fuite irrémédiablement dans les journaux d'accès HTTP des serveurs/proxys, l'historique du navigateur et les en-têtes HTTP `Referer`.

### Le Protocole d'Ingestion & Purge Immédiate (Token Vaulting)
Lorsqu'un jeton d'accès ou paramètre de session doit être transmis à l'application (ex: lancement via deep-link `app://` ou redirection LMS Moodle) :
1. **Ingestion Immédiate :** Dès la première milliseconde d'initialisation, le frontend transmet le secret directement au runtime backend sécurisé (Rust via commande IPC ou serveur via canal sécurisé).
2. **Purge Irréversible de l'URL :** Le frontend exécute instantanément la purge de la barre d'adresse et de l'historique :
   ```typescript
   // Purge immédiate et irréversible des secrets de l'URL
   const cleanUrl = new URL(window.location.href);
   cleanUrl.searchParams.delete("wstoken");
   cleanUrl.searchParams.delete("token");
   cleanUrl.searchParams.delete("secret");
   window.history.replaceState({}, document.title, cleanUrl.pathname + cleanUrl.hash);
   ```
3. **Séquestre Mémoire Protégé Côté Backend :** Le backend réceptionne le secret dans une structure protégée par effacement automatique à la libération de la RAM :
   ```rust
   // Rust : Nettoyage physique des octets de la RAM à la libération (Anti-Memory Dump)
   #[derive(Clone, zeroize::Zeroize, zeroize::ZeroizeOnDrop)]
   pub struct SecureSessionVault {
       pub api_url: String,
       pub secret_token: String,
       pub session_id: u64,
   }
   ```

---

## 3. Souveraineté Backend sur la Logique Métier et les États Critiques

### L'Anti-Pattern Typique : La Condition Critique Côté Client
```typescript
// ❌ FAILLE MAJEURE : L'IA confie l'autorité de sécurité au client
if (strikesCount >= 3) {
  // L'utilisateur peut intercepter ou neutraliser cet appel en console JS !
  await expulserEtudiant({ token: userToken });
}
```

### Le Standard Senior Engineer : Le Backend Décideur et Exécuteur
Le frontend se borne à remonter des faits bruts (événements de télémétrie, motifs d'anomalie, réponses utilisateur). Le backend évalue souverainement les règles et déclenche lui-même les conséquences :

```rust
// ✅ STANDARD SENIOR : Rust est le seul juge et exécuteur de la décision
pub fn enregistrer_infraction(
    state: &ExamState,
    motif: &str,
) -> Result<InfractionResult, ProctorError> {
    // 1. Incrémentation atomique interne protégée contre toute altération JS
    let strike_count = state.strikes.fetch_add(1, Ordering::SeqCst) + 1;
    
    // 2. Décision autonome du backend selon la politique active
    let is_expelled = strike_count >= 3 && state.get_policy() == "strict";
    
    if is_expelled {
        // Le backend déclenche lui-même l'expulsion via son séquestre interne
        // Zéro dépendance envers une instruction du frontend
        state.declencher_killswitch_immediat()?;
    }
    
    Ok(InfractionResult { strike_count, is_expelled })
}
```

---

## 4. Intégrité Cryptographique & Horodatage Faisant Foi (CWE-345)

1. **Horloge Système Monotonique :**
   - L'horloge de la machine de l'utilisateur (`new Date()`, `Date.now()`) peut être avancée, reculée ou falsifiée par le système hôte.
   - Tout calcul de durée d'épreuve, d'expiration de session ou d'horodatage d'incident légal doit être validé par une source d'horloge serveur certifiée ou l'horloge système UTC interne du backend natif (`chrono::Utc::now()`).
2. **Calcul Souverain des Attestations et Reçus d'Audit :**
   - Le scellement cryptographique d'un audit trail, d'un reçu d'examen ou d'une transaction ne doit JAMAIS être calculé en JavaScript.
   - Le payload canonique est assemblé par le backend avec les données qu'il a lui-même certifiées (compteur d'incidents officiel, horodatage UTC, statut de confinement OS).
   - L'empreinte SHA-256 / signature HMAC est générée en Rust (`sha2::Sha256`), enregistrée dans un fichier scellé sur disque avec son fichier de contrôle `.sha256`, puis seulement mise à disposition du client en lecture seule.

---

## 5. Confinement Réseau & Élimination des Fuites DevTools

1. **Requêtes d'Infrastructure Émises Exclusivement par le Backend :**
   - Toutes les communications avec des services d'infrastructure critiques (LMS Moodle, bases de données, passerelles bancaires) doivent être émises par le client HTTP du backend natif (Rust `reqwest`, Go `net/http`, Python `httpx`).
   - Le réseau de la WebView / du navigateur ne doit jamais être sollicité pour ces échanges.
2. **Avantages de Sécurité Infranchissables :**
   - **Protection Anti-Sniffing :** Aucun jeton ni en-tête d'autorisation ne transite dans l'onglet *Network* des DevTools du navigateur.
   - **Protection Anti-Rejeu :** L'étudiant ou l'attaquant ne peut pas copier la requête en format `cURL` depuis son navigateur pour exécuter des appels hors-contexte.
   - **Protection Anti-SSRF Durcie (CWE-918) :** Le backend applique un parsing IP typé strict (`std::net::IpAddr`), bloquant loopback, RFC1918 et adresses de métadonnées cloud (`169.254.169.254`).

---

## 6. Surveillance Matérielle et Kiosk au Niveau OS

Pour toute application de surveillance, d'examen sécurisé ou de poste dédié :
1. **Watchdog Indépendant :**
   - Le contrôle de l'intégrité de la fenêtre (anti-minimisation, maintien en plein écran, détection de branchement d'écran secondaire HDMI à chaud) doit tourner dans une boucle asynchrone autonome de fond (ex: thread Tokio cadencé à 350ms).
   - Les événements du DOM (`window.onblur`, `document.visibilitychange`) ne sont que des capteurs d'appoint.
2. **Neutralisation Native du Presse-Papier :**
   - Le presse-papier du système d'exploitation doit être purgé dès l'entrée dans la zone sécurisée.
   - Toute opération `copy`, `cut` ou `paste` est interceptée et annulée au niveau du runtime.

---

## 7. Grille d'Évaluation & Checklist d'Audit

| Question d'Audit | Statut Exigé | Risque Associé si Non-Conforme |
| :--- | :---: | :--- |
| Y a-t-il un token d'API ou secret d'infrastructure dans l'état React / Vue ? | **NON (0 tolérance)** | CWE-312 : Fuite de secrets en mémoire vive et console |
| Les paramètres d'URL sensibles sont-ils purgés au montage ? | **OUI (Immédiat)** | CWE-598 : Fuite de tokens dans les en-têtes Referer et logs |
| Le frontend décide-t-il d'un bannissement ou d'une clôture via un `if ()` ? | **NON (Interdit)** | CWE-602 : Contournement de logique par injection de code client |
| L'empreinte SHA-256 du scellement d'examen est-elle calculée dans Rust ? | **OUI (Souverain)** | CWE-345 : Falsification d'attestation ou de reçu d'examen |
| Les requêtes réseau sensibles transitent-elles par le client HTTP du backend ? | **OUI (100% Rust)** | OWASP A01 : Interception de tokens et falsification DevTools |
| Les secrets en RAM côté backend sont-ils protégés par `Zeroize` ? | **OUI** | CWE-316 : Rémanence de données sensibles dans les dumps mémoire |

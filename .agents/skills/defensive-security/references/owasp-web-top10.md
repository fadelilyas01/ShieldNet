# OWASP Web Application Top 10 (2021) — Référence défensive

Ce document détaille les 10 catégories de vulnérabilités web les plus critiques
selon OWASP, avec les contre-mesures défensives à appliquer.

---

## A01:2021 — Broken Access Control (Contrôle d'accès défaillant)

**Description :** Les restrictions sur ce que les utilisateurs authentifiés sont
autorisés à faire ne sont pas correctement appliquées. Les attaquants exploitent
ces failles pour accéder à des fonctionnalités ou données non autorisées.

**Impact :** Accès non autorisé à des comptes d'utilisateurs, données sensibles,
modification/suppression de données, élévation de privilèges.

### Contre-mesures

1. **Refuser par défaut** — Toute ressource doit être interdite sauf si
   explicitement autorisée.
2. **Vérification côté serveur** — Ne jamais se fier aux contrôles côté client.
   Vérifier les permissions à chaque requête.
3. **Contrôle d'accès basé sur les rôles (RBAC)** — Implémenter un système de
   rôles granulaire centralisé.
4. **Désactiver le listing de répertoires** — Empêcher l'énumération de fichiers
   sur le serveur web.
5. **Journaliser les échecs d'accès** — Logger et alerter sur les tentatives
   d'accès refusées répétées.

```javascript
// ❌ MAUVAIS : Vérification côté client uniquement
if (user.role === 'admin') {
  showAdminPanel();
}

// ✅ BON : Vérification côté serveur systématique
app.get('/admin/users', authorize('admin'), async (req, res) => {
  // Le middleware authorize() vérifie le rôle avant l'exécution
  const users = await User.findAll();
  res.json(users);
});
```

---

## A02:2021 — Cryptographic Failures (Défaillances cryptographiques)

**Description :** Failles liées à la cryptographie (ou son absence), exposant
des données sensibles : mots de passe, numéros de carte, données de santé, PII.

**Impact :** Vol de données sensibles, usurpation d'identité, fraude, non-
conformité réglementaire (RGPD, PCI DSS).

### Contre-mesures

1. **Classifier les données** — Identifier quelles données sont sensibles et
   appliquer des contrôles proportionnels.
2. **Chiffrer en transit** — TLS 1.2+ obligatoire, HSTS activé.
3. **Chiffrer au repos** — AES-256 pour les données sensibles stockées.
4. **Hasher les mots de passe** — Utiliser Argon2id, bcrypt, ou scrypt avec un
   salt unique et un coût adapté.
5. **Ne pas inventer sa crypto** — Utiliser des bibliothèques éprouvées
   (libsodium, OpenSSL, Web Crypto API).

```python
# ❌ MAUVAIS : MD5 / SHA1 pour les mots de passe
import hashlib
hashed = hashlib.md5(password.encode()).hexdigest()

# ✅ BON : Argon2id avec paramètres appropriés
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)
hashed = ph.hash(password)
# Vérification
try:
    ph.verify(hashed, password_attempt)
except argon2.exceptions.VerifyMismatchError:
    raise AuthenticationError("Invalid credentials")
```

---

## A03:2021 — Injection

**Description :** Les données fournies par l'utilisateur sont envoyées à un
interpréteur sans validation ni échappement. Inclut : SQL injection, NoSQL
injection, OS command injection, LDAP injection, XSS.

**Impact :** Vol ou corruption de données, prise de contrôle du serveur,
déni de service.

### Contre-mesures

1. **Requêtes paramétrées** — Utiliser systématiquement des requêtes préparées
   ou des ORM.
2. **Validation des entrées** — Valider par whitelist (type, longueur, format).
3. **Encodage contextuel des sorties** — Encoder selon le contexte (HTML, JS,
   SQL, URL, CSS).
4. **Principe du moindre privilège DB** — L'application ne doit pas utiliser un
   compte DB avec des privilèges admin.
5. **WAF en complément** — Un WAF peut aider mais ne remplace pas le code sécurisé.

```javascript
// ❌ MAUVAIS : Concaténation SQL
const query = `SELECT * FROM users WHERE id = '${req.params.id}'`;

// ✅ BON : Requête paramétrée
const query = 'SELECT * FROM users WHERE id = $1';
const result = await db.query(query, [req.params.id]);

// ✅ BON : ORM avec validation
const user = await User.findByPk(req.params.id, {
  attributes: ['id', 'name', 'email'] // Limiter les champs exposés
});
```

---

## A04:2021 — Insecure Design (Conception non sécurisée)

**Description :** Failles liées à des erreurs de conception architecturale, et
non à des bugs d'implémentation. Aucun correctif de code ne peut compenser une
architecture fondamentalement non sécurisée.

**Impact :** Vulnérabilités systémiques qui nécessitent une refonte, exposition
massive de données.

### Contre-mesures

1. **Threat modeling** — Réaliser une analyse des menaces dès la conception.
2. **User stories d'abus** — Pour chaque fonctionnalité, définir les scénarios
   d'abus possibles.
3. **Separation of concerns** — Isoler les composants critiques (auth, paiement).
4. **Limites et quotas** — Définir des limites métier (nombre de transactions,
   montant maximal, etc.).
5. **Tests de sécurité dès le design** — Intégrer les tests de sécurité dans le
   cycle de développement.

---

## A05:2021 — Security Misconfiguration (Mauvaise configuration)

**Description :** Configurations par défaut non sécurisées, configurations
incomplètes, stockage cloud ouvert, headers HTTP mal configurés, messages
d'erreur verbeux contenant des informations sensibles.

**Impact :** Accès non autorisé, fuite d'informations, compromission du serveur.

### Contre-mesures

1. **Hardening automatisé** — Utiliser des processus de durcissement
   reproductibles (IaC, scripts de configuration).
2. **Environnements identiques** — Dev, staging et prod doivent avoir les mêmes
   configurations de sécurité.
3. **Supprimer le superflu** — Désactiver les fonctionnalités, frameworks et
   composants non utilisés.
4. **Revue des permissions cloud** — Auditer régulièrement les permissions S3,
   Azure Blob, GCS.
5. **Headers de sécurité** — Voir [security-headers.md](./security-headers.md).

---

## A06:2021 — Vulnerable and Outdated Components (Composants vulnérables)

**Description :** Utilisation de composants (bibliothèques, frameworks, OS) avec
des vulnérabilités connues ou qui ne sont plus maintenus.

**Impact :** Exploitation de CVE connues, compromission de l'application.

### Contre-mesures

1. **Inventaire des dépendances** — Maintenir un SBOM (Software Bill of Materials).
2. **Audit automatisé** — `npm audit`, `pip audit`, `dotnet list package --vulnerable`.
3. **Mises à jour régulières** — Planifier des mises à jour de dépendances
   (hebdomadaires ou via Dependabot/Renovate).
4. **Lockfile** — Committer le lockfile et vérifier son intégrité.
5. **Surveiller les advisories** — S'abonner aux flux de sécurité (GitHub
   Advisory, NVD).

```bash
# Audit des dépendances
npm audit --production          # Node.js
pip audit                       # Python
dotnet list package --vulnerable # .NET
bundle audit                    # Ruby
```

---

## A07:2021 — Identification and Authentication Failures

**Description :** Failles dans l'authentification : mots de passe faibles
autorisés, credential stuffing, session fixation, absence de MFA.

**Impact :** Prise de contrôle de comptes, usurpation d'identité.

### Contre-mesures

1. **MFA** — Implémenter l'authentification multi-facteurs, surtout pour les
   opérations sensibles.
2. **Politique de mots de passe** — Minimum 8 caractères, vérifier contre les
   listes de mots de passe compromis (Have I Been Pwned).
3. **Rate limiting** — Limiter les tentatives de connexion (ex: 5 tentatives
   puis lockout temporaire).
4. **Session management** — Tokens sécurisés, expiration, invalidation à la
   déconnexion.
5. **Ne pas exposer l'existence du compte** — Utiliser des messages d'erreur
   génériques ("identifiants invalides").

```javascript
// ✅ BON : Rate limiting sur le login
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,                    // 5 tentatives
  message: 'Trop de tentatives, réessayez dans 15 minutes',
  standardHeaders: true,
  legacyHeaders: false,
});
app.post('/auth/login', loginLimiter, loginHandler);

// ✅ BON : Message d'erreur générique
res.status(401).json({
  error: 'Identifiants invalides' // Ne pas dire "utilisateur introuvable"
});
```

---

## A08:2021 — Software and Data Integrity Failures

**Description :** Défauts liés à l'intégrité du code et de l'infrastructure :
mises à jour non vérifiées, pipelines CI/CD non sécurisés, désérialisation non
sécurisée.

**Impact :** Exécution de code malveillant, compromission de la supply chain.

### Contre-mesures

1. **Vérifier les signatures** — Valider les signatures numériques des packages
   et mises à jour.
2. **Sécuriser le pipeline CI/CD** — Contrôle d'accès strict, séparation des
   environnements, revue de code obligatoire.
3. **Intégrité des dépendances** — Utiliser les sous-resource integrity (SRI)
   pour les CDN, vérifier les checksums.
4. **Éviter la désérialisation non sécurisée** — Ne pas désérialiser de données
   non fiables, ou utiliser des formats simples (JSON vs. pickle/serialize).
5. **Lockfile et reproducibilité** — S'assurer que les builds sont reproductibles.

---

## A09:2021 — Security Logging and Monitoring Failures

**Description :** Insuffisance de la journalisation, de la détection et de la
réponse aux incidents. Sans logs et monitoring adéquats, les attaques restent
indétectées.

**Impact :** Détection tardive des breaches, impossibilité d'analyse forensique,
non-conformité.

### Contre-mesures

1. **Logger les événements de sécurité** — Connexions (succès/échec), accès
   aux données sensibles, modifications de permissions, erreurs d'autorisation.
2. **Format structuré** — Utiliser un format de log structuré (JSON) avec
   timestamp, user ID, IP, action.
3. **Centraliser les logs** — Envoyer les logs vers un SIEM ou une solution
   centralisée.
4. **Ne pas logger de données sensibles** — Jamais de mots de passe, tokens,
   numéros de carte dans les logs.
5. **Alertes automatiques** — Configurer des alertes sur les patterns anormaux
   (brute force, injection attempts, etc.).

```javascript
// ✅ BON : Log de sécurité structuré
const securityLog = {
  timestamp: new Date().toISOString(),
  event: 'LOGIN_FAILED',
  userId: attemptedUserId,
  ip: req.ip,
  userAgent: req.headers['user-agent'],
  details: 'Invalid credentials',
  // ❌ NE PAS inclure : password, token, etc.
};
logger.warn(securityLog);
```

---

## A10:2021 — Server-Side Request Forgery (SSRF)

**Description :** L'application récupère une ressource distante à partir d'une
URL fournie par l'utilisateur sans validation suffisante, permettant à un
attaquant d'atteindre des services internes.

**Impact :** Accès aux services internes (metadata cloud, bases de données
internes), exfiltration de données.

### Contre-mesures

1. **Whitelist d'URLs/domaines** — N'autoriser que les domaines et protocoles
   explicitement nécessaires.
2. **Bloquer les réseaux internes** — Filtrer les requêtes vers 127.0.0.1,
   169.254.x.x, 10.x.x.x, 172.16-31.x.x, 192.168.x.x.
3. **Pas de redirections** — Désactiver ou limiter le suivi de redirections HTTP.
4. **Segmentation réseau** — Isoler les services de récupération d'URLs.
5. **Valider le type de réponse** — Vérifier que la réponse correspond au type
   attendu (image, JSON, etc.).

```python
# ✅ BON : Validation d'URL avec whitelist
import ipaddress
from urllib.parse import urlparse

ALLOWED_DOMAINS = {'api.example.com', 'cdn.example.com'}
BLOCKED_NETWORKS = [
    ipaddress.ip_network('127.0.0.0/8'),
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('169.254.0.0/16'),
]

def validate_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https'):
        return False
    if parsed.hostname not in ALLOWED_DOMAINS:
        return False
    # Résoudre et vérifier l'IP
    resolved_ip = ipaddress.ip_address(socket.gethostbyname(parsed.hostname))
    for network in BLOCKED_NETWORKS:
        if resolved_ip in network:
            return False
    return True
```


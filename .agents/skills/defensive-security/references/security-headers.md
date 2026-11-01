# Headers de sécurité HTTP — Référence complète

Configuration recommandée des headers HTTP de sécurité pour les applications
web.

---

## Configuration complète recommandée (copier-coller)

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self';
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Resource-Policy: same-origin
X-XSS-Protection: 0
```

---

## Détail de chaque header

### 1. Strict-Transport-Security (HSTS)

**Objectif :** Force les connexions HTTPS uniquement. Empêche les attaques de
SSL-stripping et les downgrades MITM.

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

| Directive | Explication |
|-----------|------------|
| `max-age=31536000` | Durée de validité : 1 an |
| `includeSubDomains` | Appliqué à tous les sous-domaines |
| `preload` | Demande l'inclusion dans la liste preload des navigateurs |

> ⚠️ **Attention :** Avant d'activer `includeSubDomains`, s'assurer que TOUS les
> sous-domaines supportent HTTPS.

---

### 2. Content-Security-Policy (CSP)

**Objectif :** Whitelist contrôlant quelles ressources peuvent être chargées.
Mitige XSS, injection de données, clickjacking.

#### Configuration restrictive (recommandée)

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self';
```

#### Configuration avec nonce (pour les scripts inline nécessaires)

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{RANDOM}'; style-src 'self' 'nonce-{RANDOM}'; object-src 'none';
```

#### Directives clés

| Directive | Usage | Valeur recommandée |
|-----------|-------|-------------------|
| `default-src` | Fallback pour toutes les directives | `'self'` |
| `script-src` | Sources de scripts autorisées | `'self'` (pas de `'unsafe-inline'` ni `'unsafe-eval'`) |
| `style-src` | Sources de CSS autorisées | `'self'` |
| `img-src` | Sources d'images autorisées | `'self' data:` (si images base64 nécessaires) |
| `object-src` | Sources de plugins (Flash, etc.) | `'none'` |
| `frame-ancestors` | Qui peut embarquer la page en iframe | `'self'` ou `'none'` |
| `base-uri` | Restreint la balise `<base>` | `'self'` |
| `form-action` | Destinations des formulaires | `'self'` |
| `upgrade-insecure-requests` | Upgrade les requêtes HTTP vers HTTPS | (pas de valeur) |
| `report-uri` / `report-to` | Endpoint de reporting CSP | URL de votre collecteur |

> 💡 **Conseil :** Commencer en mode `Content-Security-Policy-Report-Only` pour
> identifier les violations avant de bloquer.

---

### 3. X-Frame-Options

**Objectif :** Empêche le clickjacking en contrôlant l'embedding en iframe.

```
X-Frame-Options: DENY
```

| Valeur | Effet |
|--------|-------|
| `DENY` | Interdit tout embedding en iframe |
| `SAMEORIGIN` | Autorise l'embedding depuis la même origine |

> 📝 Supplanté par `CSP frame-ancestors` dans les navigateurs modernes. Utiliser
> les deux pour la rétrocompatibilité.

---

### 4. X-Content-Type-Options

**Objectif :** Empêche le MIME-sniffing. Oblige le navigateur à respecter le
Content-Type déclaré.

```
X-Content-Type-Options: nosniff
```

---

### 5. Referrer-Policy

**Objectif :** Contrôle les informations de referrer transmises lors de la
navigation.

```
Referrer-Policy: strict-origin-when-cross-origin
```

| Valeur | Comportement |
|--------|-------------|
| `no-referrer` | Aucun referrer envoyé |
| `same-origin` | Referrer complet uniquement pour la même origine |
| `strict-origin` | Envoie uniquement l'origine (pas le path) |
| `strict-origin-when-cross-origin` | Path complet pour same-origin, origine seule pour cross-origin |

---

### 6. Permissions-Policy

**Objectif :** Contrôle quelles APIs/fonctionnalités du navigateur sont
accessibles (caméra, micro, géolocalisation, paiement).

```
Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()
```

> Parenthèses vides `()` = fonctionnalité désactivée globalement.
> `(self)` = autorisé pour le même domaine uniquement.

---

### 7. Cross-Origin-Opener-Policy (COOP)

**Objectif :** Isole le contexte de navigation pour empêcher les attaques
cross-origin (Spectre, side-channel).

```
Cross-Origin-Opener-Policy: same-origin
```

---

### 8. Cross-Origin-Embedder-Policy (COEP)

**Objectif :** Requiert que les ressources accordent explicitement la permission
d'être chargées.

```
Cross-Origin-Embedder-Policy: require-corp
```

---

### 9. Cross-Origin-Resource-Policy (CORP)

**Objectif :** Empêche d'autres origines de lire vos ressources.

```
Cross-Origin-Resource-Policy: same-origin
```

---

## Implémentation par framework

### Express.js (Node.js)

```javascript
const helmet = require('helmet');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'"],
      imgSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameAncestors: ["'self'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginEmbedderPolicy: { policy: 'require-corp' },
  crossOriginResourcePolicy: { policy: 'same-origin' },
}));
```

### Django (Python)

```python
# settings.py
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'
SECURE_CROSS_ORIGIN_OPENER_POLICY = 'same-origin'

# CSP via django-csp
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'",)
CSP_IMG_SRC = ("'self'",)
CSP_OBJECT_SRC = ("'none'",)
CSP_FRAME_ANCESTORS = ("'self'",)
CSP_BASE_URI = ("'self'",)
CSP_FORM_ACTION = ("'self'",)
```

### Spring Boot (Java)

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.headers(headers -> headers
            .httpStrictTransportSecurity(hsts -> hsts
                .maxAgeInSeconds(31536000)
                .includeSubDomains(true)
                .preload(true))
            .contentSecurityPolicy(csp -> csp
                .policyDirectives("default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'self'"))
            .frameOptions(frame -> frame.deny())
            .contentTypeOptions(Customizer.withDefaults())
            .referrerPolicy(referrer -> referrer
                .policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
            .crossOriginOpenerPolicy(coop -> coop.policy(CrossOriginOpenerPolicyHeaderWriter.CrossOriginOpenerPolicy.SAME_ORIGIN))
        );
        return http.build();
    }
}
```

### Nginx

```nginx
# Ajouter dans le bloc server {}
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; object-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self';" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), camera=(), microphone=(), payment=()" always;
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;
add_header Cross-Origin-Resource-Policy "same-origin" always;
add_header X-XSS-Protection "0" always;
```


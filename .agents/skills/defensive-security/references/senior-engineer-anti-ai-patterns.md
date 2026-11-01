# Référentiel Senior Software Engineer : Éradication des Failles & Anti-Patterns IA

Ce document définit les standards d'ingénierie logicielle avancés (**Staff / Senior Software Engineer**) à appliquer obligatoirement pour éliminer les failles récurrentes, les raccourcis paresseux et les patterns déficients typiquement produits par les modèles d'intelligence artificielle.

---

## 📋 Table des matières

1. [Matrice des Failles de Sécurité IA vs Rigueur Senior](#1-matrice-des-failles-de-sécurité-ia-vs-rigueur-senior)
2. [Typage Stricte & Éradication de l'Évasion de Types](#2-typage-stricte--éradication-de-lévasion-de-types)
3. [Gestion Robuste des Erreurs & Zéro Panic](#3-gestion-robuste-des-erreurs--zéro-panic)
4. [Cycle de Vie Asynchrone, Concurrence & Fuites de Mémoire](#4-cycle-de-vie-asynchrone-concurrence--fuites-de-mémoire)
5. [Architecture Modulaire vs Monolithes "God Files"](#5-architecture-modulaire-vs-monolithes-god-files)
6. [Checklist d'Auto-Revue Senior](#6-checklist-dauto-revue-senior)

---

## 1. Matrice des Failles de Sécurité IA vs Rigueur Senior

| Vulnérabilité / Pattern | ❌ Ce que produit typiquement une IA (Anti-Pattern) | ✅ Ce qu'exige un Ingénieur Senior (Standard Robuste) |
| :--- | :--- | :--- |
| **Secrets & Placeholders** (CWE-798, CWE-312) | Insère `"TODO_REPLACE_WITH_REAL_KEY"`, `"secret_token_placeholder"`, `"mock_jwt"` ou des clés codées en dur dans les bundles. | Charge strictement depuis `.env` validé au démarrage par Zod/Pydantic/Config crate. Aucun placeholder en production. RAM effacée avec `zeroize`. |
| **Filtrage IP & SSRF** (CWE-918) | Filtre textuel naïf : `if url.contains("10.")` ou `url.startswith("http://192")` (bloque les domaines légitimes comme `univ-paris10.fr` et laisse passer les bypasses). | Résolution DNS puis parsing strict `std::net::IpAddr`. Contrôle `ip.is_loopback()`, `ip.is_private()`, `ip.is_link_local()`, et blocage des adresses de métadonnées cloud (`169.254.169.254`). |
| **Comparaison de Secrets** (CWE-208) | Comparaison directe par égalité `if (userHash === storedHash)` ou `user_pin == stored_pin`, vulnérable aux attaques par canal auxiliaire temporel (Timing Attacks). | Comparaison en temps constant (**Constant-Time**) : XOR bit-à-bit sans sortie prématurée (`crypto/subtle.ConstantTimeCompare`, crate Rust `subtle::ConstantTimeEq`, Web Crypto). |
| **Gestion des Pannes & IA** (CWE-636) | **Fail-Open** paresseux : `try { ... } catch { return true; }` pour éviter que l'application ne bloque lors d'un test. | **Fail-Secure** strict : en cas de timeout, d'exception ou d'absence de capteur/modèle, rejeter l'accès (`return { allowed: false, reason: "SYSTEM_UNAVAILABLE" }`). |
| **Génération d'Identifiants & Aléa** (CWE-338) | `Math.random().toString(36)` pour générer des tokens, nonces, identifiants de session ou codes de vérification. | CSPRNG certifié de l'OS exclusivement : `crypto.getRandomValues()`, Rust `rand::rngs::OsRng`, Python `secrets.token_urlsafe()`. |
| **Divulgation d'Informations** (CWE-209) | `res.status(500).json({ error: err.stack, path: file_path })` renvoyant le chemin Windows `C:\Users\username\...` ou la requête SQL. | Masquage complet : chemin relatif normalisé (`evidence/attempt-1/cam.webm`), message d'erreur générique typé (`INTERNAL_SERVER_ERROR`), journalisation interne sécurisée. |
| **Contrôle d'Accès & PIN** (CWE-307) | Vérification côté client sans limite de tentatives, ou absence de verrouillage dans les IPC natifs (Tauri/Electron). | Double barrière : Rate-limiting en mémoire côté backend/Rust (Sliding Window, ex: max 3 tentatives par 60s) + désactivation temporisée de l'UI. |

---

## 2. Typage Stricte & Éradication de l'Évasion de Types

### L'Anti-Pattern IA :
L'IA a tendance à utiliser `any`, des casts forcés `as unknown as Type`, des `@ts-ignore` ou à désérialiser du JSON sans validation :
```typescript
// ❌ ANTI-PATTERN IA : Évasion de type et absence de validation
async function fetchUserData(id: string): Promise<any> {
  const res = await fetch(`/api/users/${id}`);
  const data = await res.json(); // Données non vérifiées !
  return data as any;
}
```

### Le Standard Senior :
Validation de schéma au runtime (Zod, ArkType ou TypeBox) et typage nominal / discriminant :
```typescript
// ✅ STANDARD SENIOR : Validation au runtime avec Zod + Types Dérivés
import { z } from "zod";

export const UserSchema = z.object({
  id: z.string().uuid(),
  username: z.string().min(3).max(50).regex(/^[a-zA-Z0-9_-]+$/),
  email: z.string().email(),
  role: z.enum(["student", "proctor", "admin"]),
  lastLogin: z.string().datetime().optional(),
});

export type User = z.infer<typeof UserSchema>;

export async function fetchUserData(id: string, signal?: AbortSignal): Promise<User> {
  const res = await fetch(`/api/users/${encodeURIComponent(id)}`, { signal });
  if (!res.ok) {
    throw new Error(`HTTP_${res.status}: Impossible de récupérer l'utilisateur`);
  }
  const raw = await res.json();
  const parsed = UserSchema.safeParse(raw);
  if (!parsed.success) {
    console.error("[Schema Violation]", parsed.error.format());
    throw new Error("INVALID_PAYLOAD: Réponse serveur non conforme au schéma");
  }
  return parsed.data;
}
```

---

## 3. Gestion Robuste des Erreurs & Zéro Panic

### L'Anti-Pattern IA :
- En Rust : utilisation compulsive de `.unwrap()` et `.expect("failed")` qui provoquent des crashs complets (Panics / DoS) en production.
- En TypeScript / JS : blocs `catch (e) {}` vides ou simples `console.log(e)` sans propagation ni remédiation.

```rust
// ❌ ANTI-PATTERN IA (Rust) : Panique assurée en production si le fichier n'existe pas
let content = std::fs::read_to_string(&path).unwrap();
let json: Value = serde_json::from_str(&content).expect("JSON corrupted");
```

### Le Standard Senior :
Typage exhaustif des erreurs via `thiserror` (librairie/crate) ou `anyhow::Context` (binaire/app) :
```rust
// ✅ STANDARD SENIOR (Rust) : Erreurs typées avec thiserror et gestion explicite
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("Fichier de configuration introuvable : {0}")]
    NotFound(String),
    #[error("Erreur de lecture I/O : {0}")]
    Io(#[from] std::io::Error),
    #[error("Format JSON invalide dans la configuration : {0}")]
    ParseError(#[from] serde_json::Error),
}

pub fn load_config(path: &std::path::Path) -> Result<AppConfig, ConfigError> {
    if !path.exists() {
        return Err(ConfigError::NotFound(path.display().to_string()));
    }
    let content = std::fs::read_to_string(path)?;
    let config: AppConfig = serde_json::from_str(&content)?;
    Ok(config)
}
```

---

## 4. Cycle de Vie Asynchrone, Concurrence & Fuites de Mémoire

### L'Anti-Pattern IA :
- Lancer des `fetch` ou des timers dans un `useEffect` sans `AbortController` ni cleanup function, provoquant des *Race Conditions* et des *Memory Leaks* lors du démontage du composant.
- Accumuler des écouteurs d'événements sans jamais les détacher (`window.addEventListener` sans `removeEventListener`).

```typescript
// ❌ ANTI-PATTERN IA : Race conditions et fuites mémoire garanties
useEffect(() => {
  fetch(`/api/search?q=${query}`)
    .then(r => r.json())
    .then(data => setResults(data)); // Si query change vite, les réponses arrivent dans le désordre !
}, [query]);
```

### Le Standard Senior :
Annulation systématique via `AbortController` et nettoyage rigoureux :
```typescript
// ✅ STANDARD SENIOR : AbortController et nettoyage complet
useEffect(() => {
  const controller = new AbortController();
  
  async function performSearch() {
    try {
      const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, {
        signal: controller.signal
      });
      if (!res.ok) throw new Error("Search failed");
      const data = await res.json();
      setResults(data);
    } catch (err: unknown) {
      if (err instanceof Error && err.name === "AbortError") {
        return; // Requête annulée normalement, ignorer
      }
      setError("Échec de la recherche");
    }
  }

  performSearch();

  return () => {
    controller.abort(); // Annule la requête en vol si le composant se démonte ou si query change
  };
}, [query]);
```

---

## 5. Architecture Modulaire vs Monolithes "God Files"

### L'Anti-Pattern IA :
Créer un fichier unique de 1500 lignes (ex: `App.tsx` ou `main.rs`) qui contient :
- Les états React globaux
- Les appels réseau bruts
- Les calculs de sécurité et hashs
- Les composants d'UI JSX imbriqués
- Les styles CSS inline

### Le Standard Senior :
Découpage strict en couches et responsabilité unique (*Single Responsibility Principle*) :
```
src/
├── domain/               # Entités pures et règles métier (indépendant du framework)
│   ├── models/           # Types, Value Objects, Schemas Zod
│   └── services/         # Algorithmes métier, calculs canoniques
├── infrastructure/       # Adaptateurs externes
│   ├── api/              # Clients HTTP avec retry et timeout
│   ├── storage/          # Wrapper sessionStorage / Keychain
│   └── crypto/           # Fonctions cryptographiques Web Crypto / Subtle
├── presentation/         # Couche UI
│   ├── components/       # Composants atomiques réutilisables (Button, Input, Card)
│   ├── features/         # Vues et flux métier (KioskView, ExamPortal)
│   └── hooks/            # Hooks personnalisés encapsulant l'état
```

---

## 6. Checklist d'Auto-Revue Senior

Avant de soumettre du code, poser les 7 questions suivantes :

1. **Robustesse aux entrées adverses :** Que se passe-t-il si l'entrée utilisateur est un payload vide, une chaîne Unicode de 100 000 caractères, ou un caractère nul `\0` ?
2. **Gestion de panne Fail-Secure :** Si le réseau se coupe au milieu de la requête, le système est-il dans un état sécurisé et prévisible ?
3. **Zéro fuite de mémoire :** Tous les timers (`setInterval`), abonnements d'événements et requêtes asynchrones sont-ils annulés lors du démontage ?
4. **Zéro typage laxiste :** Y a-t-il le moindre `any`, `@ts-ignore` ou `as unknown as T` ? (Si oui, le supprimer et modéliser le type exact).
5. **Résistance au Timing Attack :** Toutes les comparaisons de tokens/hashs/PIN sont-elles en temps constant ?
6. **Masquage d'erreurs :** Aucun chemin local (`C:\...`) ni message brut de base de données n'est-il transmis au client ?
7. **Performance & Efficacité :** Y a-t-il des re-renders inutiles, des boucles `O(N²)` évitables, ou des blocages du fil principal (main thread) ?

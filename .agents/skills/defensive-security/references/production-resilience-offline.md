# Résilience Industrielle & Offline-First : Code de Production vs Académique

Ce guide détaille les patterns d'ingénierie de production (**Staff / Senior Systems Engineer**) permettant de rendre une application invulnérable aux pannes réseau, aux coupures imprévues, aux clics intempestifs et aux pertes de données locales.

---

## 📋 Table des matières

1. [Matrice : Code Académique vs Résilience Industrielle](#1-matrice--code-académique-vs-résilience-industrielle)
2. [Timeouts Stricts Universels & Annulation](#2-timeouts-stricts-universels--annulation)
3. [Retry Exponentiel avec Gigue (Exponential Backoff with Jitter)](#3-retry-exponentiel-avec-gigue)
4. [Idempotence & Protection Anti-Double Soumission (Double-Submit Guard)](#4-idempotence--protection-anti-double-soumission)
5. [File d'Attente Locale & Mode Hors-Ligne (Offline Buffer)](#5-file-dattente-locale--mode-hors-ligne)
6. [Bilan de Santé Système Pré-Vol (Diagnostic 1-Clic)](#6-bilan-de-santé-système-pré-vol)
7. [Versioning des Données Locales & Migrations Sans Perte](#7-versioning-des-données-locales--migrations-sans-perte)
8. [Hygiène Absolue des Logs en Production (Zero Console Noise)](#8-hygiène-absolue-des-logs-en-production)

---

## 1. Matrice : Code Académique vs Résilience Industrielle

| Défi Réel | ❌ Code Académique / Débutant | ✅ Code de Production Résilient |
| :--- | :--- | :--- |
| **Micro-coupure Wi-Fi** | Requête `fetch()` bloquée indéfiniment, interface figée (*freeze*), crash silencieux. | Timeout strict (ex: 8s), passage immédiat en tampon hors-ligne local, retry automatique avec gigue. |
| **Utilisateur clique 3 fois vite** | 3 requêtes partent au serveur, écrasant la base de données ou créant des doublons. | Verrouillage instantané du bouton au 1er clic + clé d'idempotence UUID transmise au serveur. |
| **Mise à jour du logiciel** | `localStorage.clear()` efface le travail de l'utilisateur pour "repartir sur du propre". | Migrations séquentielles de schéma (`schemaVersion`) préservant l'intégralité des données locales. |
| **Console du navigateur** | Polluée de dizaines de `console.log(data)` exposant parfois des emails ou tokens. | Suppression automatique des logs à la compilation (`drop_console`), logger structuré avec masquage PII. |
| **Début d'épreuve / d'action** | L'utilisateur découvre au milieu de l'action que son micro ou sa caméra ne marche pas. | Sas de pré-vol automatique testant les capteurs et le réseau en 1 clic avant de commencer. |

---

## 2. Timeouts Stricts Universels & Annulation

Tout appel asynchrone sortant (HTTP, WebSocket, IPC natif) doit être encadré par un délai d'attente maximal :

```typescript
/**
 * Wrapper HTTP résilient avec timeout obligatoire et annulation.
 */
export async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs: number = 8000
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: options.signal ?? controller.signal,
    });
    return response;
  } catch (err: unknown) {
    if (err instanceof Error && err.name === "AbortError") {
      throw new Error(`NETWORK_TIMEOUT: La requête vers ${url} a dépassé ${timeoutMs}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}
```

---

## 3. Retry Exponentiel avec Gigue

Pour éviter qu'un millier d'étudiants ou d'utilisateurs ne réessaient tous à la même seconde et saturent le serveur (*Thundering Herd Problem*) :

```typescript
/**
 * Exécute une opération avec retry exponentiel et décalage aléatoire (Jitter).
 */
export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelayMs: number = 1000
): Promise<T> {
  let attempt = 0;
  while (attempt < maxRetries) {
    try {
      return await fn();
    } catch (error) {
      attempt++;
      if (attempt >= maxRetries) throw error;
      
      // Calcul du délai exponentiel + Jitter aléatoire CSPRNG
      const exponentialDelay = baseDelayMs * Math.pow(2, attempt);
      const randomJitter = Math.floor(Math.random() * 500); // Bruit aléatoire 0-500ms
      const delay = exponentialDelay + randomJitter;
      
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  throw new Error("RETRY_EXHAUSTED");
}
```

---

## 4. Idempotence & Protection Anti-Double Soumission

### Au Niveau UI (Bouton Auto-Verrouillant) :
```tsx
export function SubmitButton({
  isSubmitting,
  onClick,
  label = "Valider et soumettre",
  loadingLabel = "Enregistrement sécurisé...",
}: {
  isSubmitting: boolean;
  onClick: () => Promise<void>;
  label?: string;
  loadingLabel?: string;
}) {
  return (
    <button
      type="button"
      disabled={isSubmitting}
      onClick={onClick}
      className="relative px-5 py-2.5 rounded-lg font-semibold text-sm bg-emerald-600 hover:bg-emerald-500 disabled:bg-zinc-800 disabled:text-zinc-500 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:cursor-not-allowed"
    >
      {isSubmitting && <SpinnerIcon className="w-4 h-4 animate-spin text-zinc-400" />}
      <span>{isSubmitting ? loadingLabel : label}</span>
    </button>
  );
}
```

### Au Niveau API (Clé d'Idempotence) :
Chaque requête sensible de modification transmet un en-tête `Idempotency-Key: <UUID v4>` pour garantir qu'un doublon réseau n'exécute pas deux fois l'action côté backend.

---

## 5. File d'Attente Locale & Mode Hors-Ligne (Offline Buffer)

Si la connexion s'interrompt pendant la saisie d'un formulaire ou d'une épreuve :
1. Stocker les données immédiatement dans un tampon chiffré en mémoire (`sessionStorage` ou `IndexedDB`).
2. Indiquer discrètement à l'utilisateur : *« Sauvegardé en mémoire locale (18:54). Synchronisation dès reconnexion. »*
3. Écouter l'événement `window.addEventListener('online', syncBuffer)`.
4. Dès le retour du réseau, vider la file d'attente vers le serveur et notifier l'utilisateur par un toast vert : *« Vos données ont été synchronisées avec succès. »*

---

## 6. Bilan de Santé Système Pré-Vol (Diagnostic 1-Clic)

Un composant de pré-vol vérifie avant l'action principale :
- **Connexion réseau :** Mesure de la latence (ping vers serveur < 300ms = Vert, < 800ms = Orange, > 800ms = Rouge).
- **Capteurs matériels :** Disponibilité active de la webcam et du micro.
- **Batterie :** Niveau de batterie > 20% ou appareil sur secteur (via `navigator.getBattery()`).
- **Plein écran & Moniteur unique :** Détection d'écrans externes multiples.

---

## 7. Versioning des Données Locales & Migrations Sans Perte

Ne jamais écraser brutalement les structures de données en local :

```typescript
interface StoredDataV1 {
  version: 1;
  answers: Record<string, string>;
}

interface StoredDataV2 {
  version: 2;
  answers: Record<string, { value: string; timestamp: number }>;
}

export function migrateData(raw: unknown): StoredDataV2 {
  const data = raw as { version?: number };
  if (!data || typeof data !== "object") {
    return { version: 2, answers: {} };
  }

  // Migration progressive de la version 1 vers la version 2
  if (data.version === 1) {
    const v1 = data as StoredDataV1;
    const migratedAnswers: StoredDataV2["answers"] = {};
    for (const [key, val] of Object.entries(v1.answers)) {
      migratedAnswers[key] = { value: val, timestamp: Date.now() };
    }
    return { version: 2, answers: migratedAnswers };
  }

  return data as StoredDataV2;
}
```

---

## 8. Hygiène Absolue des Logs en Production (Zero Console Noise)

En production, l'inspecteur du navigateur ne doit afficher aucun log de développement.

### Configuration du Bundler (Vite / Rollup / esbuild) :
```typescript
// vite.config.ts
export default defineConfig({
  esbuild: {
    // Supprime tous les console.log et console.debug en production
    drop: process.env.NODE_ENV === "production" ? ["console", "debugger"] : [],
  },
});
```

### Masquage des Données Personnelles (PII Redaction) :
Tout message de log interne doit automatiquement masquer les emails et jetons :
`user@domain.fr` → `u***@domain.fr`  
`token_abc123xyz` → `tok***[REDACTED]`

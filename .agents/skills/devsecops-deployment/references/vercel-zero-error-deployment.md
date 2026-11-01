# 🌐 Guide de Déploiement Cloud Vercel Zéro-Erreur

Ce guide définit les standards d'ingénierie et de configuration DevSecOps pour garantir un déploiement 100% sans erreur sur **Vercel** (et plateformes cloud similaires comme Netlify ou Cloudflare Pages) pour toute application web moderne (Vite, React, Vue, Svelte, SPAs).

---

## 🛑 Les 5 Causes Majeures d'Erreurs sur Vercel

### 1. Conflit de Chemin Relatif (`base: "./"`) et Rewrites SPA
* **Symptôme :** Erreur `Uncaught SyntaxError: Unexpected token '<'` et `MIME type ('text/html') is not executable`. Page blanche lors d'un rafraîchissement sur une sous-route (`/docs`, `/app`).
* **Mécanisme :** Si Vite génère `<script src="./assets/index.js">`, un accès à `https://domaine.vercel.app/docs` demande `./assets/index.js` résolu en `/docs/assets/index.js`. La règle de rewrite globale `/(.*) -> /index.html` intercepte la requête et renvoie du HTML au lieu du JavaScript !
* **Solution :** Configurer `base: "/"` (ou chemin absolu) dans `vite.config.ts` et utiliser la règle standard Vercel `/(.*) -> /index.html` (Vercel donne la priorité absolue aux fichiers physiques présents dans `dist/`).

### 2. Rewrites Brutes ou Regex Incompatibles avec path-to-regexp
* **Symptôme :** Erreur de parsing Vercel `Could not parse rewrite source` ou échec de build.
* **Mécanisme :** Le moteur de routage Vercel (`path-to-regexp`) ne supporte pas les assertions négatives complexes `(?!...)`.
* **Solution :** Utiliser la règle officielle standard :
  ```json
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
  ```
  Vercel sert **automatiquement les fichiers statiques en priorité** s'ils existent dans le dossier `dist/`. Tant que le `base path` dans `vite.config.ts` pointe vers `/assets/` (et non `./assets/`), les scripts et styles sont servis directement sans jamais déclencher la redirection SPA.

### 3. Blocage des Permissions Matérielles (Webcam, Micro, Plein Écran)
* **Symptôme :** WebRTC ou `navigator.mediaDevices.getUserMedia()` refusé ou inaccessible dans le navigateur sur le domaine Vercel.
* **Solution :** Injecter l'en-tête `Permissions-Policy` dans `vercel.json` :
  ```json
  { "key": "Permissions-Policy", "value": "camera=*, microphone=*, display-capture=*, fullscreen=*" }
  ```

### 4. Blocage Content-Security-Policy (CSP) & WebAssembly
* **Symptôme :** MediaPipe ou modules WASM bloqués avec `Refused to compile or instantiate WebAssembly module`.
* **Solution :** Autoriser les CDN officiels et `wasm-unsafe-eval` dans les sources autorisées.

### 5. Présence du package `vercel` dans `devDependencies`
* **Symptôme :** Délais de build excessifs, timeouts `npm install` ou échecs de build sur Vercel.
* **Solution :** Ne jamais installer `vercel` dans `package.json`. L'environnement Vercel fournit nativement sa propre CLI.

### 6. Branches Parasites Orphelines (ex: `gh-pages`) déclenchant des Builds Échoués
* **Symptôme :** Vercel envoie une alerte "Deployment Failed" ou affiche un statut rouge alors même que la branche `main` fonctionne à 100%.
* **Mécanisme :** Les workflows CI (comme GitHub Pages via `peaceiris/actions-gh-pages`) créent souvent une branche orpheline (`gh-pages`) ne contenant que des fichiers statiques compilés (`dist/`), **sans `package.json` ni `vercel.json`**. Vercel détecte automatiquement le push sur cette branche, tente d'exécuter `npm run build`, et échoue immédiatement avec `ENOENT: package.json non trouvé`.
* **Solution :** 
  1. Configurer `ignoreCommand` dans `vercel.json` pour ignorer toute branche non-production :
     ```json
     "ignoreCommand": "if [ -z \"$VERCEL_GIT_COMMIT_REF\" ] || [ \"$VERCEL_GIT_COMMIT_REF\" = \"main\" ]; then exit 1; else exit 0; fi"
     ```
  2. Migrer GitHub Pages vers le mécanisme officiel `actions/deploy-pages@v4` (qui n'utilise aucune branche `gh-pages` orpheline).

---

## 🛠️ Le Modèle `vercel.json` Idéal et Durci

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": "vite",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "ignoreCommand": "if [ -z \"$VERCEL_GIT_COMMIT_REF\" ] || [ \"$VERCEL_GIT_COMMIT_REF\" = \"main\" ]; then exit 1; else exit 0; fi",
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "SAMEORIGIN" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "Permissions-Policy", "value": "camera=*, microphone=*, display-capture=*, fullscreen=*" }
      ]
    },
    {
      "source": "/assets/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

---

## ⚙️ Configuration Multi-Plateformes (Vite `vite.config.ts`)

Pour qu'un même code se déploie sans erreur sur **Vercel**, **Netlify**, **Tauri (Desktop)** et **GitHub Pages** :

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(() => ({
  plugins: [react()],
  // Base path dynamique : "/" pour Vercel, Netlify, Tauri ; sous-dossier uniquement pour GitHub Pages
  base: process.env.VITE_BASE_PATH || (process.env.GITHUB_PAGES === "true" ? "/MonProjet/" : "/"),
}));
```

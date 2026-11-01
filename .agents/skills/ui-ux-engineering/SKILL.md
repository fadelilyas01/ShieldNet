---
name: ui-ux-engineering
description: >-
  Skill d'ingénierie UI/UX et de design de produits numériques professionnels (SaaS, Web, Mobile).
  À utiliser pour concevoir, implémenter ou auditer des interfaces utilisateur modernes,
  ergonomiques et professionnelles (inspirées de standards comme Stripe, Linear, Vercel, Apple HIG).
  Bannit les designs génériques typiques d'IA (dégradés violets criards, néons superflus, cartes flottantes sans hiérarchie)
  au profit d'une vraie rigueur d'ingénieur produit : système de design tokens (grille 8pt, palette sobre,
  échelle typographique stricte), états exhaustifs (loading skeletons, empty states, erreurs, focus accessible),
  ergonomie mobile native et conformité WCAG AA.
---

# 🎨 UI/UX Engineering & Modern Product Design Skill

Skill dédié à la conception et au développement d'interfaces utilisateur **professionnelles, sobres, fonctionnelles et élégantes**, éliminant tout artefact "brouillon" ou "gadget généré par IA".

---

## 📋 Table des matières

1. [Le Manifeste Anti-« AI Slop »](#le-manifeste-anti-ai-slop)
2. [Principes d'Ingénierie UI/UX Professionnelle](#principes-dingénierie-uiux-professionnelle)
3. [Système de Design & Tokens (Grille, Couleurs, Typographie)](#système-de-design--tokens)
4. [Micro-Animations & Rendu Fluide 60 FPS](#micro-animations--rendu-fluide-60-fps)
5. [Gestion Systématique des États (Les 5 États d'Interface)](#les-5-états-dinterface-obligatoires)
6. [UX Writing & Éradication du Jargon Technique](#ux-writing--éradication-du-jargon-technique)
7. [Guides de Référence Spécialisés](#guides-de-référence-spécialisés)
8. [Scripts d'Audit Ergonomique](#scripts-daudit-ergonomique)

---

## Le Manifeste Anti-« AI Slop »

Les interfaces générées par les modèles d'IA souffrent souvent de clichés visuels qui décrédibilisent une application professionnelle. Ce skill **interdit formellement** :

| ❌ Ce qui est INTERDIT (Clichés IA) | ✅ Ce qui est EXIGÉ (Ingénieur Produit Sérieux) |
| :--- | :--- |
| **Gradients violets/roses criards sur fond noir** sur chaque bouton et titre | Palette neutre raffinée (zinc/slate), couleur d'accent unique et intentionnelle |
| **Glows néons et ombres colorées démesurées** sans justification physique | Ombres douces, subtiles, étagées (`shadow-xs`, `shadow-sm`) et bordures fines (`border-border/50`) |
| **Cartes flottantes géantes avec padding incohérent** et coins ultra-arrondis uniformes | Grille stricte basée sur un pas de 4px / 8px, alignements rigoureux, densité d'information optimisée |
| **Absence d'états d'interaction** (aucun `:hover`, `:active`, `:focus-visible`) | Micro-interactions réactives, curseurs appropriés, indicateurs de focus visibles pour l'accessibilité |
| **Spinners isolés au milieu d'une page blanche** | Skeletons loaders reproduisant la forme exacte du contenu attendu |
| **Boutons avec icônes seules sans label textuel ni `aria-label`** | Accessibilité totale, tooltips au survol, raccourcis clavier affichés (`⌘K`) |
| **Logos simulés, emojis de substitution (`🎓`, `🌐`) ou icônes génériques** | **Vrais logos officiels vectoriels (SVG)**. Si manquant, obligation de télécharger l'asset officiel dans `public/logos/` |
| **Commentaires de code pollués d'emojis décoratifs (`🚀`, `💡`, `🔥`)** | Commentaires techniques sobres, descriptifs et professionnels (standard JSDoc / TSDoc / Rustdoc) sans emojis décoratifs |
| **Jargon technique anxiogène exposé à l'utilisateur** (Erreur 500, NullPointer, SHA-256 mismatch, Gateway Timeout) | **Messages en langage humain clair, empathique et orienté action** (répondre aux 3 questions : Que s'est-il passé ? Quel impact ? Que faire ?) |

---

## Principes d'Ingénierie UI/UX Professionnelle

1. **Hiérarchie Visuelle Implacable (Content-First) :**
   - L'utilisateur doit comprendre en moins de 3 secondes l'objectif principal de l'écran.
   - Ne jamais donner la même importance visuelle à deux boutons côte à côte (1 bouton primaire, les autres secondaires ou ghost/tertiary).
2. **Loi de Fitts & Cibles Tactiles :**
   - Sur mobile et tactile, la zone minimale cliquable est de **44x44 points / 48x48 dp**.
   - Placer les actions destructives à l'opposé des actions courantes pour éviter les clics accidentels.
3. **Consistance du Système de Design :**
   - Ne jamais utiliser de valeurs arbitraires (ex: `margin: 17px`, `color: #4a5b6c`). Toujours mapper sur les variables de design tokens (`var(--spacing-4)`, `bg-muted`).
4. **Logos Réels & Assets Vectoriels Officiels :**
   - Ne jamais utiliser d'emojis ou d'icônes génériques de librairies pour représenter des universités, ministères, entreprises ou logiciels tiers (Moodle, Google, etc.).
   - Télécharger et intégrer les véritables fichiers SVG officiels dans les assets locaux (`public/logos/`).
5. **Commentaires de Code Professionnels :**
   - Proscrire tout emoji décoratif dans les commentaires source. Documenter le *pourquoi* avec rigueur technique.
6. **Accessibilité (A11y - WCAG 2.2 AA) :**
   - Contraste de texte minimum de **4.5:1** pour le texte normal, **3:1** pour le texte large.
   - Navigation clavier intégrale (`Tab`, `Shift+Tab`, `Escape`, `Enter`).

---

## Système de Design & Tokens

### 1. La Grille 8pt (Spacing & Layout)
Toutes les marges, paddings, hauteurs et largeurs doivent être des multiples de 4 ou 8 :
- `4px` (space-1) : Espacement ultra-compact (icône + texte dans un tag/badge).
- `8px` (space-2) : Espacement interne compact (padding d'un bouton compact).
- `12px` (space-3) : Espacement de formulaire standard.
- `16px` (space-4) : Padding de carte de base, marge de section compacte.
- `24px` (space-6) : Espacement entre blocs majeurs.
- `32px / 48px` : Marges de mise en page (page layout).

### 2. Échelle Typographique Épurée
- **Font Stack :** Polices système ou sans-serif modernes à lisibilité maximale (*Inter, Geist, SF Pro, Segoe UI, Roboto*). Pour le code ou les chiffres financiers, polices monospace (*Geist Mono, JetBrains Mono*).
- **Échelle :**
  - **H1 (Page Title) :** `text-2xl` à `text-3xl font-semibold tracking-tight`
  - **H2 (Section) :** `text-xl font-semibold`
  - **H3 (Sub-section / Card title) :** `text-base font-medium`
  - **Body (Texte courant) :** `text-sm font-normal text-muted-foreground`
  - **Caption / Meta :** `text-xs text-muted-foreground font-mono`

---

## Micro-Animations & Rendu Fluide 60 FPS

Pour éviter l'effet "gadget" ou "lourdeur", les animations doivent être légères, discrètes et performantes :

1. **GPU-Accelerated Uniquement :**
   - Animer exclusivement `transform` (`translate3d`, `scale`, `rotate`) et `opacity`.
   - Bannir formellement l'animation de propriétés de mise en page (`width`, `height`, `margin`, `padding`, `top`, `left`) qui provoquent des saccades et des *layout shifts*.
2. **Courbes d'Inertie Réalistes :**
   - Utiliser des courbes bézier d'inertie physique fluides (`cubic-bezier(0.16, 1, 0.3, 1)` - standard Apple/Linear), jamais de transitions brutales ou de rebonds exagérés.
3. **Respect de l'Accessibilité Mouvement :**
   - Intégrer systématiquement `@media (prefers-reduced-motion: reduce)` pour neutraliser les animations pour les utilisateurs sensibles.
4. **Micro-effets Haut de Gamme :**
   - Lignes de balayage laser légères (Border Beam), auras d'ambiance diffuses très lentes (Aurora floats), spectres audio en CSS pur sans calcul JS continu.

---

## Les 5 États d'Interface Obligatoires

Pour chaque composant de données ou formulaire, concevoir et implémenter **systématiquement** les 5 états :

```
┌────────────────────────────────────────────────────────┐
│ 1. ÉTAT IDLE / DEFAULT    : Données affichées          │
│ 2. ÉTAT LOADING          : Skeleton loader adapté      │
│ 3. ÉTAT EMPTY            : Illustration sobre + CTA    │
│ 4. ÉTAT ERROR            : Message clair + bouton retry│
│ 5. ÉTAT PARTIAL / DIRTY  : Changements non enregistrés │
└────────────────────────────────────────────────────────┘
```

Consulter le guide complet : [États et Accessibilité](./references/accessibility-and-states.md)

---

## UX Writing & Éradication du Jargon Technique

Toute interface professionnelle doit parler le langage de l'utilisateur et éliminer le vocabulaire de développeur :

1. **La Règle des 3 Questions :** Tout message d'état ou d'erreur doit expliciter :
   - *Que s'est-il passé ?* (Explication simple et factuelle)
   - *Quel est l'impact ?* (Rassurer sur la sauvegarde des données)
   - *Que faire maintenant ?* (Action immédiate via bouton clair)
2. **Bannir les Termes Informatiques :** Ne jamais afficher de code HTTP (401, 404, 500, 504), d'acronymes (SHA-256, SSRF, CORS, IPC) ou de stack traces. Utiliser des termes simples : « Empreinte de sécurité », « Connexion ralentie », « Session expirée ».
3. **Micro-Copy Explicite des Boutons :** Remplacer les boutons vagues (« OK », « Soumettre ») par des actions précises (« Valider et transmettre ma copie », « Réactiver la caméra »).
4. **Protection Anti-Double Clic :** Tout bouton d'action sensible doit se désactiver immédiatement au premier clic avec un libellé d'attente rassurant (« Enregistrement sécurisé... »).

Consulter le guide complet : [UX Writing & Zéro Jargon](./references/ux-writing-zero-jargon.md)

---

## Guides de Référence Spécialisés

| Référence | Contenu |
|-----------|---------|
| [UX Writing & Zéro Jargon](./references/ux-writing-zero-jargon.md) | Éradication du jargon technique, règle des 3 questions, micro-copy rassurante des boutons |
| [Senior UI/UX & Anti-AI Slop](./references/senior-ui-ux-patterns.md) | Standard Senior Product Design, micro-animations GPU 60 FPS, accessibilité WCAG AA, 5 états d'interface |
| [Design Tokens & Typographie](./references/design-tokens-and-typography.md) | Échelles de couleurs, ratios de contraste, tokens CSS et Tailwind, typographie pro |
| [Composants Web Pro (Shadcn / Tailwind)](./references/component-patterns-web.md) | Data Tables avec tri/filtres, Navigation Shells, Modales, Command Palettes (`⌘K`), formulaires |
| [Composants Mobile Natifs](./references/component-patterns-mobile.md) | Safe Area, Bottom Sheets, Gestures, Retours Haptiques, Navigation Stack (Flutter, React Native, Swift, Kotlin) |
| [États d'Interface & Accessibilité](./references/accessibility-and-states.md) | Skeletons précis, Empty States engageants, conformité WCAG AA, focus rings visibles |

---

## Scripts d'Audit Ergonomique

| Script | Usage |
|--------|-------|
| [audit-ui.ps1](./scripts/audit-ui.ps1) | Scanne les fichiers front-end (React, Vue, HTML, Tailwind) pour détecter les antipatterns d'accessibilité, couleurs arbitraires, `z-index` démesurés et états manquants. |

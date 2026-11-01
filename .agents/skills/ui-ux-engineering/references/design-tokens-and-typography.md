# Design Tokens, Couleurs & Typographie — Référence

Ce document détaille les spécifications mathématiques et visuelles pour créer un système de design cohérent, sobre et haut de gamme.

---

## 📋 Table des matières

1. [La Règle des 60-30-10 (Équilibre Visuel)](#1-la-règle-des-60-30-10-équilibre-visuel)
2. [Système Sémantique de Couleurs (Dark & Light Mode)](#2-système-sémantique-de-couleurs-dark--light-mode)
3. [Configuration des Tokens CSS & Tailwind v4/v3](#3-configuration-des-tokens-css--tailwind-v4v3)
4. [Échelle Typographique & Rythme Vertical](#4-échelle-typographique--rythme-vertical)
5. [Rayons de Courbure (Border Radius) & Élévations (Ombres)](#5-rayons-de-courbure-border-radius--élévations-ombres)

---

## 1. La Règle des 60-30-10 (Équilibre Visuel)

Pour éviter la surcharge visuelle ou l'effet "sapin de Noël" :
* **60% (Couleur dominante neutre) :** Fond de page (`background`), surface des cartes (`card`). Généralement blanc cassé ou gris très clair en mode clair (`#FAFAFA`), gris anthracite profond en mode sombre (`#09090B`).
* **30% (Couleur structurelle secondaire) :** Bordures subtiles (`border`), textes secondaires (`muted-foreground`), barres latérales, séparateurs.
* **10% (Couleur d'accentuation / CTA) :** Réservée exclusivement aux actions clés : bouton principal d'action, indicateur d'état actif, badge de notification.

---

## 2. Système Sémantique de Couleurs (Dark & Light Mode)

Ne jamais coder de couleurs en dur (`#2563eb` ou `rgb(...)`) dans les composants. Toujours utiliser des variables sémantiques.

### Tokens Essentiels (HSL / OKLCH) :

```css
:root {
  /* Mode Clair : Sobre, propre, fond légèrement teinté */
  --background: 0 0% 100%;
  --foreground: 240 10% 3.9%;

  --card: 0 0% 100%;
  --card-foreground: 240 10% 3.9%;

  --popover: 0 0% 100%;
  --popover-foreground: 240 10% 3.9%;

  /* Action primaire : sobre et affirmée */
  --primary: 240 5.9% 10%;
  --primary-foreground: 0 0% 98%;

  /* Éléments secondaires / neutres */
  --secondary: 240 4.8% 95.9%;
  --secondary-foreground: 240 5.9% 10%;

  --muted: 240 4.8% 95.9%;
  --muted-foreground: 240 3.8% 46.1%;

  --accent: 240 4.8% 95.9%;
  --accent-foreground: 240 5.9% 10%;

  /* Statuts fonctionnels (Destructif, Succès, Avertissement) */
  --destructive: 0 84.2% 60.2%;
  --destructive-foreground: 0 0% 98%;

  --border: 240 5.9% 90%;
  --input: 240 5.9% 90%;
  --ring: 240 5.9% 10%;

  --radius: 0.5rem; /* 8px par défaut */
}

.dark {
  /* Mode Sombre : Fond noir profond mais pas 100% noir pour éviter le clipping OLED dur */
  --background: 240 10% 3.9%;
  --foreground: 0 0% 98%;

  --card: 240 10% 4.9%;
  --card-foreground: 0 0% 98%;

  --popover: 240 10% 4.9%;
  --popover-foreground: 0 0% 98%;

  --primary: 0 0% 98%;
  --primary-foreground: 240 5.9% 10%;

  --secondary: 240 3.7% 15.9%;
  --secondary-foreground: 0 0% 98%;

  --muted: 240 3.7% 15.9%;
  --muted-foreground: 240 5% 64.9%;

  --accent: 240 3.7% 15.9%;
  --accent-foreground: 0 0% 98%;

  --destructive: 0 62.8% 30.6%;
  --destructive-foreground: 0 0% 98%;

  --border: 240 3.7% 15.9%;
  --input: 240 3.7% 15.9%;
  --ring: 240 4.9% 83.9%;
}
```

---

## 3. Configuration des Tokens CSS & Tailwind

Dans `tailwind.config.js` (ou `@theme` en Tailwind CSS v4) :

```javascript
module.exports = {
  darkMode: ["class"],
  theme: {
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
};
```

---

## 4. Échelle Typographique & Rythme Vertical

### Règles de Rigueur Typographique :
1. **Contraste de Graisse :** Un titre doit être en `font-semibold` ou `font-medium`, le corps de texte en `font-normal`. Éviter le gras excessif (`font-black`, `font-extrabold`) sur des interfaces d'outils de travail.
2. **Letter-Spacing (Tracking) :**
   - Sur les grands titres (`text-2xl`, `text-3xl`) : serrer légèrement (`tracking-tight`).
   - Sur les petits labels en majuscules (`text-xs uppercase`) : espacer (`tracking-wider`).
3. **Hauteur de Ligne (Leading) :**
   - Titres : `leading-tight` (1.1 à 1.25).
   - Corps de texte : `leading-relaxed` (1.5 à 1.6) pour faciliter la lecture des paragraphes.

---

## 5. Rayons de Courbure (Border Radius) & Élévations (Ombres)

### Les Rayons (Border Radius)
* **Composants d'action (boutons, inputs) :** `rounded-md` (6px) ou `rounded-lg` (8px).
* **Conteneurs (cartes, modales) :** `rounded-xl` (12px) ou `rounded-2xl` (16px).
* **Badges / Tags :** `rounded-full` (uniquement pour les badges d'état compacts).
* ❌ *Ne jamais appliquer `rounded-3xl` ou `rounded-full` sur de grands formulaires ou des conteneurs de tableau de bord.*

### Les Ombres (Shadows)
En design moderne, les ombres sont diffuses et multicouches (effet d'occlusion ambiante) :

```css
/* Ombre subtile de carte au repos */
.shadow-subtle {
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05),
              0 0 0 1px rgba(0, 0, 0, 0.04);
}

/* Ombre de menu déroulant / modale */
.shadow-elevated {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.08),
              0 4px 6px -2px rgba(0, 0, 0, 0.04),
              0 0 0 1px rgba(0, 0, 0, 0.06);
}
```

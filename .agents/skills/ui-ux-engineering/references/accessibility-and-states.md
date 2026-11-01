# États d'Interface & Accessibilité (WCAG 2.2 AA) — Référence

Ce document définit les standards pour concevoir des composants résilients qui gèrent tous les scénarios de vie réels (chargement, pannes, listes vides) et respectent les normes d'accessibilité.

---

## 📋 Table des matières

1. [Les 5 États Fondamentaux d'Interface](#1-les-5-états-fondamentaux-dinterface)
2. [Implémentation de Skeleton Loaders Précis](#2-implémentation-de-skeleton-loaders-précis)
3. [Empty States Engageants & Actionnables](#3-empty-states-engageants--actionnables)
4. [Gestion Gracieuse des Erreurs (Error Boundaries)](#4-gestion-gracieuse-des-erreurs)
5. [Checklist Accessibilité (WCAG 2.2 AA)](#5-checklist-accessibilité-wcag-22-aa)

---

## 1. Les 5 États Fondamentaux d'Interface

Une interface d'ingénieur sérieux ne laisse jamais l'utilisateur dans l'inconnu :

| État | Comportement Attendu | Erreur Commune à Éviter |
| :--- | :--- | :--- |
| **1. Idle / Default** | Données présentées avec hiérarchie claire et contrastes vérifiés | Surcharge d'éléments visuels sans hiérarchie |
| **2. Loading** | Skeleton loader épousant exactement la forme future du composant | Spinner circulaire géant au milieu de l'écran |
| **3. Empty** | Message bienveillant expliquant pourquoi c'est vide + CTA direct | Écran vide ou simple mention "Aucun résultat" |
| **4. Error** | Cause lisible + action de remédiation (bouton Réessayer) | Stack trace technique brute ou message opaque "Erreur 500" |
| **5. Dirty / Modifié** | Indicateur discret de modifications non sauvegardées | Perte des données saisies sans avertissement |

---

## 2. Implémentation de Skeleton Loaders Précis

Le skeleton loader doit pré-afficher la structure exacte pour éliminer les sauts d'agencement (CLS - Cumulative Layout Shift) :

```tsx
// CardSkeleton.tsx
export function SecurityScanCardSkeleton() {
  return (
    <div className="rounded-lg border border-border bg-card p-4 shadow-sm animate-pulse space-y-3">
      {/* En-tête : badge et titre */}
      <div className="flex items-center justify-between">
        <div className="h-4 w-32 rounded bg-muted" />
        <div className="h-5 w-16 rounded-full bg-muted" />
      </div>

      {/* Description : 2 lignes simulées */}
      <div className="space-y-1.5 pt-1">
        <div className="h-3 w-full rounded bg-muted/70" />
        <div className="h-3 w-4/5 rounded bg-muted/70" />
      </div>

      {/* Footer : Métadonnées et bouton */}
      <div className="flex items-center justify-between pt-3 border-t border-border/50">
        <div className="h-3 w-24 rounded bg-muted/60" />
        <div className="h-7 w-20 rounded bg-muted" />
      </div>
    </div>
  );
}
```

---

## 3. Empty States Engageants & Actionnables

L'état vide est une opportunité d'onboarding :

```tsx
import { ShieldCheck, Plus } from 'lucide-react';

export function EmptyRepositoriesState({ onAddRepo }: { onAddRepo: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-border p-12 text-center bg-card/50">
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-secondary text-muted-foreground mb-4">
        <ShieldCheck className="h-6 w-6" />
      </div>
      <h3 className="text-sm font-semibold text-foreground">Aucun dépôt connecté</h3>
      <p className="mt-1 text-xs text-muted-foreground max-w-sm">
        Connectez vos dépôts GitHub ou GitLab pour lancer votre premier audit de sécurité automatisé.
      </p>
      <button
        onClick={onAddRepo}
        className="mt-5 inline-flex items-center gap-2 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground hover:bg-primary/90 transition-colors shadow-sm"
      >
        <Plus size={14} />
        Connecter un dépôt
      </button>
    </div>
  );
}
```

---

## 4. Gestion Gracieuse des Erreurs

En cas d'erreur réseau ou d'API, toujours proposer une action de reprise :

```tsx
import { AlertCircle, RotateCcw } from 'lucide-react';

export function InlineErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex items-center justify-between rounded-md border border-destructive/20 bg-destructive/5 p-3 text-xs text-destructive">
      <div className="flex items-center gap-2">
        <AlertCircle size={16} className="flex-shrink-0" />
        <span>{message || "Impossible de charger les données pour le moment."}</span>
      </div>
      <button
        onClick={onRetry}
        className="inline-flex items-center gap-1.5 rounded bg-destructive/10 px-2 py-1 font-medium hover:bg-destructive/20 transition-colors"
      >
        <RotateCcw size={12} />
        Réessayer
      </button>
    </div>
  );
}
```

---

## 5. Checklist Accessibilité (WCAG 2.2 AA)

Avant de livrer un composant UI, valider cette checklist :

- [ ] **Contraste des Couleurs :** Ratio de contraste ≥ 4.5:1 pour le texte courant par rapport à l'arrière-plan.
- [ ] **Indicateurs de Focus Visibles :** Présence de `focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none` sur chaque élément interactif.
- [ ] **Labels Explicites sur les Icônes :** Tout bouton composé uniquement d'une icône possède un `aria-label="Nom de l'action"` ou une balise `<span className="sr-only">`.
- [ ] **Navigation Clavier :** Les modales piègent le focus (`focus-trap`) et se ferment avec la touche `Échap`.
- [ ] **Respect de `prefers-reduced-motion` :** Les animations complexes sont désactivées pour les utilisateurs sensibles :
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, ::before, ::after {
      animation-duration: 0.01ms !important;
      transition-duration: 0.01ms !important;
    }
  }
  ```

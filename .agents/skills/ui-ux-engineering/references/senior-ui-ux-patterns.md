# Référentiel Senior UI/UX & Product Design Engineer : Éradication de l'AI Slop

Ce guide définit les standards d'ingénierie d'interface et d'expérience utilisateur (**Staff Product Designer & Senior Frontend Engineer**) pour produire des applications élégantes, accessibles et robustes, débarrassées des clichés et artefacts génériques de l'IA (*AI Slop*).

---

## 📋 Table des matières

1. [Matrice Anti-« AI Slop » vs Standard Ingénieur Produit](#1-matrice-anti-ai-slop-vs-standard-ingénieur-produit)
2. [Micro-Animations Professionnelles & Performance 60 FPS](#2-micro-animations-professionnelles--performance-60-fps)
3. [Le Contrat des 5 États d'Interface](#3-le-contrat-des-5-états-dinterface)
4. [Architecture des Design Tokens & Grille 8pt](#4-architecture-des-design-tokens--grille-8pt)
5. [Accessibilité Implacable (WCAG 2.2 AA)](#5-accessibilité-implacable-wcag-22-aa)
6. [Ergonomie Mobile & Native Touch](#6-ergonomie-mobile--native-touch)
7. [Logos Authentiques & Éradication des Commentaires Décoratifs](#7-logos-authentiques--éradication-des-commentaires-décoratifs)

---

## 1. Matrice Anti-« AI Slop » vs Standard Ingénieur Produit

| Dimension | ❌ Ce que produit typiquement une IA (AI Slop) | ✅ Ce qu'exige un Senior Design Engineer (Linear/Apple/Stripe) |
| :--- | :--- | :--- |
| **Palette & Dégradés** | Dégradés violets/fuchsia/cyan criards sur fond noir profond sur chaque bouton et titre pour paraître "futuriste". | Palette sobre et raffinée (Zinc, Slate ou Neutral), teinte dominante unique et intentionnelle. Fond sombre subtil (`#09090b` / `bg-zinc-950`), bordures fines (`border-zinc-800/60`). |
| **Ombres & Lueurs** | Énormes néons colorés (`box-shadow: 0 0 50px rgba(168, 85, 247, 0.5)`) et cartes flottantes déconnectées. | Ombres douces, étagées et physiques (`shadow-xs`, `shadow-sm`) ou légers reflets directionnels (`border-t-white/10`). |
| **Espacement & Grille** | Marges arbitraires (`margin: 17px`, `gap: 23px`), aucun rythme vertical, composants écrasés ou sur-espacés. | Système de grille stricte **8pt** (multiples de 4px / 8px). Alignements parfaits, hiérarchie typographique mathématique. |
| **États de Chargement** | Un simple spinner circulaire au centre d'un conteneur vide, provoquant un saut de mise en page (*Layout Shift*). | **Skeleton Loaders** reproduisant fidèlement la forme géométrique du contenu à venir, avec balayage subtil (`animate-pulse`). |
| **Gestion des Erreurs** | Texte rouge brut jeté sous un formulaire ou alerte navigateur intrusive `alert("Erreur")`. | Carte d'erreur intégrée avec icône contextuelle, message clair non-technique et bouton de remédiation immédiate (**Retry**). |
| **Animations** | Animations de reflow lentes animant `width`, `height`, `margin` ou `top`, causant du jank et saccadant à 20 FPS. | Animations 60 FPS GPU-accélérées exclusives (`transform`, `opacity`), courbes bézier élégantes (`cubic-bezier(0.16, 1, 0.3, 1)`). |
| **Accessibilité** | Boutons d'icônes sans `aria-label`, aucun anneau de focus clavier (`outline: none` destructeur), contraste insuffisant. | Conformité WCAG 2.2 AA : anneau de focus `focus-visible:ring-2`, contraste ≥ 4.5:1, navigation clavier intégrale. |
| **Logos & Marques** | Emojis comme faux logos (`🎓 Univ`, `🌐 Moodle`) ou icônes de substitution génériques non officielles. | **Vrais logos vectoriels officiels (SVG)**. Si absent, téléchargement et intégration locale de l'asset SVG officiel dans `public/logos/`. |
| **Commentaires de Code** | Commentaires pollués d'emojis décoratifs (`// 🚀 Run`, `// 💡 Note`, `// 🔥 Magic`). | Commentaires techniques sobres, descriptifs et professionnels (standard JSDoc / TSDoc / Rustdoc) sans emojis décoratifs. |

---

## 2. Micro-Animations Professionnelles & Performance 60 FPS

### Règle d'or : Animer uniquement sur le GPU
Ne jamais animer des propriétés déclenchant le recalcul de layout ou de paint du navigateur :
- ❌ **INTERDIT :** `width`, `height`, `top`, `left`, `margin`, `padding`, `filter: blur(...)` sur de larges zones.
- ✅ **EXIGÉ :** `transform` (`translate3d`, `scale`, `rotate`) et `opacity`.

### Courbes de Bézier (Easing) Professionnelles
Bannir le easing `linear` ou `ease-in-out` basique du web. Utiliser des courbes d'inertie physique fluides :
```css
/* Easing fluide moderne (Linear / iOS) */
:root {
  --ease-spring: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-snappy: cubic-bezier(0.2, 0, 0, 1);
}
```

### Micro-Animations Décoratives Subtiles
1. **Rayon de Bordure Interactif (Border Beam) :**
   Une fine traînée lumineuse animée en `rotate(360deg)` autour d'une carte clé (ex: Sas d'accès officiel), masquée par un masque radial pour ne révéler qu'un arc de 60°.
2. **Onde Sonore / Spectre Audio Vivant :**
   Barres verticales dont l'échelle Y (`scaleY(0.3)` à `scaleY(1.0)`) est animée en pur CSS avec des délais étagés (`animation-delay: 0.15s, 0.3s...`), sans JavaScript continu.
3. **Pulsation d'Aura Ambiante :**
   Dégradé radial très doux en fond d'écran (`opacity: 0.15` à `0.25`), dérivant lentement en translation `translate3d(±10px, ±10px, 0)` sur 12 secondes.

### Respect Strict de `prefers-reduced-motion`
Tout projet professionnel doit désactiver ou simplifier les animations pour les utilisateurs ayant activé l'accessibilité mouvement :
```css
@media (prefers-reduced-motion: reduce) {
  *, ::before, ::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

---

## 3. Le Contrat des 5 États d'Interface

Tout composant affichant des données dynamiques doit être conçu comme une machine à états finie implémentant obligatoirement 5 états :

```
┌────────────────────────────────────────────────────────┐
│ 1. IDLE (Nominal)       : Données chargées et affichées│
│ 2. LOADING (Chargement) : Skeleton loaders proportionnés│
│ 3. EMPTY (Vide)         : Illustration sobre + CTA     │
│ 4. ERROR (Erreur)       : Message clair + Bouton Retry │
│ 5. DIRTY (Non sauvegardé): Indicateur d'état non scellé │
└────────────────────────────────────────────────────────┘
```

### Exemple d'Implémentation React / TypeScript :
```tsx
interface ResourceState<T> {
  status: "idle" | "loading" | "empty" | "error";
  data: T | null;
  error: string | null;
}

export function IncidentList({ state, onRetry }: { state: ResourceState<Incident[]>; onRetry: () => void }) {
  if (state.status === "loading") {
    return (
      <div className="space-y-3" role="status" aria-label="Chargement des incidents">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-16 rounded-xl bg-zinc-800/40 animate-pulse border border-zinc-700/20" />
        ))}
      </div>
    );
  }

  if (state.status === "error") {
    return (
      <div className="p-6 rounded-xl border border-rose-500/30 bg-rose-950/20 text-center">
        <AlertTriangleIcon className="w-8 h-8 text-rose-400 mx-auto mb-2" />
        <p className="text-sm font-medium text-rose-200 mb-1">{state.error || "Une erreur est survenue"}</p>
        <button
          onClick={onRetry}
          className="mt-3 px-4 py-2 text-xs font-semibold rounded-lg bg-rose-600 hover:bg-rose-500 text-white focus-visible:ring-2 focus-visible:ring-rose-400"
        >
          Réessayer
        </button>
      </div>
    );
  }

  if (state.status === "empty" || !state.data?.length) {
    return (
      <div className="p-8 rounded-xl border border-zinc-800/60 bg-zinc-900/30 text-center">
        <CheckCircleIcon className="w-8 h-8 text-emerald-400 mx-auto mb-2 opacity-80" />
        <p className="text-sm font-medium text-zinc-300">Aucun incident détecté</p>
        <p className="text-xs text-zinc-500 mt-1">La session se déroule dans des conditions nominales.</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {state.data.map((item) => (
        <IncidentCard key={item.id} incident={item} />
      ))}
    </div>
  );
}
```

---

## 4. Architecture des Design Tokens & Grille 8pt

### Pas d'Espacement Standard (8pt Rhythm)
```
- space-1  :  4px   -> Micro espacements (badge padding x, gap icône/label)
- space-2  :  8px   -> Padding interne compact (boutons denses, tags)
- space-3  : 12px   -> Espacement champs de formulaires
- space-4  : 16px   -> Padding standard de cartes, espacement horizontal
- space-6  : 24px   -> Espacement entre sections de cartes
- space-8  : 32px   -> Marges de page et conteneurs majeurs
```

### Palette Sémantique (Zéro Hex Arbitraire)
Tous les styles doivent exploiter des variables CSS ou des classes Tailwind sémantiques :
- Fond primaire : `bg-background` (`#09090b` dark / `#ffffff` light)
- Fond surélevé : `bg-card` ou `bg-muted/50`
- Bordures de structure : `border-border` ou `border-white/10`
- Texte principal : `text-foreground`
- Texte secondaire : `text-muted-foreground`
- Accentuation : `text-primary` / `bg-primary`

---

## 5. Accessibilité Implacable (WCAG 2.2 AA)

1. **Focus Rings Visibles :**
   Tout élément interactif (`<button>`, `<a>`, `<input>`) doit posséder :
   `focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2`
2. **Labels Textuels Accessibles :**
   Chaque bouton ne contenant qu'une icône doit impérativement porter un attribut `aria-label="Action explicite"`.
3. **Contraste Typographique :**
   Ratio minimal de **4.5:1** pour le texte standard (< 18pt) et **3:1** pour le texte large (≥ 18pt ou gras ≥ 14pt).
4. **Navigation Clavier :**
   Les modales doivent intercepter et confiner le focus (`focus-trap`), et se fermer à la touche `Escape`.

---

## 6. Ergonomie Mobile & Native Touch

1. **Cibles Tactiles Minimales :**
   Toute zone cliquable doit mesurer au moins **44x44 px** (iOS) ou **48x48 dp** (Android).
2. **Intégration de la Safe Area :**
   Intégrer les marges d'encoche et de barre d'accueil système :
   `padding-bottom: max(16px, env(safe-area-inset-bottom))`
3. **Zone du Pouce (Thumb Zone) :**
   Placer les actions les plus fréquentes (validation, navigation principale) dans le tiers inférieur de l'écran, accessible d'une seule main sans contorsion.

---

## 7. Logos Authentiques & Éradication des Commentaires Décoratifs

### 1. Vrais Logos Obligatoires (Zero Fake / Generic Icons)
Dans toute interface logicielle (pages de connexion, sas d'accès, portails officiels, dashboards, cartes d'intégration partenaires ou universitaires) :
- ❌ **INTERDIT :**
  - Utiliser des emojis comme logos ou emblèmes (ex: `🎓 Sorbonne`, `🏛️ Éducation Nationale`, `🌐 Moodle`, `💼 Entreprise`).
  - Utiliser des icônes génériques issues de bibliothèques d'icônes génériques (`lucide-react`, `heroicons`) pour représenter des marques ou des institutions réelles.
  - Laisser des cadres vides ou des placeholders textuels non stylisés.
- ✅ **OBLIGATOIRE :**
  - Utiliser **exclusivement les vrais logos officiels vectoriels (SVG)** ou des images WebP haute définition fournies par les marques/institutions.
  - **Protocole de Téléchargement & Intégration Locale :** Si un logo requis n'est pas encore présent dans le dépôt de code, l'agent a l'obligation formelle de **télécharger le logo officiel SVG** (depuis Simple Icons, Wikimedia Commons ou le kit de presse officiel de la marque), de l'enregistrer dans le dossier local du projet (ex: `public/logos/<marque>.svg` ou `src/assets/brands/<marque>.svg`), et de l'intégrer avec les attributs d'accessibilité requis (`alt="Logo officiel de <Nom>"`, `width`, `height`, et préservation du ratio d'aspect `preserveAspectRatio="xMidYMid meet"`).

```tsx
// ✅ EXEMPLE : Intégration d'un vrai logo SVG officiel téléchargé localement
export function MoodleIntegrationBadge() {
  return (
    <div className="flex items-center gap-2.5 px-3 py-1.5 rounded-lg border border-zinc-800 bg-zinc-900/60">
      <img
        src="/logos/moodle-official.svg"
        alt="Logo officiel Moodle"
        className="w-5 h-5 object-contain"
        loading="lazy"
      />
      <span className="text-xs font-medium text-zinc-300">Moodle LMS Officiel</span>
    </div>
  );
}
```

### 2. Commentaires de Code Professionnels (Zéro Emojis Décoratifs)
Le code source d'un projet d'entreprise ne doit pas ressembler à un brouillon généré par IA parsemé d'emojis superflus :
- ❌ **INTERDIT :**
  ```typescript
  // 🚀 Initialisation du client Moodle !
  // 💡 Note: Attention au token ici 🔥🔥
  // 🛡️ Vérification de la sécurité super blindée
  ```
- ✅ **EXIGÉ (Standard JSDoc / TSDoc / Rustdoc) :**
  ```typescript
  /**
   * Initialise la session de télémétrie et configure le canal IPC sécurisé.
   * Valide les jetons d'intégrité avant d'autoriser le sas d'examen.
   *
   * @param config - Options d'environnement et politique de rate-limiting.
   * @throws {AuthenticationError} En cas de signature invalide.
   */
  export async function initializeSession(config: SessionConfig): Promise<SessionToken> {
    // Vérification de validité temporelle du token
    if (Date.now() > config.expiresAt) {
      throw new AuthenticationError("SESSION_EXPIRED");
    }
    // ...
  }
  ```


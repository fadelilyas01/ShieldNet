# Patterns de Composants Web Modernes (SaaS & Desktop) — Référence

Ce document fournit des patterns de code éprouvés en React/TypeScript avec Tailwind CSS et des primitives accessibles (Radix UI / Shadcn).

---

## 📋 Table des matières

1. [Structure Shell d'Application (Sidebar + Header + Breadcrumb)](#1-structure-shell-dapplication)
2. [Data Table Professionnelle (Tri, Filtres, Pagination)](#2-data-table-professionnelle)
3. [Formulaire avec Validation Accessible & États de Soumission](#3-formulaire-avec-validation-accessible)
4. [Palette de Commande Rapide (⌘K Command Bar)](#4-palette-de-commande-rapide-k)
5. [Modales & Drawers Latéraux Déterministes](#5-modales--drawers-latéraux)

---

## 1. Structure Shell d'Application

Une interface d'administration ou un SaaS sérieux utilise une structure à deux panneaux fixes avec défilement interne indépendant :

```tsx
import React, { useState } from 'react';
import { LayoutDashboard, Shield, Users, Settings, Search, Bell, ChevronRight } from 'lucide-react';

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-background text-foreground antialiased font-sans">
      {/* 1. SIDEBAR FIXE */}
      <aside className={`flex flex-col border-r border-border bg-card transition-all duration-200 ease-in-out ${collapsed ? 'w-16' : 'w-64'}`}>
        {/* Logo / Nom de l'application */}
        <div className="flex h-14 items-center border-b border-border px-4">
          <Shield className="h-6 w-6 text-foreground flex-shrink-0" />
          {!collapsed && <span className="ml-3 font-semibold tracking-tight text-sm">Shieldnet Cloud</span>}
        </div>

        {/* Navigation Principale */}
        <nav className="flex-1 space-y-1 p-2 overflow-y-auto">
          <NavItem icon={<LayoutDashboard size={18} />} label="Vue d'ensemble" active collapsed={collapsed} />
          <NavItem icon={<Shield size={18} />} label="Sécurité & Vulnérabilités" count={3} collapsed={collapsed} />
          <NavItem icon={<Users size={18} />} label="Utilisateurs & Accès" collapsed={collapsed} />
          <NavItem icon={<Settings size={18} />} label="Paramètres Système" collapsed={collapsed} />
        </nav>

        {/* Profil Utilisateur / Footer Sidebar */}
        <div className="border-t border-border p-3 flex items-center gap-3">
          <div className="h-8 w-8 rounded-full bg-secondary flex items-center justify-center text-xs font-medium">JD</div>
          {!collapsed && (
            <div className="flex flex-col min-w-0 flex-1">
              <span className="text-xs font-medium truncate">Jean Dupont</span>
              <span className="text-[11px] text-muted-foreground truncate">admin@shieldnet.io</span>
            </div>
          )}
        </div>
      </aside>

      {/* 2. ZONE PRINCIPALE (Header + Contenu avec scroll indépendant) */}
      <div className="flex flex-1 flex-col overflow-hidden">
        {/* Header supérieur */}
        <header className="flex h-14 items-center justify-between border-b border-border bg-background px-6">
          {/* Fil d'Ariane (Breadcrumbs) */}
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <span>Administration</span>
            <ChevronRight size={14} />
            <span className="font-medium text-foreground">Vue d'ensemble</span>
          </div>

          {/* Recherche & Notifications */}
          <div className="flex items-center gap-3">
            <button className="flex items-center gap-2 rounded-md border border-input bg-card px-3 py-1.5 text-xs text-muted-foreground hover:bg-muted transition-colors">
              <Search size={14} />
              <span>Rechercher...</span>
              <kbd className="rounded bg-muted px-1.5 py-0.5 text-[10px] font-mono text-muted-foreground border border-border">⌘K</kbd>
            </button>
            <button className="rounded-md p-2 text-muted-foreground hover:bg-muted hover:text-foreground" aria-label="Notifications">
              <Bell size={16} />
            </button>
          </div>
        </header>

        {/* Contenu Défilant */}
        <main className="flex-1 overflow-y-auto p-6 bg-muted/20">
          <div className="mx-auto max-w-7xl">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}

function NavItem({ icon, label, active, count, collapsed }: any) {
  return (
    <a
      href="#"
      className={`flex items-center gap-3 rounded-md px-3 py-2 text-xs font-medium transition-colors ${
        active
          ? 'bg-secondary text-foreground'
          : 'text-muted-foreground hover:bg-muted hover:text-foreground'
      }`}
      title={collapsed ? label : undefined}
    >
      <span className="flex-shrink-0">{icon}</span>
      {!collapsed && <span className="flex-1 truncate">{label}</span>}
      {!collapsed && count && (
        <span className="rounded-full bg-destructive/10 px-1.5 py-0.5 text-[10px] font-medium text-destructive">{count}</span>
      )}
    </a>
  );
}
```

---

## 2. Data Table Professionnelle

Une table de données professionnelle doit comporter :
- Des largeurs de colonnes déterministes.
- Des en-têtes avec tri (`aria-sort`).
- Des statuts clairs sous forme de badges aux contrastes vérifiés.
- Des actions contextuelles alignées à droite.

```tsx
export function AuditLogTable({ logs }: { logs: Array<any> }) {
  return (
    <div className="rounded-lg border border-border bg-card shadow-sm overflow-hidden">
      {/* Barre d'outils / Filtres */}
      <div className="flex items-center justify-between p-4 border-b border-border">
        <input
          type="text"
          placeholder="Filtrer les événements..."
          className="h-8 w-64 rounded-md border border-input bg-background px-3 text-xs placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
        />
        <div className="flex gap-2">
          <button className="h-8 rounded-md border border-border px-3 text-xs font-medium hover:bg-muted">Exporter CSV</button>
          <button className="h-8 rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground hover:bg-primary/90">Nouveau Scan</button>
        </div>
      </div>

      {/* Tableau structuré */}
      <table className="w-full text-left text-xs">
        <thead className="bg-muted/50 text-muted-foreground font-medium border-b border-border">
          <tr>
            <th className="py-2.5 px-4">Horodatage</th>
            <th className="py-2.5 px-4">Événement</th>
            <th className="py-2.5 px-4">Utilisateur</th>
            <th className="py-2.5 px-4">Sévérité</th>
            <th className="py-2.5 px-4 text-right">Action</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {logs.map((log) => (
            <tr key={log.id} className="hover:bg-muted/30 transition-colors">
              <td className="py-3 px-4 font-mono text-muted-foreground">{log.timestamp}</td>
              <td className="py-3 px-4 font-medium text-foreground">{log.event}</td>
              <td className="py-3 px-4 text-muted-foreground">{log.user}</td>
              <td className="py-3 px-4">
                <SeverityBadge severity={log.severity} />
              </td>
              <td className="py-3 px-4 text-right">
                <button className="text-muted-foreground hover:text-foreground font-medium">Détails</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Pagination compacte */}
      <div className="flex items-center justify-between p-3 border-t border-border text-xs text-muted-foreground">
        <span>Affichage de 1 à 10 sur 142 résultats</span>
        <div className="flex gap-1">
          <button className="rounded px-2.5 py-1 border border-border hover:bg-muted disabled:opacity-50" disabled>Précédent</button>
          <button className="rounded px-2.5 py-1 border border-border hover:bg-muted">Suivant</button>
        </div>
      </div>
    </div>
  );
}

function SeverityBadge({ severity }: { severity: 'low' | 'medium' | 'high' | 'critical' }) {
  const styles = {
    low: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20',
    medium: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20',
    high: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 border-orange-500/20',
    critical: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/20',
  };

  return (
    <span className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] font-medium ${styles[severity]}`}>
      {severity.toUpperCase()}
    </span>
  );
}
```

---

## 3. Formulaire avec Validation Accessible

Un formulaire professionnel ne doit pas reposer uniquement sur des bordures rouges : il doit fournir des labels clairs, une aide contextuelle et un message d'erreur textuel lié via `aria-describedby`.

```tsx
export function ApiKeyCreateForm() {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <form className="space-y-4 max-w-md bg-card p-6 rounded-lg border border-border shadow-sm">
      <div className="space-y-1">
        <label htmlFor="key-name" className="text-xs font-medium text-foreground">
          Nom de la Clé API <span className="text-destructive">*</span>
        </label>
        <input
          id="key-name"
          name="name"
          type="text"
          placeholder="Ex: Production CI/CD Token"
          aria-describedby={error ? "key-name-error" : "key-name-hint"}
          aria-invalid={!!error}
          className={`h-9 w-full rounded-md border bg-background px-3 text-xs transition-colors focus-visible:outline-none focus-visible:ring-1 ${
            error
              ? 'border-destructive focus-visible:ring-destructive'
              : 'border-input focus-visible:ring-ring'
          }`}
        />
        {error ? (
          <p id="key-name-error" className="text-[11px] text-destructive font-medium">{error}</p>
        ) : (
          <p id="key-name-hint" className="text-[11px] text-muted-foreground">Identifiant unique lisible pour votre équipe.</p>
        )}
      </div>

      <div className="flex justify-end gap-2 pt-2">
        <button type="button" className="h-8 px-3 rounded-md border border-border text-xs font-medium hover:bg-muted">Annuler</button>
        <button
          type="submit"
          disabled={isSubmitting}
          className="h-8 px-3 rounded-md bg-primary text-xs font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50 flex items-center gap-2"
        >
          {isSubmitting && <span className="h-3 w-3 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />}
          Créer la clé
        </button>
      </div>
    </form>
  );
}
```

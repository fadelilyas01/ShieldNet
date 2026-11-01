# Guide UX Writing : Éradication du Jargon Technique & Communication Humaine

Ce guide définit les standards d'écriture d'interface (**UX Writing & Product Copy**) pour concevoir des logiciels compréhensibles par tout être humain, éliminant tout jargon d'ingénieur, acronyme hermétique ou message d'erreur anxiogène.

---

## 📋 Table des matières

1. [La Règle d'Or des 3 Questions](#1-la-règle-dor-des-3-questions)
2. [Lexique de Traduction : Jargon Technique vers Langage Humain](#2-lexique-de-traduction--jargon-technique-vers-langage-humain)
3. [Anatomie d'un Message d'Erreur Professionnel](#3-anatomie-dun-message-derreur-professionnel)
4. [Micro-Copy des Boutons d'Action (Adieu les boutons vagues)](#4-micro-copy-des-boutons-daction)
5. [Notifications, Bannières & États Transitoires](#5-notifications-bannières--états-transitoires)

---

## 1. La Règle d'Or des 3 Questions

Chaque message d'alerte, modale ou statut affiché à un utilisateur final doit obligatoirement répondre à **trois questions fondamentales** sans utiliser de vocabulaire informatique :

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. QUE S'EST-IL PASSÉ ?    → Constat simple et factuel en une phrase  │
│ 2. QUEL EST L'IMPACT ?      → Rassurance immédiate sur les données     │
│ 3. QUE DOIS-JE FAIRE ?      → Solution claire avec un bouton d'action  │
└────────────────────────────────────────────────────────────────────────┘
```

### Exemple Comparatif :
- ❌ **Anti-Pattern Jargon / Académique :**
  > *"Error 504 Gateway Timeout: Échec de transmission du payload JSON vers l'endpoint websocket /api/v1/sync. Socket disconnected."*
- ✅ **Standard Senior Product UX :**
  > **Connexion temporairement ralentie**  
  > Vos dernières réponses sont bien conservées sur cet appareil. Le système se reconnecte automatiquement dès que le réseau redevient stable.  
  > *[Bouton : Vérifier la connexion]*

---

## 2. Lexique de Traduction : Jargon Technique vers Langage Humain

Ne jamais exposer ces termes techniques dans l'interface utilisateur. Utiliser systématiquement leur équivalent humain :

| Terme Technique Interdit en UI | Équivalent Humain Professionnel |
| :--- | :--- |
| **Erreur 401 / Unauthorized** | « Session expirée. Veuillez vous reconnecter pour continuer. » |
| **Erreur 403 / Forbidden** | « Vous n'avez pas accès à cet espace. Contactez votre responsable si nécessaire. » |
| **Erreur 404 / Not Found** | « Cette page ou ce document n'est plus disponible. » |
| **Erreur 500 / Internal Server Error** | « Un incident temporaire empêche cette opération. Vos données sont préservées, veuillez réessayer dans quelques instants. » |
| **Timeout / Gateway Timeout 504** | « Le serveur met plus de temps que prévu à répondre. Nous renouvelons la tentative. » |
| **Payload / JSON / Body** | « Données » ou « Informations » |
| **SHA-256 / Hash / Digest** | « Empreinte de sécurité » ou « Scellement numérique » |
| **SSRF / IP private blocked** | « L'adresse demandée n'est pas autorisée par la politique de sécurité. » |
| **MediaStreamTrack ended / Cam null** | « Votre caméra ne transmet plus d'image. Vérifiez qu'elle est bien branchée ou allumée. » |
| **Websocket disconnected** | « Liaison interrompue. Reconnexion automatique en cours... » |
| **SQL Exception / DB Lock** | « Enregistrement temporairement indisponible. Nouvelle tentative immédiate. » |
| **Parsing error / Schema mismatch** | « Le format du document n'est pas reconnu. » |
| **IPC failure / Tauri command rejected** | « Le composant système n'a pas répondu. Veuillez relancer l'application. » |

---

## 3. Anatomie d'un Message d'Erreur Professionnel

Un message d'erreur senior ne blâme jamais l'utilisateur et ne se contente pas d'afficher du rouge. Il apporte une solution concrète :

```tsx
// ✅ Composant d'erreur explicite et empathique
export function CameraErrorBanner({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="p-4 rounded-xl border border-amber-500/30 bg-amber-950/20 text-amber-200 flex items-start gap-3">
      <CameraOffIcon className="w-5 h-5 text-amber-400 mt-0.5 shrink-0" />
      <div className="space-y-1 text-sm">
        <p className="font-semibold text-zinc-100">Caméra introuvable ou occupée</p>
        <p className="text-zinc-300 text-xs">
          Une autre application utilise peut-être votre caméra (Teams, Zoom, Discord). Fermez ces applications puis réessayez.
        </p>
        <div className="pt-2">
          <button
            onClick={onRetry}
            className="px-3 py-1.5 text-xs font-medium rounded-lg bg-amber-500 hover:bg-amber-400 text-zinc-950 transition-colors"
          >
            Réactiver la caméra
          </button>
        </div>
      </div>
    </div>
  );
}
```

---

## 4. Micro-Copy des Boutons d'Action

Les boutons doivent décrire précisément l'action qui va s'exécuter, pas de mots vagues comme « OK », « Soumettre » ou « Cliquez ici » :

| ❌ Intitulé Vague ou Brusque | ✅ Micro-Copy Spécifique & Rassurante |
| :--- | :--- |
| `OK` | « J'ai compris » ou « Continuer » |
| `Soumettre` | « Valider et transmettre ma copie » |
| `Supprimer` (sans contexte) | « Supprimer définitivement cette tentative » |
| `Envoyer` | « Transmettre les pièces jointes » |
| `Enregistrer` | « Enregistrer les modifications » |
| En cours d'action (`Loading`) | « Enregistrement sécurisé... » *(avec spinner discret)* |

---

## 5. Notifications, Bannières & États Transitoires

1. **Retours de Succès Discrets :**
   - Ne pas ouvrir de modale bloquante pour un simple succès. Utiliser un toast éphémère (3 à 4 secondes) : *« Copie sauvegardée à 18:52 »*.
2. **Alertes Bloquantes Réservées aux Situations Critiques :**
   - N'utiliser une boîte de dialogue modale que si l'utilisateur risque de perdre son travail (ex: quitter l'examen avant la fin).
3. **Statut Réseau Visible mais Non Intrusif :**
   - En cas de micro-coupure réseau : afficher une fine pastille ambrée dans la barre de titre (*« Reconnexion au serveur... »*) sans figer l'écran ni afficher de popup anxiogène.

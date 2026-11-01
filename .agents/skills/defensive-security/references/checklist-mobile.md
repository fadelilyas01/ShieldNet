# Checklist de sécurité Mobile — Exhaustive

Checklist complète pour le déploiement sécurisé d'applications mobiles
(Android et iOS).

---

## 🔐 Stockage de données

- [ ] Pas de données sensibles dans SharedPreferences/UserDefaults en clair
- [ ] EncryptedSharedPreferences (Android) / Keychain (iOS) pour les tokens
- [ ] SQLCipher pour les bases SQLite contenant des données sensibles
- [ ] Pas de données sensibles dans le stockage externe (Android)
- [ ] Pas de données sensibles dans les logs
- [ ] Pas de données sensibles dans les captures d'écran automatiques
- [ ] Pas de données sensibles dans le presse-papier
- [ ] Cache HTTP nettoyé pour les données sensibles
- [ ] WebView cache désactivé pour les pages sensibles
- [ ] Données temporaires nettoyées à la déconnexion
- [ ] `android:allowBackup="false"` ou backups chiffrés
- [ ] Keyboard cache désactivé pour les champs sensibles (iOS)

## 🔑 Authentification et Autorisation

- [ ] Authentification toujours vérifiée côté serveur
- [ ] Biométrie implémentée correctement (avec fallback sécurisé)
- [ ] Pas de bypass d'authentification possible
- [ ] Session timeout sur inactivité
- [ ] Re-authentification pour les opérations sensibles
- [ ] Tokens stockés dans le stockage sécurisé
- [ ] Access tokens à durée courte (15 min)
- [ ] Refresh token avec rotation
- [ ] Déconnexion complète (invalidation côté serveur)
- [ ] Autorisation vérifiée côté serveur à chaque requête
- [ ] Pas de logique d'autorisation uniquement côté client

## 🌐 Communication réseau

- [ ] TLS 1.2+ obligatoire
- [ ] `android:usesCleartextTraffic="false"` (Android)
- [ ] App Transport Security activé sans exceptions (iOS)
- [ ] Network Security Config restrictif (Android)
- [ ] Certificate pinning implémenté
- [ ] Pas de désactivation de la validation SSL (même en debug)
- [ ] Pas d'acceptation de tous les certificats
- [ ] Backup pins configurés (en cas de rotation de certificat)
- [ ] Détection de proxy SSL (optionnel, selon la sensibilité)

## 🛡️ Protection du binaire

- [ ] Obfuscation activée (ProGuard/R8 Android)
- [ ] Symbols strippés des builds de production (iOS)
- [ ] Détection de root/jailbreak
- [ ] Détection de debugging
- [ ] Détection de tampering / repackaging
- [ ] Vérification de l'intégrité de la signature de l'app
- [ ] Code natif pour la logique sensible (optionnel)
- [ ] RASP intégré (optionnel, pour les apps très sensibles)

## 📱 Configuration de l'application

### Android
- [ ] `android:debuggable="false"` en production
- [ ] `android:allowBackup="false"`
- [ ] `android:networkSecurityConfig` configuré
- [ ] `android:usesCleartextTraffic="false"`
- [ ] Composants non exportés par défaut (`android:exported="false"`)
- [ ] Content providers protégés par permissions
- [ ] Permissions minimales demandées
- [ ] `minSdkVersion` raisonnable (≥ 24 recommandé)
- [ ] ProGuard/R8 activé
- [ ] Pas de broadcast receivers implicites non protégés

### iOS
- [ ] App Transport Security activé (pas d'exceptions)
- [ ] Entitlements minimaux
- [ ] Pas d'URLs schemes personnalisés non validés
- [ ] Associated Domains configurés pour Universal Links
- [ ] Background modes limités au nécessaire
- [ ] Data Protection: NSFileProtectionComplete

## 🔗 Deep Links et IPC

- [ ] Deep links validés (host, path, paramètres)
- [ ] Universal Links / App Links préférés aux custom URL schemes
- [ ] Intents Android filtrés et validés
- [ ] Pas de données sensibles passées via deep links
- [ ] Content providers avec permissions appropriées
- [ ] Pas d'activités internes exportées

## 📊 Entrées et Sorties

- [ ] Validation de toutes les entrées utilisateur
- [ ] Validation côté client ET côté serveur
- [ ] WebViews sécurisées (JavaScript désactivé si non nécessaire)
- [ ] `allowFileAccess=false` dans les WebViews
- [ ] Pas de `addJavascriptInterface` non contrôlé
- [ ] Filtrage des URLs chargées dans les WebViews
- [ ] Sanitisation des données affichées
- [ ] Protection contre les injections dans les requêtes locales

## 🔒 Cryptographie

- [ ] Algorithmes modernes (AES-256-GCM, RSA-2048+, ECDSA)
- [ ] Pas de MD5, SHA1, DES, RC4
- [ ] Clés stockées dans le hardware-backed keystore
- [ ] IV/Nonce uniques pour chaque opération
- [ ] Pas de clés cryptographiques hardcodées
- [ ] SecureRandom utilisé pour la génération aléatoire
- [ ] Pas d'implémentation crypto personnalisée
- [ ] Clés avec taille appropriée (AES-256, RSA-2048+)

## 📝 Logging et Diagnostics

- [ ] Pas de `console.log` / `print` / `Log.d` avec données sensibles en prod
- [ ] Crashlytics/Sentry configuré sans données PII
- [ ] Pas de données sensibles dans les analytics
- [ ] Logs de sécurité envoyés au backend (événements critiques)
- [ ] Stack traces non visibles par l'utilisateur

## 🧪 Tests de sécurité

- [ ] Tests d'authentification
- [ ] Tests d'autorisation (IDOR, escalade de privilèges)
- [ ] Tests de stockage sécurisé
- [ ] Tests de communication réseau (MITM)
- [ ] Analyse statique (MobSF, SonarQube)
- [ ] Test de reverse engineering (décompilation)
- [ ] Test de tampering

## 📦 Dépendances et Supply Chain

- [ ] Audit des dépendances (vulnérabilités connues)
- [ ] Dépendances provenant de sources officielles
- [ ] Lockfiles commités
- [ ] Pas de SDKs avec des pratiques de données douteuses
- [ ] Signature de l'APK/IPA vérifiée
- [ ] Review des permissions demandées par les SDKs tiers

## 🏗️ Build et Distribution

- [ ] Signing keys protégées (pas dans le repo)
- [ ] Builds de production sans debug symbols
- [ ] Pas de credentials de test en production
- [ ] Release management sécurisé (accès restreint)
- [ ] App Signing by Google Play / App Store signatures

## 📜 Conformité et Privacy

- [ ] Politique de confidentialité accessible dans l'app
- [ ] Consentement avant collecte de données
- [ ] Droit de suppression des données implémenté
- [ ] App Privacy Details / Data Safety Section remplis
- [ ] RGPD/CCPA compliance vérifiée
- [ ] Pas de tracking sans consentement
- [ ] ATT (App Tracking Transparency) implémenté (iOS)


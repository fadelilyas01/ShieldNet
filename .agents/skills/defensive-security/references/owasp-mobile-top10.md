# OWASP Mobile Top 10 (2024) — Référence défensive

Ce document détaille les 10 catégories de vulnérabilités mobiles les plus
critiques selon OWASP Mobile Top 10 (2024), avec les contre-mesures défensives.

---

## M1:2024 — Improper Credential Usage (Utilisation incorrecte des identifiants)

**Description :** Identifiants codés en dur dans le code source, stockage non
sécurisé des tokens et clés API, transmission d'identifiants non chiffrée.

**Impact :** Extraction de clés API depuis l'APK/IPA, accès non autorisé aux
backends, compromission des comptes utilisateurs.

### Contre-mesures

1. **Jamais de secrets dans le code** — Utiliser des variables d'environnement
   ou un coffre-fort de secrets (Vault, AWS Secrets Manager).
2. **Stockage sécurisé** — Keychain (iOS), EncryptedSharedPreferences (Android),
   flutter_secure_storage.
3. **Tokens à durée limitée** — Expiration courte (15min access token), refresh
   token avec rotation.
4. **Obfuscation** — ProGuard/R8 (Android), pas de string literals pour les
   secrets.
5. **Détection de fuites** — Scanner le code source avec des outils comme
   truffleHog ou gitleaks.

```kotlin
// ❌ MAUVAIS : Clé API en dur
val API_KEY = "sk-1234567890abcdef"

// ✅ BON : Stockage sécurisé Android
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()
val sharedPrefs = EncryptedSharedPreferences.create(
    context, "secure_prefs", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
sharedPrefs.edit().putString("api_token", token).apply()
```

---

## M2:2024 — Inadequate Supply Chain Security

**Description :** Utilisation de bibliothèques tierces non vérifiées, SDKs
malveillants, dépendances compromises.

**Impact :** Injection de code malveillant, vol de données, cryptojacking.

### Contre-mesures

1. **Audit des dépendances** — Vérifier les sources, la réputation et la
   maintenance des bibliothèques.
2. **Lockfiles stricts** — Committer `package-lock.json`, `pubspec.lock`,
   `Podfile.lock`.
3. **Scanners de vulnérabilités** — `npm audit`, OWASP Dependency-Check,
   Snyk.
4. **Signature des packages** — Vérifier les checksums et signatures.
5. **Minimal dependencies** — Réduire le nombre de dépendances au strict
   nécessaire.

---

## M3:2024 — Insecure Authentication/Authorization

**Description :** Mécanismes d'authentification faibles ou contournables,
absence de vérification côté serveur, autorisation implémentée uniquement
côté client.

**Impact :** Contournement de l'authentification, escalade de privilèges, accès
aux données d'autres utilisateurs.

### Contre-mesures

1. **Authentification côté serveur** — Toujours valider les tokens sur le
   backend, jamais uniquement en local.
2. **Biométrie + fallback sécurisé** — Implémenter la biométrie avec un fallback
   robuste (pas un simple PIN à 4 chiffres).
3. **Vérification d'autorisation par requête** — Chaque appel API doit vérifier
   que l'utilisateur a le droit d'accéder à la ressource demandée.
4. **Token binding** — Lier les tokens à l'appareil (device ID + fingerprint).
5. **Session timeout** — Expiration automatique des sessions inactives.

```swift
// ✅ BON : Authentification biométrique iOS avec Keychain
import LocalAuthentication

func authenticateUser(completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    context.localizedFallbackTitle = "Utiliser le mot de passe"

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &error) else {
        completion(false)
        return
    }

    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Authentifiez-vous pour continuer") {
        success, error in
        DispatchQueue.main.async {
            completion(success)
        }
    }
}
```

---

## M4:2024 — Insufficient Input/Output Validation

**Description :** Validation insuffisante des données entrantes et sortantes :
injection SQL via les champs de l'app, XSS dans les WebViews, path traversal.

**Impact :** Exécution de code, vol de données, compromission de l'appareil.

### Contre-mesures

1. **Validation stricte des entrées** — Type, longueur, format, plage.
2. **WebView sécurisée** — Désactiver JavaScript si non nécessaire, ne pas
   charger d'URLs non fiables.
3. **Encodage des sorties** — Encoder avant d'afficher dans les WebViews.
4. **Content providers sécurisés** — Protéger les content providers Android avec
   des permissions appropriées.
5. **Schémas d'URL validés** — Filtrer les deep links et schémas d'URL.

```kotlin
// ✅ BON : WebView sécurisée Android
webView.settings.apply {
    javaScriptEnabled = false // Activer uniquement si nécessaire
    allowFileAccess = false
    allowContentAccess = false
    allowFileAccessFromFileURLs = false
    allowUniversalAccessFromFileURLs = false
}
// Filtrer les URLs chargées
webView.webViewClient = object : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val url = request?.url?.toString() ?: return true
        return !url.startsWith("https://trusted-domain.com")
    }
}
```

---

## M5:2024 — Insecure Communication

**Description :** Communications non chiffrées, validation de certificats
absente ou contournable, protocol downgrade.

**Impact :** Interception de données (MITM), vol de credentials, modification
de données en transit.

### Contre-mesures

1. **TLS 1.2+ obligatoire** — Configurer Network Security Config (Android) et
   ATS (iOS).
2. **Certificate pinning** — Épingler les certificats des serveurs de confiance.
3. **Pas d'exceptions** — Ne pas désactiver la validation SSL, même en debug.
4. **HSTS** — S'assurer que le backend envoie le header HSTS.
5. **Détecter les proxies** — Alerter si un proxy SSL est détecté.

```xml
<!-- ✅ BON : Android Network Security Config -->
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">AAAAAA...</pin>
            <pin digest="SHA-256">BBBBBB...</pin> <!-- Backup pin -->
        </pin-set>
    </domain-config>
</network-security-config>
```

```swift
// ✅ BON : Certificate pinning iOS avec URLSession
class PinnedSessionDelegate: NSObject, URLSessionDelegate {
    let pinnedHashes: Set<String> = ["sha256/AAAAAA...", "sha256/BBBBBB..."]

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        // Vérifier le hash du certificat contre les pins
        let serverHash = sha256Hash(of: SecCertificateCopyData(certificate) as Data)
        if pinnedHashes.contains(serverHash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

---

## M6:2024 — Inadequate Privacy Controls

**Description :** Collecte excessive de données personnelles, absence de
consentement, stockage non sécurisé des PII, partage non autorisé avec des tiers.

**Impact :** Violations RGPD/CCPA, amendes, perte de confiance des utilisateurs.

### Contre-mesures

1. **Minimisation des données** — Ne collecter que les données strictement
   nécessaires.
2. **Consentement explicite** — Demander le consentement avant toute collecte.
3. **Pseudonymisation** — Pseudonymiser les données dès que possible.
4. **Droit à l'oubli** — Implémenter la suppression complète des données utilisateur.
5. **Privacy by Design** — Intégrer la protection de la vie privée dès la
   conception.

---

## M7:2024 — Insufficient Binary Protections

**Description :** Absence d'obfuscation, pas de détection de tampering, pas de
protection contre l'ingénierie inverse.

**Impact :** Reverse engineering de l'application, extraction de secrets,
création de clones malveillants.

### Contre-mesures

1. **Obfuscation** — ProGuard/R8 (Android), SwiftShield (iOS).
2. **Détection de root/jailbreak** — Détecter et réagir aux appareils
   compromis.
3. **Anti-tampering** — Vérifier l'intégrité de l'application au runtime.
4. **Code natif pour la logique sensible** — Déplacer la logique critique dans
   du code natif (C/C++).
5. **Runtime Application Self-Protection (RASP)** — Implémenter des contrôles
   RASP.

```kotlin
// ✅ BON : Détection de root Android
fun isDeviceRooted(): Boolean {
    val paths = arrayOf(
        "/system/app/Superuser.apk",
        "/sbin/su", "/system/bin/su",
        "/system/xbin/su", "/data/local/xbin/su",
        "/data/local/bin/su", "/system/sd/xbin/su"
    )
    return paths.any { File(it).exists() } ||
           Runtime.getRuntime().exec("which su").inputStream.bufferedReader()
               .readText().isNotEmpty()
}

// Vérification d'intégrité de l'APK
fun verifyAppSignature(context: Context): Boolean {
    val packageInfo = context.packageManager.getPackageInfo(
        context.packageName, PackageManager.GET_SIGNING_CERTIFICATES
    )
    val signatures = packageInfo.signingInfo.apkContentsSigners
    val expectedHash = "expected_signature_hash"
    return signatures.any {
        MessageDigest.getInstance("SHA-256")
            .digest(it.toByteArray())
            .joinToString("") { "%02x".format(it) } == expectedHash
    }
}
```

---

## M8:2024 — Security Misconfiguration

**Description :** Configurations par défaut non sécurisées, permissions
excessives, mode debug activé en production, exports non intentionnels de
composants Android.

**Impact :** Fuite d'informations, accès non autorisé aux composants,
exploitation via des configurations laxistes.

### Contre-mesures

1. **android:debuggable="false"** — Toujours en production.
2. **Permissions minimales** — Ne demander que les permissions nécessaires.
3. **Exporter explicitement** — `android:exported="false"` par défaut pour les
   composants Android.
4. **Backup sécurisé** — `android:allowBackup="false"` ou chiffrer les backups.
5. **ATS (iOS)** — Ne pas ajouter d'exceptions App Transport Security.

```xml
<!-- ✅ BON : AndroidManifest.xml sécurisé -->
<application
    android:debuggable="false"
    android:allowBackup="false"
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false">

    <!-- Composants non exportés par défaut -->
    <activity android:name=".InternalActivity"
              android:exported="false" />

    <provider android:name=".SecureProvider"
              android:exported="false"
              android:grantUriPermissions="false" />
</application>
```

---

## M9:2024 — Insecure Data Storage

**Description :** Données sensibles stockées de manière non sécurisée :
SharedPreferences en clair, SQLite non chiffré, fichiers dans le stockage
externe, logs contenant des PII.

**Impact :** Extraction de données via backup, accès physique à l'appareil,
malware avec permissions de lecture.

### Contre-mesures

1. **EncryptedSharedPreferences** — Utiliser le stockage chiffré d'Android.
2. **Keychain** — Utiliser le Keychain pour les données sensibles iOS.
3. **SQLCipher** — Chiffrer les bases SQLite.
4. **Pas de stockage externe** — Ne jamais stocker de données sensibles sur le
   stockage externe.
5. **Supprimer les données temporaires** — Nettoyer les caches et fichiers
   temporaires contenant des données sensibles.

```dart
// ✅ BON : Stockage sécurisé Flutter
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

// Stocker un token
await storage.write(key: 'auth_token', value: token);

// Lire un token
final token = await storage.read(key: 'auth_token');

// Supprimer toutes les données sensibles à la déconnexion
await storage.deleteAll();
```

---

## M10:2024 — Insufficient Cryptography

**Description :** Utilisation d'algorithmes obsolètes (MD5, SHA1, DES, RC4),
clés de chiffrement faibles, gestion de clés incorrecte, implémentation
personnalisée de la cryptographie.

**Impact :** Déchiffrement des données, forge de tokens, contournement de
l'intégrité.

### Contre-mesures

1. **Algorithmes modernes** — AES-256-GCM, RSA-2048+, ECDSA P-256+.
2. **Bibliothèques éprouvées** — Utiliser les APIs du système (CryptoKit iOS,
   Jetpack Security Android).
3. **Gestion des clés** — Utiliser le hardware-backed keystore (Android
   Keystore, Secure Enclave iOS).
4. **IV/Nonce uniques** — Générer un IV/nonce unique pour chaque opération de
   chiffrement.
5. **Pas de crypto maison** — Ne jamais implémenter ses propres algorithmes
   cryptographiques.

```kotlin
// ✅ BON : Chiffrement AES-GCM avec Android Keystore
val keyGenerator = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
)
keyGenerator.init(
    KeyGenParameterSpec.Builder("secure_key",
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .build()
)
val secretKey = keyGenerator.generateKey()

val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, secretKey)
val iv = cipher.iv
val encrypted = cipher.doFinal(plainText.toByteArray())
```


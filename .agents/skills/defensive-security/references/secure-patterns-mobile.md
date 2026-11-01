# Patterns Mobile sécurisés — Référence

Exemples de code sécurisé pour React Native, Flutter, Swift et Kotlin.

---

## Stockage sécurisé

### React Native

```javascript
import EncryptedStorage from 'react-native-encrypted-storage';
import * as Keychain from 'react-native-keychain';

// ✅ BON : Stockage chiffré pour les tokens
async function storeToken(token) {
  await EncryptedStorage.setItem('auth_token', token);
}

async function getToken() {
  return await EncryptedStorage.getItem('auth_token');
}

async function clearTokens() {
  await EncryptedStorage.clear();
}

// ✅ BON : Keychain pour les credentials
async function storeCredentials(username, password) {
  await Keychain.setGenericPassword(username, password, {
    accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
    accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
    securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
  });
}

async function getCredentials() {
  const credentials = await Keychain.getGenericPassword({
    authenticationPrompt: {
      title: 'Authentification requise',
      description: 'Utilisez votre empreinte pour accéder à vos identifiants',
    },
  });
  return credentials || null;
}
```

### Flutter

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'com.yourapp.secure',
    ),
  );

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

### Swift (iOS)

```swift
import Security

class KeychainService {
    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case notFound
    }

    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func read(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(status)
        }
        return data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### Kotlin (Android)

```kotlin
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureStorage(private val context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val sharedPrefs = EncryptedSharedPreferences.create(
        context,
        "secure_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveToken(token: String) {
        sharedPrefs.edit().putString("auth_token", token).apply()
    }

    fun getToken(): String? {
        return sharedPrefs.getString("auth_token", null)
    }

    fun clear() {
        sharedPrefs.edit().clear().apply()
    }
}
```

---

## Authentification biométrique

### React Native

```javascript
import ReactNativeBiometrics from 'react-native-biometrics';

const biometrics = new ReactNativeBiometrics({
  allowDeviceCredentials: true,
});

async function authenticateWithBiometrics() {
  const { available, biometryType } = await biometrics.isSensorAvailable();

  if (!available) {
    throw new Error('Biométrie non disponible');
  }

  const { success } = await biometrics.simplePrompt({
    promptMessage: 'Confirmez votre identité',
    cancelButtonText: 'Annuler',
  });

  if (!success) {
    throw new Error('Authentification biométrique échouée');
  }

  return true;
}

// ✅ Générer une paire de clés liée à la biométrie
async function createBiometricKey() {
  const { publicKey } = await biometrics.createKeys();
  // Envoyer publicKey au serveur pour l'associer au compte
  return publicKey;
}

async function signWithBiometrics(payload) {
  const { signature } = await biometrics.createSignature({
    promptMessage: 'Signez pour confirmer',
    payload,
  });
  return signature;
}
```

### Flutter

```dart
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authentifiez-vous pour continuer',
        options: const AuthenticationOptions(
          stickyAuth: true,       // Ne pas annuler si l'app passe en arrière-plan
          biometricOnly: false,   // Autoriser le fallback PIN/mot de passe
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
```

---

## Communication réseau sécurisée

### React Native (Certificate Pinning)

```javascript
// Avec react-native-ssl-pinning
import { fetch as sslFetch } from 'react-native-ssl-pinning';

async function secureApiCall(endpoint, body) {
  const response = await sslFetch(`https://api.example.com${endpoint}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${await getToken()}`,
    },
    body: JSON.stringify(body),
    sslPinning: {
      certs: ['api_cert'], // Certificat épinglé dans les assets
    },
    timeoutInterval: 30000,
  });

  return response.json();
}
```

### Flutter (Certificate Pinning avec Dio)

```dart
import 'dart:io';
import 'package:dio/dio.dart';

class SecureHttpClient {
  late final Dio _dio;

  SecureHttpClient() {
    final securityContext = SecurityContext(withTrustedRoots: false);
    // Charger le certificat épinglé
    securityContext.setTrustedCertificatesBytes(
      File('assets/certs/api_cert.pem').readAsBytesSync()
    );

    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Intercepteur pour ajouter le token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorageService().getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }
}
```

---

## Détection de root/jailbreak

### React Native

```javascript
import JailMonkey from 'jail-monkey';

function checkDeviceSecurity() {
  const risks = {
    isJailBroken: JailMonkey.isJailBroken(),
    canMockLocation: JailMonkey.canMockLocation(),
    isDebuggedMode: JailMonkey.isDebuggedMode(),
    isOnExternalStorage: JailMonkey.isOnExternalStorage(),
    hookDetected: JailMonkey.hookDetected(),
  };

  if (risks.isJailBroken) {
    // ⚠️ Selon la sensibilité, bloquer ou avertir
    Alert.alert(
      'Appareil compromis',
      'Cet appareil semble être rooté/jailbreaké. ' +
      'Certaines fonctionnalités peuvent être désactivées pour votre sécurité.'
    );
    // Désactiver les fonctionnalités sensibles
    disableSensitiveFeatures();
  }

  return risks;
}
```

### Flutter

```dart
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class DeviceSecurityCheck {
  Future<bool> isDeviceCompromised() async {
    final jailbroken = await FlutterJailbreakDetection.jailbroken;
    final developerMode = await FlutterJailbreakDetection.developerMode;

    if (jailbroken) {
      // Logger l'événement de sécurité
      SecurityLogger.log('COMPROMISED_DEVICE_DETECTED');
      return true;
    }
    return false;
  }
}
```

---

## Deep Links sécurisés

### React Native

```javascript
import { Linking } from 'react-native';

// ✅ BON : Validation des deep links
const ALLOWED_HOSTS = ['app.example.com'];
const ALLOWED_PATHS = ['/profile', '/settings', '/products'];

function handleDeepLink(url) {
  try {
    const parsed = new URL(url);

    // Vérifier le host
    if (!ALLOWED_HOSTS.includes(parsed.hostname)) {
      console.warn('Deep link bloqué : host non autorisé', parsed.hostname);
      return;
    }

    // Vérifier le path
    const basePath = '/' + parsed.pathname.split('/').filter(Boolean)[0];
    if (!ALLOWED_PATHS.includes(basePath)) {
      console.warn('Deep link bloqué : path non autorisé', parsed.pathname);
      return;
    }

    // Sanitiser les paramètres
    const params = {};
    parsed.searchParams.forEach((value, key) => {
      // N'accepter que les paramètres connus
      if (['id', 'ref'].includes(key)) {
        params[key] = value.replace(/[^a-zA-Z0-9-_]/g, '');
      }
    });

    // Router vers l'écran approprié
    navigateTo(basePath, params);
  } catch (error) {
    console.error('Deep link invalide', error);
  }
}

Linking.addEventListener('url', ({ url }) => handleDeepLink(url));
```

---

## Logs sécurisés (Mobile)

```javascript
// ✅ BON : Logger sécurisé qui supprime les données sensibles en production
class SecureLogger {
  static isProduction = !__DEV__;

  static sanitize(data) {
    if (typeof data !== 'object' || data === null) return data;

    const sensitiveKeys = [
      'password', 'token', 'secret', 'authorization',
      'credit_card', 'ssn', 'pin', 'cvv',
    ];

    const sanitized = { ...data };
    for (const key of Object.keys(sanitized)) {
      if (sensitiveKeys.some(sk => key.toLowerCase().includes(sk))) {
        sanitized[key] = '[REDACTED]';
      }
    }
    return sanitized;
  }

  static log(message, data = {}) {
    if (this.isProduction) {
      // En production : envoyer au service de monitoring (sans données sensibles)
      MonitoringService.log({
        message,
        data: this.sanitize(data),
        timestamp: new Date().toISOString(),
      });
    } else {
      console.log(`[LOG] ${message}`, this.sanitize(data));
    }
  }

  static error(message, error, data = {}) {
    if (this.isProduction) {
      MonitoringService.error({
        message,
        error: error.message, // Pas la stack trace en prod
        data: this.sanitize(data),
      });
    } else {
      console.error(`[ERROR] ${message}`, error, this.sanitize(data));
    }
  }
}
```

---

## Bases de données locales chiffrées (Mobile)

### React Native / Flutter (SQLCipher)

```javascript
// React Native avec react-native-sqlcipher-storage
import SQLite from 'react-native-sqlcipher-storage';
import * as Keychain from 'react-native-keychain';

async function getOrGenerateDbKey() {
  const credentials = await Keychain.getGenericPassword({ service: 'db_encryption_key' });
  if (credentials) return credentials.password;

  // Génération d'une clé AES 256 bits aléatoire stockée dans le Keychain
  const newKey = Array.from(crypto.getRandomValues(new Uint8Array(32)))
    .map(b => b.toString(16).padStart(2, '0')).join('');
  await Keychain.setGenericPassword('db_user', newKey, { service: 'db_encryption_key' });
  return newKey;
}

export async function openEncryptedDatabase() {
  const password = await getOrGenerateDbKey();
  return SQLite.openDatabase({
    name: 'app_encrypted.db',
    location: 'default',
    key: password, // Clé de chiffrement SQLCipher (AES-256)
  });
}
```

### Android (Room avec SQLCipher)

```kotlin
// Android Room + SQLCipher
import androidx.room.Room
import net.sqlcipher.database.SupportFactory

val passphrase = getSecureKeyFromAndroidKeyStore() // Clé depuis Android KeyStore
val factory = SupportFactory(passphrase)

val db = Room.databaseBuilder(context, AppDatabase::class.java, "secure_app.db")
    .openHelperFactory(factory) // Chiffrement transparent de la base SQLite
    .build()
```

---

## Sécurisation des WebViews

Les WebViews mal configurées sont l'une des sources majeures de vulnérabilités mobiles (XSS local, vol de fichiers privés).

### Android (WebView durcie)

```kotlin
val webView = findViewById<WebView>(R.id.webview)
val settings = webView.settings

// ❌ INTERDIRE formellement l'accès aux fichiers locaux du package
settings.allowFileAccess = false
settings.allowContentAccess = false
settings.allowFileAccessFromFileURLs = false
settings.allowUniversalAccessFromFileURLs = false

// Activer JavaScript uniquement si strictement indispensable
settings.javaScriptEnabled = true

// Restreindre le chargement aux domaines légitimes
webView.webViewClient = object : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val url = request?.url?.toString() ?: return true
        if (url.startsWith("https://trusted.example.com/")) {
            return false // Charger dans la WebView
        }
        // Ouvrir les liens externes dans le navigateur système
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        startActivity(intent)
        return true
    }
}
```

### iOS (WKWebView sécurisée)

```swift
import WebKit

let config = WKWebViewConfiguration()
let preferences = WKWebpagePreferences()
preferences.allowsContentJavaScript = true
config.defaultWebpagePreferences = preferences

// Interdire la lecture de fichiers locaux sans restriction
config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")

let webView = WKWebView(frame: .zero, configuration: config)
```

---

## Prévention des Fuites d'Écran (Screen Leakage)

Empêche la capture d'écran, l'enregistrement vidéo malveillant et l'exposition de données sensibles dans le sélecteur d'applications en tâche de fond.

### Android (`FLAG_SECURE`)

```kotlin
// Dans MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // Empêche les captures d'écran et masque l'aperçu dans le multitâche
    window.setFlags(
        WindowManager.LayoutParams.FLAG_SECURE,
        WindowManager.LayoutParams.FLAG_SECURE
    )
    setContentView(R.layout.activity_main)
}
```

### iOS (Floutage dans le Multitâche)

```swift
// Dans SceneDelegate.swift ou AppDelegate.swift
func sceneWillResignActive(_ scene: UIScene) {
    // Ajouter un écran de masquage quand l'app passe en arrière-plan
    let blurEffect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = window?.frame ?? .zero
    blurView.tag = 9999
    window?.addSubview(blurView)
}

func sceneDidBecomeActive(_ scene: UIScene) {
    // Retirer le floutage quand l'utilisateur revient sur l'application
    window?.viewWithTag(9999)?.removeFromSuperview()
}
```

---

## RASP & Détection Anti-Tampering (Frida / Hooks)

```kotlin
// Détection basique de présence d'outils de hook (Frida / Xposed) sur Android
fun isFridaServerRunning(): Boolean {
    val commonPorts = intArrayOf(27042, 27043)
    for (port in commonPorts) {
        try {
            val socket = java.net.Socket("127.0.0.1", port)
            socket.close()
            return true // Port Frida ouvert détecté
        } catch (_: Exception) {}
    }
    // Vérification des maps mémoire
    val mapsFile = java.io.File("/proc/self/maps")
    if (mapsFile.exists()) {
        val content = mapsFile.readText()
        if (content.contains("frida") || content.contains("xposed")) {
            return true
        }
    }
    return false
}
```



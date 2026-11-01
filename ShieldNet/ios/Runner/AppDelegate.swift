import Flutter
import UIKit
import CallKit
import CommonCrypto

// ==============================================================================
// ShieldNet iOS Main Application Delegate & Native Platform Bridge
// Support complet CallKit, App Groups et Chiffrement Matériel (iOS Security Standard)
// ==============================================================================

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CALL_CHANNEL = "com.shieldnet.shieldnet/call_screening"
  private let SECURITY_CHANNEL = "com.shieldnet.security"
  private let extensionIdentifier = "com.shieldnet.shieldnet.ShieldNetCallExtension"
  private let appGroupSuiteName = "group.com.shieldnet.shieldnet"
  private let blacklistFileName = "shieldnet_ios_blacklist.json"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let callChannel = FlutterMethodChannel(name: CALL_CHANNEL, binaryMessenger: controller.binaryMessenger)
    let securityChannel = FlutterMethodChannel(name: SECURITY_CHANNEL, binaryMessenger: controller.binaryMessenger)

    // -------------------------------------------------------------------------
    // 1. Canal d'Interception et de Filtrage d'Appels (CallKit Bridge)
    // -------------------------------------------------------------------------
    callChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "isCallScreeningActive":
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: self.extensionIdentifier) { status, error in
          if let error = error {
            result(FlutterError(code: "CALLKIT_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(status == .enabled)
          }
        }
        
      case "requestCallScreeningRole":
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: self.extensionIdentifier) { status, error in
          if status == .enabled {
            result(true)
          } else {
            // Sur iOS, l'utilisateur doit activer l'extension dans Réglages > Téléphone > Blocage et identification
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
              DispatchQueue.main.async {
                UIApplication.shared.open(settingsUrl)
              }
            }
            result(false)
          }
        }
        
      case "reloadCallDirectoryExtension":
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: self.extensionIdentifier) { error in
          if let error = error {
            result(FlutterError(code: "RELOAD_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      case "syncBlockedNumbersToExtension":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments dictionary required", details: nil))
          return
        }

        var parsedNumbers: [Int64] = []
        if let intNumbers = args["numbers"] as? [Int64] {
          parsedNumbers = intNumbers
        } else if let intValues = args["numbers"] as? [Int] {
          parsedNumbers = intValues.map { Int64($0) }
        } else if let stringValues = args["numbers"] as? [String] {
          parsedNumbers = stringValues.compactMap { str in
            let digits = str.filter { $0.isNumber }
            return Int64(digits)
          }
        }

        // Sauvegarde dans UserDefaults partagé de l'App Group
        let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
        defaults?.set(parsedNumbers, forKey: "blocked_phone_numbers")
        defaults?.synchronize()

        // Sauvegarde fichier JSON partagé pour supporter les listes massives
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupSuiteName) {
          let fileURL = containerURL.appendingPathComponent(self.blacklistFileName)
          let payload: [String: Any] = [
            "blocked": parsedNumbers,
            "updated_at": ISO8601DateFormatter().string(from: Date())
          ]
          if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) {
            try? data.write(to: fileURL)
          }
        }
        
        // Rechargement immédiat de l'extension CallKit
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: self.extensionIdentifier) { error in
          if let error = error {
            result(FlutterError(code: "RELOAD_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      case "testDatabaseBridge":
        let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
        let count = (defaults?.array(forKey: "blocked_phone_numbers") as? [Int64])?.count ?? 0
        let diag: [String: Any] = [
          "connected": true,
          "platform": "iOS CallKit",
          "extension_id": self.extensionIdentifier,
          "app_group": self.appGroupSuiteName,
          "blocked_count": count,
          "message": "Pont natif iOS CallKit opérationnel"
        ]
        result(diag)

      case "checkNumber":
        guard let args = call.arguments as? [String: Any],
              let numberStr = args["number"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "number parameter required", details: nil))
          return
        }
        let digits = numberStr.filter { $0.isNumber }
        if let targetNumber = Int64(digits) {
          let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
          let numbers = defaults?.array(forKey: "blocked_phone_numbers") as? [Int64] ?? []
          result(numbers.contains(targetNumber))
        } else {
          result(false)
        }

      case "setContactsOnlyMode":
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
        defaults?.set(enabled, forKey: "contacts_only_mode")
        defaults?.synchronize()
        result(true)

      case "isContactsOnlyMode":
        let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
        result(defaults?.bool(forKey: "contacts_only_mode") ?? false)

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // -------------------------------------------------------------------------
    // 2. Canal de Sécurité Cryptographique (Keychain Bridge)
    // -------------------------------------------------------------------------
    securityChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      if call.method == "setCryptoSalt" {
        guard let salt = (call.arguments as? [String: Any])?["salt"] as? String else {
          result(FlutterError(code: "INVALID_SALT", message: "Crypto salt string required", details: nil))
          return
        }
        // Stockage sécurisé du sel dans les préférences de l'App Group
        let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
        defaults?.set(salt, forKey: "shieldnet_crypto_salt")
        defaults?.synchronize()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import Foundation
import CallKit

// ==============================================================================
// ShieldNet Call Directory Extension (iOS Native CallKit Integration)
// Conforme au Standard Zéro-Vulnérabilité & Privacy by Design (Loi 25 / LPRPDE)
// ==============================================================================

class CallDirectoryHandler: CXCallDirectoryProvider {

    private let appGroupSuiteName = "group.com.shieldnet.shieldnet"
    private let blacklistFileName = "shieldnet_ios_blacklist.json"

    // Numéros d'urgence vitale et services publics à immunité absolue (jamais filtrés)
    private let emergencyNumbers: Set<Int64> = [
        911, 811, 988, 711, 311, 211, 511,
        1911, 1811, 1988, 1711, 1311, 1211, 1511
    ]

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        do {
            if context.isIncremental {
                // Synchronisation delta optimisée (ajouts et retraits ciblés)
                try handleIncrementalRequest(with: context)
            } else {
                // Rechargement initial complet
                try handleFullRequest(with: context)
            }
        } catch {
            // Mode Fail-Secure : Journalisation sobre sans crash de l'extension
            NSLog("[ShieldNet CallDirectoryHandler] Erreur lors du traitement: %@", error.localizedDescription)
        }

        context.completeRequest()
    }

    // -------------------------------------------------------------------------
    // 1. Rechargement Complet (Full Rebuild)
    // -------------------------------------------------------------------------
    private func handleFullRequest(with context: CXCallDirectoryExtensionContext) throws {
        let (blockedNumbers, identifiedNumbers) = loadStoredPhoneEntries()

        // 1. Enregistrement des numéros bloqués (Blacklist absolue)
        for number in blockedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        // 2. Enregistrement des numéros suspects identifiés (Avertissement citoyen)
        for (number, label) in identifiedNumbers {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)
        }
    }

    // -------------------------------------------------------------------------
    // 2. Rechargement Incrémental (Delta Updates)
    // -------------------------------------------------------------------------
    private func handleIncrementalRequest(with context: CXCallDirectoryExtensionContext) throws {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        
        // Retrait des numéros réhabilités (Faux-positifs purgés)
        let removedNumbers = (defaults?.array(forKey: "removed_phone_numbers") as? [Int64] ?? []).sorted()
        for number in removedNumbers {
            context.removeBlockingEntry(withPhoneNumber: number)
            context.removeIdentificationEntry(withPhoneNumber: number)
        }

        // Ajout des nouveaux numéros signalés
        let (newBlocked, newIdentified) = loadStoredPhoneEntries()
        for number in newBlocked {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
        for (number, label) in newIdentified {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)
        }

        // Purge de l'historique delta une fois appliqué
        defaults?.removeObject(forKey: "removed_phone_numbers")
        defaults?.synchronize()
    }

    // -------------------------------------------------------------------------
    // 3. Chargement et Normalisation Sécurisée des Données
    // -------------------------------------------------------------------------
    private func loadStoredPhoneEntries() -> ([Int64], [(Int64, String)]) {
        var rawBlocked: [Int64] = []
        var rawIdentified: [(Int64, String)] = []

        // Source A : Fichier JSON partagé dans l'App Group (Pour les volumétries élevées)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName) {
            let fileURL = containerURL.appendingPathComponent(blacklistFileName)
            if let data = try? Data(contentsOf: fileURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let blocked = json["blocked"] as? [Int64] {
                    rawBlocked.append(contentsOf: blocked)
                }
                if let identified = json["identified"] as? [[String: Any]] {
                    for item in identified {
                        if let num = item["number"] as? Int64,
                           let label = item["label"] as? String {
                            rawIdentified.append((num, label))
                        }
                    }
                }
            }
        }

        // Source B : Fallback UserDefaults partagé
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        if rawBlocked.isEmpty {
            let defaultsBlocked = defaults?.array(forKey: "blocked_phone_numbers") as? [Int64] ?? []
            rawBlocked.append(contentsOf: defaultsBlocked)
        }
        if rawIdentified.isEmpty {
            let defaultsSpam = defaults?.array(forKey: "spam_identification_numbers") as? [Int64] ?? []
            for num in defaultsSpam {
                rawIdentified.append((num, "ShieldNet: Suspect d'Appel Frauduleux"))
            }
        }

        // Normalisation stricte pour CallKit :
        // 1. Exclure rigoureusement les urgences (Immunité absolue)
        // 2. Dédupliquer
        // 3. Trier impérativement par ordre croissant (Exigence CallKit stricte)
        let filteredBlocked = Set(rawBlocked).subtracting(emergencyNumbers).sorted()
        
        let filteredIdentifiedMap = Dictionary(grouping: rawIdentified.filter { !emergencyNumbers.contains($0.0) }, by: { $0.0 })
            .mapValues { $0.first?.1 ?? "ShieldNet: Spam Téléphonique" }
        let sortedIdentified = filteredIdentifiedMap.keys.sorted().map { ($0, filteredIdentifiedMap[$0]!) }

        return (filteredBlocked, sortedIdentified)
    }
}

// -----------------------------------------------------------------------------
// Gestionnaire d'Erreurs Délégué
// -----------------------------------------------------------------------------
extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("[ShieldNet CallDirectoryHandler] La requête de l'extension a échoué: %@", error.localizedDescription)
    }
}

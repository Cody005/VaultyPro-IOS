import Foundation
import LocalAuthentication
import Security
import SwiftData

// MARK: - VaultManager

@MainActor
@Observable
final class VaultManager {

    // MARK: - Nested types

    enum AuthMethod: String {
        case pin      = "pin"
        case biometric = "biometric"
        case none     = "none"
    }

    enum VaultState {
        case notSetup   // vault exists but no auth configured yet
        case locked     // auth set up, waiting for unlock
        case unlocked   // auth passed, content visible
    }

    // MARK: - Published state

    private(set) var vaultState: VaultState = .notSetup {
        didSet {
            guard vaultState != oldValue else { return }
            if vaultState == .unlocked { scheduleAutoLock() } else { cancelAutoLock() }
        }
    }
    private(set) var authMethod: AuthMethod = .none
    private(set) var biometryType: LABiometryType = .none

    /// Seconds of inactivity before the vault auto-locks while the app is in the foreground.
    /// `0` disables the inactivity timer (still locks on background / relaunch).
    var autoLockSeconds: Int {
        didSet {
            UserDefaults.standard.set(autoLockSeconds, forKey: autoLockKey)
            if vaultState == .unlocked { scheduleAutoLock() }
        }
    }
    private var autoLockTask: Task<Void, Never>?

    /// Number of consecutive failed PIN attempts in the current lockout window.
    private(set) var failedAttempts: Int = 0
    /// When set, PIN entry is blocked until this date.
    private(set) var lockedOutUntil: Date?

    // MARK: - Keychain constants

    private let keychainService = "com.vaultypro.vault"
    private let keychainAccount = "vault-pin"

    // MARK: - UserDefaults keys

    private let authMethodKey  = "vaultypro.vault.authMethod"
    private let isSetupKey      = "vaultypro.vault.isSetup"
    private let autoLockKey     = "vaultypro.vault.autoLockSeconds"

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.object(forKey: autoLockKey) as? Int
        autoLockSeconds = stored ?? 60
        loadPersistedState()
        refreshBiometryType()
    }

    // MARK: - Computed helpers

    var isLockedOut: Bool {
        guard let lockedOutUntil else { return false }
        return lockedOutUntil > Date()
    }

    var lockoutSecondsRemaining: Int {
        guard let lockedOutUntil, lockedOutUntil > Date() else { return 0 }
        return Int(lockedOutUntil.timeIntervalSinceNow.rounded(.up))
    }

    var canUseBiometrics: Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    var biometryDisplayName: String {
        switch biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Biometrics"
        }
    }

    var biometrySystemImage: String {
        switch biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "faceid"
        }
    }

    // MARK: - Setup

    /// Stores `pin` in Keychain and marks vault as set up with PIN auth.
    func setupWithPIN(_ pin: String) {
        guard pin.count == 6 else { return }
        saveToKeychain(pin)
        authMethod = .pin
        persist()
        vaultState = .unlocked
    }

    /// Triggers a biometric prompt; on success marks vault as set up with biometric auth.
    func setupWithBiometrics() async -> Bool {
        let reason = "Set up \(biometryDisplayName) to protect your Vault"
        let ok = await performBiometricEvaluation(reason: reason)
        if ok {
            authMethod = .biometric
            persist()
            vaultState = .unlocked
        }
        return ok
    }

    // MARK: - Unlock

    /// Returns `true` and unlocks on correct PIN; records failed attempt otherwise.
    @discardableResult
    func unlockWithPIN(_ pin: String) -> Bool {
        guard !isLockedOut else { return false }
        guard let stored = readFromKeychain(), pin == stored else {
            failedAttempts += 1
            if failedAttempts >= 5 {
                lockedOutUntil = Date().addingTimeInterval(30)
                failedAttempts = 0
            }
            return false
        }
        failedAttempts = 0
        lockedOutUntil = nil
        vaultState = .unlocked
        return true
    }

    /// Triggers a biometric prompt; on success unlocks vault.
    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        let ok = await performBiometricEvaluation(reason: "Unlock your Vault")
        if ok { vaultState = .unlocked }
        return ok
    }

    // MARK: - Lock

    func lock() {
        if vaultState == .unlocked { vaultState = .locked }
    }

    // MARK: - Inactivity auto-lock

    /// Call on user interaction while the vault is open to restart the inactivity countdown.
    func keepAlive() {
        guard vaultState == .unlocked else { return }
        scheduleAutoLock()
    }

    private func scheduleAutoLock() {
        cancelAutoLock()
        let seconds = autoLockSeconds
        guard seconds > 0 else { return }
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(seconds)))
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }

    private func cancelAutoLock() {
        autoLockTask?.cancel()
        autoLockTask = nil
    }

    // MARK: - Forgot PIN / Reset

    /// Moves all vault items back to inbox, deletes PIN, resets auth state.
    func resetVault(in context: ModelContext) {
        let descriptor = FetchDescriptor<StashItem>(
            predicate: #Predicate { $0.isInVault }
        )
        if let vaultItems = try? context.fetch(descriptor) {
            for item in vaultItems {
                item.isInVault = false
                item.collection = nil
            }
            try? context.save()
        }

        deleteFromKeychain()
        authMethod = .none
        failedAttempts = 0
        lockedOutUntil = nil

        UserDefaults.standard.removeObject(forKey: authMethodKey)
        UserDefaults.standard.set(false, forKey: isSetupKey)

        vaultState = .notSetup
    }

    // MARK: - Vault collection bootstrap

    /// Creates the singleton Vault collection if it doesn't exist yet.
    func ensureVaultCollection(in context: ModelContext) {
        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { $0.isVault }
        )
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        let vault = Collection(
            name: "Vault",
            emoji: "🔒",
            colorHex: "#2D1B69",
            isVault: true,
            sortOrder: -1
        )
        context.insert(vault)
        try? context.save()
    }

    // MARK: - Move items

    func moveToVault(_ item: StashItem, vaultCollection: Collection, in context: ModelContext) {
        item.isInVault = true
        item.collection = vaultCollection
        try? context.save()
    }

    func removeFromVault(_ item: StashItem, in context: ModelContext) {
        item.isInVault = false
        item.collection = nil
        try? context.save()
    }

    // MARK: - Private helpers

    private func loadPersistedState() {
        let raw = UserDefaults.standard.string(forKey: authMethodKey) ?? AuthMethod.none.rawValue
        authMethod = AuthMethod(rawValue: raw) ?? .none
        let isSetup = UserDefaults.standard.bool(forKey: isSetupKey)
        vaultState = isSetup ? .locked : .notSetup
    }

    private func persist() {
        UserDefaults.standard.set(authMethod.rawValue, forKey: authMethodKey)
        UserDefaults.standard.set(true, forKey: isSetupKey)
    }

    private func refreshBiometryType() {
        biometryType = currentBiometryType()
    }

    // MARK: - Nonisolated biometric helpers (avoid Sendable issues in Swift 6)

    nonisolated private func performBiometricEvaluation(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return false
        }
        do {
            return try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    nonisolated private func currentBiometryType() -> LABiometryType {
        let ctx = LAContext()
        var err: NSError?
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType
    }

    // MARK: - Keychain

    private func saveToKeychain(_ pin: String) {
        let data = Data(pin.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainService,
            kSecAttrAccount:      keychainAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

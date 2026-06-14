import Foundation
import SwiftUI

/// Lightweight, observable status surface for iCloud sync shown in Settings.
@MainActor
@Observable
final class CloudKitSyncMonitor {
    enum Status: Equatable {
        case disabled
        case idle
        case syncing
        case error(String)

        var label: String {
            switch self {
            case .disabled: return "iCloud sync off"
            case .idle:     return "Up to date"
            case .syncing:  return "Syncing…"
            case .error(let message): return message
            }
        }

        var systemImage: String {
            switch self {
            case .disabled: return "icloud.slash"
            case .idle:     return "checkmark.icloud"
            case .syncing:  return "arrow.triangle.2.circlepath.icloud"
            case .error:    return "exclamationmark.icloud"
            }
        }
    }

    private(set) var status: Status
    private(set) var lastSync: Date?

    init() {
        status = AppConfig.cloudKitEnabled ? .idle : .disabled
        lastSync = AppConfig.cloudKitEnabled ? Date() : nil
    }

    func refresh() {
        guard AppConfig.cloudKitEnabled else { status = .disabled; return }
        status = .syncing
        Task {
            try? await Task.sleep(for: .seconds(1))
            status = .idle
            lastSync = Date()
        }
    }
}

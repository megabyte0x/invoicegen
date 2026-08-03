import Foundation
import InvoiceCore

enum DraftOrigin: Equatable {
    case new
    case persisted
}

struct DraftSession<Value: Equatable>: Equatable {
    var origin: DraftOrigin
    var baseline: Value
    var value: Value

    var isDirty: Bool {
        origin == .new || value != baseline
    }

    mutating func markCommitted(_ committed: Value) {
        origin = .persisted
        baseline = committed
        value = committed
    }
}

struct WorkspaceSettingsDraft: Equatable {
    var businessProfile: BusinessProfile
    var paymentAcceptanceDetails: [PaymentAcceptanceDetail]
}

enum DraftKind: String, Equatable {
    case invoice
    case client
    case project
    case settings
}

extension DraftKind {
    var displayName: String {
        switch self {
        case .invoice: "invoice"
        case .client: "client"
        case .project: "project"
        case .settings: "business and payment"
        }
    }
}

enum StoreReplacementRequest: Equatable {
    case reloadFromDisk
    case sampleData
    case backup(URL)

    var actionTitle: String {
        switch self {
        case .reloadFromDisk: "Reload From Disk"
        case .sampleData: "Seed Sample Data"
        case .backup: "Restore Backup"
        }
    }
}

struct PendingStoreReplacement: Equatable {
    let sceneID: UUID
    let request: StoreReplacementRequest
}

struct StoreReplacementFeedback: Equatable, Identifiable {
    let id = UUID()
    let sceneID: UUID
    let message: String
    let isError: Bool
}

enum NavigationIntent: Equatable {
    case section(AppSection)
    case invoice(UUID)
    case client(UUID)
    case project(UUID)
    case newInvoice
    case newClient
    case newProject
    case closeWindow
}

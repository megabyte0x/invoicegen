import Foundation
import SwiftUI
import InvoiceCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case invoices
    case clients
    case projects
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .invoices: return "Invoices"
        case .clients: return "Clients"
        case .projects: return "Projects"
        case .settings: return "Business & Payments"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .invoices: return "doc.text"
        case .clients: return "person.2"
        case .projects: return "folder"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var book: InvoiceBook
    @Published var selectedSection: AppSection = .dashboard
    @Published var selectedInvoiceID: UUID?
    @Published var selectedClientID: UUID?
    @Published var selectedProjectID: UUID?
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var invoiceDraft: DraftSession<Invoice>?
    @Published var clientDraft: DraftSession<Client>?
    @Published var projectDraft: DraftSession<Project>?
    @Published var settingsDraft: DraftSession<WorkspaceSettingsDraft>?
    @Published var activeDraftRoute: DraftKind?
    @Published var pendingNavigation: NavigationIntent?
    @Published var dirtyDraftRequiringDecision: DraftKind?
    @Published var draftCommandTargetPendingCancellation: DraftCommandTarget?
    @Published var pendingStoreReplacement: StoreReplacementRequest?
    @Published var contextualReturnSection: AppSection?
    @Published var editorIssues: [EditorIssue] = []
    @Published var focusedEditorField: EditorField?
    @Published var transientEditorInputIssues: [EditorField: String] = [:]
    @Published private(set) var automaticGenerationCheckScheduledFor: Date?

    let store: LocalInvoiceStore
    var loadedStoreSuccessfully: Bool
    private var automaticGenerationCheckTask: Task<Void, Never>?

    init(store: LocalInvoiceStore = LocalInvoiceStore()) {
        self.store = store
        do {
            self.book = try store.load()
            self.loadedStoreSuccessfully = true
        } catch {
            self.book = .empty
            self.loadedStoreSuccessfully = false
            self.errorMessage = error.localizedDescription
        }
        runScheduledAutomaticGenerationCheck(now: Date())
    }

    deinit {
        automaticGenerationCheckTask?.cancel()
    }

    var hasDirtyDraft: Bool {
        invoiceDraft?.isDirty == true ||
            clientDraft?.isDirty == true ||
            projectDraft?.isDirty == true ||
            settingsDraft?.isDirty == true ||
            !transientEditorInputIssues.isEmpty
    }

    func presentEditorIssues(_ issues: [EditorIssue]) {
        editorIssues = issues
        focusedEditorField = issues.first?.field
    }

    func clearEditorIssues() {
        editorIssues = []
        focusedEditorField = nil
    }

    func requestDraftCancellation(_ target: DraftCommandTarget) {
        guard isDraftDirty(target.kind) else {
            cancelDraft(target.kind)
            return
        }

        draftCommandTargetPendingCancellation = target
    }

    func reload() {
        do {
            book = try store.load()
            loadedStoreSuccessfully = true
            errorMessage = nil
            runScheduledAutomaticGenerationCheck(now: Date())
        } catch {
            loadedStoreSuccessfully = false
            errorMessage = error.localizedDescription
            clearScheduledAutomaticGenerationCheck()
        }
    }

    func exportStore(to destinationURL: URL) {
        do {
            try store.exportStore(to: destinationURL)
            errorMessage = "Exported local store backup to \(destinationURL.path)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestStoreReplacement(_ request: StoreReplacementRequest) {
        pendingStoreReplacement = request
    }

    func cancelStoreReplacement() {
        pendingStoreReplacement = nil
    }

    func confirmStoreReplacement() {
        guard let request = pendingStoreReplacement else { return }
        do {
            let replacement: InvoiceBook
            let message: String
            switch request {
            case .sampleData:
                replacement = .sample()
                try store.save(replacement)
                message = "Replaced the local store with sample data."
            case let .backup(url):
                replacement = try store.restoreStore(from: url)
                message = "Restored local store from \(url.path)"
            }
            applySuccessfulStoreReplacement(replacement, message: message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(now: Date = Date()) {
        save(now: now, allowingOverwriteAfterLoadFailure: false)
    }

    private func save(now: Date = Date(), allowingOverwriteAfterLoadFailure: Bool) {
        guard loadedStoreSuccessfully || allowingOverwriteAfterLoadFailure else {
            errorMessage = AppPersistenceError.storeWasNotLoaded.localizedDescription
            return
        }

        do {
            var candidate = book
            candidate.generateAutomaticInvoices(now: now)
            candidate.refreshInvoiceStatuses(now: now)
            try store.save(candidate)
            book = candidate
            loadedStoreSuccessfully = true
            errorMessage = nil
            scheduleAutomaticGenerationCheck(now: now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runScheduledAutomaticGenerationCheck(now: Date = Date()) {
        persistAutomaticInvoicesIfNeeded(now: now)
        scheduleAutomaticGenerationCheck(now: now)
    }

    private func persistAutomaticInvoicesIfNeeded(now: Date) {
        guard loadedStoreSuccessfully else { return }

        var candidate = book
        let generatedInvoices = candidate.generateAutomaticInvoices(now: now)
        guard !generatedInvoices.isEmpty else { return }

        do {
            candidate.refreshInvoiceStatuses(now: now)
            try store.save(candidate)
            book = candidate
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleAutomaticGenerationCheck(now: Date = Date()) {
        automaticGenerationCheckTask?.cancel()

        guard loadedStoreSuccessfully, let nextGenerationDate = nextAutomaticGenerationDate() else {
            automaticGenerationCheckTask = nil
            automaticGenerationCheckScheduledFor = nil
            return
        }

        automaticGenerationCheckScheduledFor = nextGenerationDate
        let delaySeconds = max(0, nextGenerationDate.timeIntervalSince(now))
        let delayNanoseconds = UInt64(min(delaySeconds * 1_000_000_000, Double(UInt64.max)))

        automaticGenerationCheckTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            self?.runScheduledAutomaticGenerationCheck()
        }
    }

    private func clearScheduledAutomaticGenerationCheck() {
        automaticGenerationCheckTask?.cancel()
        automaticGenerationCheckTask = nil
        automaticGenerationCheckScheduledFor = nil
    }

    private func applySuccessfulStoreReplacement(_ replacement: InvoiceBook, message: String) {
        book = replacement
        invoiceDraft = nil
        clientDraft = nil
        projectDraft = nil
        settingsDraft = nil
        selectedInvoiceID = nil
        selectedClientID = nil
        selectedProjectID = nil
        activeDraftRoute = nil
        pendingNavigation = nil
        dirtyDraftRequiringDecision = nil
        contextualReturnSection = nil
        clearEditorIssues()
        clearAllTransientEditorInputIssues()
        searchText = ""
        draftCommandTargetPendingCancellation = nil
        pendingStoreReplacement = nil
        clearScheduledAutomaticGenerationCheck()
        selectedSection = .dashboard
        loadedStoreSuccessfully = true
        scheduleAutomaticGenerationCheck()
        errorMessage = message
    }

    private func nextAutomaticGenerationDate() -> Date? {
        book.invoices
            .filter { $0.autoGeneration.isEnabled }
            .map(\.autoGeneration.nextGenerationDate)
            .min()
    }

}

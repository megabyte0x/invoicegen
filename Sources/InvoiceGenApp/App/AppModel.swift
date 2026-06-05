import Foundation
import SwiftUI
import InvoiceCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case invoices
    case clients
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .invoices: return "Invoices"
        case .clients: return "Clients"
        case .projects: return "Projects"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .invoices: return "doc.text"
        case .clients: return "person.2"
        case .projects: return "folder"
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
    @Published private(set) var automaticGenerationCheckScheduledFor: Date?

    let store: LocalInvoiceStore
    private var loadedStoreSuccessfully: Bool
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

    func restoreStore(from sourceURL: URL) {
        do {
            try store.restoreStore(from: sourceURL)
            book = try store.load()
            loadedStoreSuccessfully = true
            selectedInvoiceID = book.invoices.first?.id
            selectedClientID = book.clients.first?.id
            selectedProjectID = book.projects.first?.id
            errorMessage = "Restored local store from \(sourceURL.path)"
            scheduleAutomaticGenerationCheck()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(now: Date = Date()) {
        save(now: now, allowingOverwriteAfterLoadFailure: false)
    }

    private func save(now: Date = Date(), allowingOverwriteAfterLoadFailure: Bool) {
        guard loadedStoreSuccessfully || allowingOverwriteAfterLoadFailure else {
            errorMessage = "Local Invoice did not save because the local store could not be loaded. Fix or reload the store file before saving, or use Seed Sample Data to intentionally replace it."
            return
        }

        do {
            book.generateAutomaticInvoices(now: now)
            book.refreshInvoiceStatuses(now: now)
            try store.save(book)
            loadedStoreSuccessfully = true
            errorMessage = nil
            scheduleAutomaticGenerationCheck(now: now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seedSampleData() {
        book = .sample()
        selectedSection = .dashboard
        selectedInvoiceID = book.invoices.first?.id
        save(allowingOverwriteAfterLoadFailure: true)
    }

    func runScheduledAutomaticGenerationCheck(now: Date = Date()) {
        persistAutomaticInvoicesIfNeeded(now: now)
        scheduleAutomaticGenerationCheck(now: now)
    }

    private func persistAutomaticInvoicesIfNeeded(now: Date) {
        guard loadedStoreSuccessfully else { return }

        let generatedInvoices = book.generateAutomaticInvoices(now: now)
        guard !generatedInvoices.isEmpty else { return }

        do {
            book.refreshInvoiceStatuses(now: now)
            try store.save(book)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutomaticGenerationCheck(now: Date = Date()) {
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

    private func nextAutomaticGenerationDate() -> Date? {
        book.invoices
            .filter { $0.autoGeneration.isEnabled }
            .map(\.autoGeneration.nextGenerationDate)
            .min()
    }

    func addInvoice() {
        let now = Date()
        let clientId = book.clients.first?.id
        let dueDays = book.businessProfile.paymentTermsDays
        let invoice = Invoice(
            number: book.nextInvoiceNumber(date: now),
            clientId: clientId,
            issueDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: dueDays, to: now) ?? now,
            currencyCode: book.businessProfile.currencyCode,
            lineItems: [
                InvoiceLineItem(title: "Professional services", quantity: 1, unitPriceMinorUnits: 0)
            ],
            terms: "Net \(dueDays)."
        )
        book.invoices.insert(invoice, at: 0)
        selectedSection = .invoices
        selectedInvoiceID = invoice.id
        save()
    }

    func deleteSelectedInvoice() {
        guard let id = selectedInvoiceID else { return }
        book.invoices.removeAll { $0.id == id }
        selectedInvoiceID = book.invoices.first?.id
        save()
    }

    func addClient() {
        let client = Client(name: "New Client")
        book.clients.insert(client, at: 0)
        selectedSection = .clients
        selectedClientID = client.id
        save()
    }

    func deleteSelectedClient() {
        guard let id = selectedClientID else { return }
        book.clients.removeAll { $0.id == id }
        for index in book.invoices.indices where book.invoices[index].clientId == id {
            book.invoices[index].clientId = nil
        }
        for index in book.projects.indices where book.projects[index].clientId == id {
            book.projects[index].clientId = nil
        }
        selectedClientID = book.clients.first?.id
        save()
    }

    func addProject() {
        let project = Project(
            clientId: book.clients.first?.id,
            name: "New Project",
            currencyCode: book.businessProfile.currencyCode
        )
        book.projects.insert(project, at: 0)
        selectedSection = .projects
        selectedProjectID = project.id
        save()
    }

    func deleteSelectedProject() {
        guard let id = selectedProjectID else { return }
        book.projects.removeAll { $0.id == id }
        for index in book.invoices.indices where book.invoices[index].projectId == id {
            book.invoices[index].projectId = nil
        }
        selectedProjectID = book.projects.first?.id
        save()
    }

    func addPaymentAcceptanceDetail(kind: PaymentAcceptanceKind) {
        let detail = PaymentAcceptanceDetail(
            kind: kind,
            label: defaultPaymentAcceptanceLabel(for: kind),
            details: ""
        )
        book.paymentAcceptanceDetails.append(detail)
        save()
    }

    func deletePaymentAcceptanceDetail(id: UUID) {
        book.paymentAcceptanceDetails.removeAll { $0.id == id }
        for index in book.invoices.indices {
            book.invoices[index].acceptedPaymentDetailIDs.removeAll { $0 == id }
        }
        save()
    }

    func invoiceBinding(id: UUID) -> Binding<Invoice>? {
        guard let fallback = book.invoices.first(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: {
                self.book.invoices.first(where: { $0.id == id }) ?? fallback
            },
            set: { newValue in
                guard let index = self.book.invoices.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.book.invoices[index] = newValue
                self.book.invoices[index].updatedAt = Date()
                self.save()
            }
        )
    }

    func clientBinding(id: UUID) -> Binding<Client>? {
        guard let fallback = book.clients.first(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: {
                self.book.clients.first(where: { $0.id == id }) ?? fallback
            },
            set: { newValue in
                guard let index = self.book.clients.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.book.clients[index] = newValue
                self.book.clients[index].updatedAt = Date()
                self.save()
            }
        )
    }

    func projectBinding(id: UUID) -> Binding<Project>? {
        guard let fallback = book.projects.first(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: {
                self.book.projects.first(where: { $0.id == id }) ?? fallback
            },
            set: { newValue in
                guard let index = self.book.projects.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.book.projects[index] = newValue
                self.book.projects[index].updatedAt = Date()
                self.save()
            }
        )
    }

    private func defaultPaymentAcceptanceLabel(for kind: PaymentAcceptanceKind) -> String {
        switch kind {
        case .bankDetails:
            return "Bank account"
        case .cryptocurrency:
            return "Crypto wallet"
        }
    }
}

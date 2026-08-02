import AppKit
import Foundation
import InvoiceCore

enum AppPersistenceError: LocalizedError {
    case storeWasNotLoaded
    case committedEntityMissing

    var errorDescription: String? {
        switch self {
        case .storeWasNotLoaded:
            return "Local Invoice did not save because the local store could not be loaded. Fix or reload the store file before saving, or use Seed Sample Data to intentionally replace it."
        case .committedEntityMissing:
            return "The saved item could not be reloaded."
        }
    }
}

extension AppModel {
    func beginNewInvoice(now: Date = Date()) {
        clearTransientEditorInputIssues(for: .invoice)
        let dueDays = book.businessProfile.paymentTermsDays
        let invoice = Invoice(
            number: book.nextInvoiceNumber(date: now),
            clientId: book.clients.first?.id,
            issueDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: dueDays, to: now) ?? now,
            currencyCode: book.businessProfile.currencyCode,
            lineItems: [
                InvoiceLineItem(title: "Professional services", quantity: 1, unitPriceMinorUnits: 0)
            ],
            terms: "Net \(dueDays)."
        )
        invoiceDraft = DraftSession(origin: .new, baseline: invoice, value: invoice)
        activeDraftRoute = .invoice
        selectedSection = .invoices
        selectedInvoiceID = nil
    }

    func beginEditingInvoice(id: UUID) {
        guard let invoice = book.invoices.first(where: { $0.id == id }) else { return }
        clearTransientEditorInputIssues(for: .invoice)
        invoiceDraft = DraftSession(origin: .persisted, baseline: invoice, value: invoice)
        activeDraftRoute = .invoice
        selectedSection = .invoices
        selectedInvoiceID = id
    }

    func commitInvoiceDraft(now: Date = Date()) throws {
        guard var session = invoiceDraft else { return }
        var candidate = book
        let savedInvoice = session.value

        var issues = EditorValidator.invoiceIssues(for: savedInvoice, in: book)
        for issue in transientInputIssues(for: .invoice)
        where !issues.contains(where: { $0.field == issue.field }) {
            issues.append(issue)
        }
        guard issues.isEmpty else {
            throw EditorCommitError(issues: issues)
        }

        if let index = candidate.invoices.firstIndex(where: { $0.id == savedInvoice.id }) {
            candidate.invoices[index] = savedInvoice
        } else {
            candidate.invoices.insert(savedInvoice, at: 0)
        }

        try applyPersistedCandidate(candidate, now: now)
        guard let committed = book.invoices.first(where: { $0.id == savedInvoice.id }) else {
            throw AppPersistenceError.committedEntityMissing
        }
        session.markCommitted(committed)
        invoiceDraft = session
        clearTransientEditorInputIssues(for: .invoice)
        activeDraftRoute = .invoice
        selectedInvoiceID = committed.id
    }

    func cancelInvoiceDraft() {
        guard let session = invoiceDraft else { return }
        invoiceDraft = nil
        clearTransientEditorInputIssues(for: .invoice)
        clearActiveDraftRoute(.invoice)
        selectedSection = .invoices
        selectedInvoiceID = session.origin == .persisted ? session.baseline.id : nil
    }

    func beginNewClient() {
        clearTransientEditorInputIssues(for: .client)
        let client = Client(name: "New Client")
        clientDraft = DraftSession(origin: .new, baseline: client, value: client)
        activeDraftRoute = .client
        selectedSection = .clients
        selectedClientID = nil
    }

    func beginEditingClient(id: UUID) {
        guard let client = book.clients.first(where: { $0.id == id }) else { return }
        clearTransientEditorInputIssues(for: .client)
        clientDraft = DraftSession(origin: .persisted, baseline: client, value: client)
        activeDraftRoute = .client
        selectedSection = .clients
        selectedClientID = id
    }

    func commitClientDraft(now: Date = Date()) throws {
        guard var session = clientDraft else { return }
        var candidate = book
        var savedClient = session.value

        let issues = EditorValidator.clientIssues(for: savedClient)
        guard issues.isEmpty else {
            throw EditorCommitError(issues: issues)
        }
        savedClient.updatedAt = now

        if let index = candidate.clients.firstIndex(where: { $0.id == savedClient.id }) {
            candidate.clients[index] = savedClient
        } else {
            candidate.clients.insert(savedClient, at: 0)
        }

        try applyPersistedCandidate(candidate, now: now)
        guard let committed = book.clients.first(where: { $0.id == savedClient.id }) else {
            throw AppPersistenceError.committedEntityMissing
        }
        session.markCommitted(committed)
        clientDraft = session
        clearTransientEditorInputIssues(for: .client)
        activeDraftRoute = .client
        selectedClientID = committed.id
    }

    func cancelClientDraft() {
        guard let session = clientDraft else { return }
        clientDraft = nil
        clearTransientEditorInputIssues(for: .client)
        clearActiveDraftRoute(.client)
        selectedSection = .clients
        selectedClientID = session.origin == .persisted ? session.baseline.id : nil
    }

    func beginNewProject() {
        clearTransientEditorInputIssues(for: .project)
        let project = Project(
            clientId: book.clients.first?.id,
            name: "New Project",
            currencyCode: book.businessProfile.currencyCode
        )
        projectDraft = DraftSession(origin: .new, baseline: project, value: project)
        activeDraftRoute = .project
        selectedSection = .projects
        selectedProjectID = nil
    }

    func beginEditingProject(id: UUID) {
        guard let project = book.projects.first(where: { $0.id == id }) else { return }
        clearTransientEditorInputIssues(for: .project)
        projectDraft = DraftSession(origin: .persisted, baseline: project, value: project)
        activeDraftRoute = .project
        selectedSection = .projects
        selectedProjectID = id
    }

    func commitProjectDraft(now: Date = Date()) throws {
        guard var session = projectDraft else { return }
        var candidate = book
        var savedProject = session.value

        var issues = EditorValidator.projectIssues(for: savedProject)
        for issue in transientInputIssues(for: .project)
        where !issues.contains(where: { $0.field == issue.field }) {
            issues.append(issue)
        }
        guard issues.isEmpty else {
            throw EditorCommitError(issues: issues)
        }
        savedProject.updatedAt = now

        if let index = candidate.projects.firstIndex(where: { $0.id == savedProject.id }) {
            candidate.projects[index] = savedProject
        } else {
            candidate.projects.insert(savedProject, at: 0)
        }

        try applyPersistedCandidate(candidate, now: now)
        guard let committed = book.projects.first(where: { $0.id == savedProject.id }) else {
            throw AppPersistenceError.committedEntityMissing
        }
        session.markCommitted(committed)
        projectDraft = session
        clearTransientEditorInputIssues(for: .project)
        activeDraftRoute = .project
        selectedProjectID = committed.id
    }

    func cancelProjectDraft() {
        guard let session = projectDraft else { return }
        projectDraft = nil
        clearTransientEditorInputIssues(for: .project)
        clearActiveDraftRoute(.project)
        selectedSection = .projects
        selectedProjectID = session.origin == .persisted ? session.baseline.id : nil
    }

    func beginEditingSettings() {
        clearTransientEditorInputIssues(for: .settings)
        let value = WorkspaceSettingsDraft(
            businessProfile: book.businessProfile,
            paymentAcceptanceDetails: book.paymentAcceptanceDetails
        )
        settingsDraft = DraftSession(origin: .persisted, baseline: value, value: value)
        activeDraftRoute = .settings
    }

    func commitSettingsDraft(now: Date = Date()) throws {
        guard var session = settingsDraft else { return }
        var candidate = book
        let savedSettings = session.value

        let issues = EditorValidator.settingsIssues(for: savedSettings)
        guard issues.isEmpty else {
            throw EditorCommitError(issues: issues)
        }
        candidate.businessProfile = savedSettings.businessProfile
        candidate.paymentAcceptanceDetails = savedSettings.paymentAcceptanceDetails

        try applyPersistedCandidate(candidate, now: now)
        let committed = WorkspaceSettingsDraft(
            businessProfile: book.businessProfile,
            paymentAcceptanceDetails: book.paymentAcceptanceDetails
        )
        session.markCommitted(committed)
        settingsDraft = session
        clearTransientEditorInputIssues(for: .settings)
        activeDraftRoute = .settings
    }

    func cancelSettingsDraft() {
        settingsDraft = nil
        clearTransientEditorInputIssues(for: .settings)
        clearActiveDraftRoute(.settings)
    }

    func commitActiveDraft(now: Date = Date()) throws {
        switch activeDraftKind {
        case .invoice:
            try commitInvoiceDraft(now: now)
        case .client:
            try commitClientDraft(now: now)
        case .project:
            try commitProjectDraft(now: now)
        case .settings:
            try commitSettingsDraft(now: now)
        case nil:
            return
        }
    }

    func cancelActiveDraft() {
        switch activeDraftKind {
        case .invoice:
            cancelInvoiceDraft()
        case .client:
            cancelClientDraft()
        case .project:
            cancelProjectDraft()
        case .settings:
            cancelSettingsDraft()
        case nil:
            return
        }
    }

    func requestNavigation(to intent: NavigationIntent, preserveCurrentDraft: Bool = false) {
        if preserveCurrentDraft {
            if invoiceDraft != nil {
                contextualReturnSection = .invoices
            }
            pendingNavigation = nil
            dirtyDraftRequiringDecision = nil
            continueNavigation(to: intent)
            return
        }

        guard let dirtyDraftKind = activeDirtyDraftKind else {
            continueNavigation(to: intent)
            return
        }

        pendingNavigation = intent
        dirtyDraftRequiringDecision = dirtyDraftKind
    }

    func discardDirtyDraftsAndContinue() {
        guard let intent = pendingNavigation else { return }
        invoiceDraft = nil
        clientDraft = nil
        projectDraft = nil
        settingsDraft = nil
        activeDraftRoute = nil
        pendingNavigation = nil
        dirtyDraftRequiringDecision = nil
        contextualReturnSection = nil
        clearAllTransientEditorInputIssues()
        continueNavigation(to: intent)
    }

    func cancelPendingNavigation() {
        pendingNavigation = nil
        dirtyDraftRequiringDecision = nil
    }

    func updateTransientEditorInputValidity(
        field: EditorField,
        isValid: Bool,
        invalidMessage: String
    ) {
        if isValid {
            transientEditorInputIssues.removeValue(forKey: field)
        } else {
            transientEditorInputIssues[field] = invalidMessage
        }
    }

    func transientEditorInputIssue(for field: EditorField) -> EditorIssue? {
        guard let message = transientEditorInputIssues[field] else { return nil }
        return EditorIssue(field: field, message: message)
    }

    func transientInputIssues(for kind: DraftKind) -> [EditorIssue] {
        transientEditorInputIssues.compactMap { field, message in
            guard draftKind(for: field) == kind else { return nil }
            return EditorIssue(field: field, message: message)
        }
        .sorted { String(describing: $0.field) < String(describing: $1.field) }
    }

    func hasTransientEditorInputIssue(for kind: DraftKind) -> Bool {
        transientEditorInputIssues.keys.contains { draftKind(for: $0) == kind }
    }

    func clearTransientEditorInputIssue(for field: EditorField) {
        transientEditorInputIssues.removeValue(forKey: field)
    }

    func clearTransientEditorInputIssues(for kind: DraftKind) {
        transientEditorInputIssues = transientEditorInputIssues.filter {
            draftKind(for: $0.key) != kind
        }
    }

    func clearAllTransientEditorInputIssues() {
        transientEditorInputIssues.removeAll()
    }

    func addInvoice() {
        beginNewInvoice()
    }

    func addClient() {
        beginNewClient()
    }

    func addProject() {
        beginNewProject()
    }

    func addPaymentAcceptanceDetail(kind: PaymentAcceptanceKind) {
        if settingsDraft == nil {
            beginEditingSettings()
        }
        let detail = PaymentAcceptanceDetail(
            kind: kind,
            label: defaultPaymentAcceptanceLabel(for: kind),
            details: ""
        )
        settingsDraft?.value.paymentAcceptanceDetails.append(detail)
    }

    func deleteSelectedInvoice() {
        guard let id = selectedInvoiceID else { return }
        var candidate = book
        candidate.invoices.removeAll { $0.id == id }

        do {
            try applyPersistedCandidate(candidate)
            if invoiceDraft?.value.id == id {
                invoiceDraft = nil
                clearTransientEditorInputIssues(for: .invoice)
                clearActiveDraftRoute(.invoice)
            }
            selectedInvoiceID = book.invoices.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedClient() {
        guard let id = selectedClientID else { return }
        var candidate = book
        candidate.clients.removeAll { $0.id == id }
        for index in candidate.invoices.indices where candidate.invoices[index].clientId == id {
            candidate.invoices[index].clientId = nil
        }
        for index in candidate.projects.indices where candidate.projects[index].clientId == id {
            candidate.projects[index].clientId = nil
        }

        do {
            try applyPersistedCandidate(candidate)
            if clientDraft?.value.id == id {
                clientDraft = nil
                clearTransientEditorInputIssues(for: .client)
                clearActiveDraftRoute(.client)
            }
            reconcileDeletedClient(id)
            selectedClientID = book.clients.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedProject() {
        guard let id = selectedProjectID else { return }
        var candidate = book
        candidate.projects.removeAll { $0.id == id }
        for index in candidate.invoices.indices where candidate.invoices[index].projectId == id {
            candidate.invoices[index].projectId = nil
        }

        do {
            try applyPersistedCandidate(candidate)
            if projectDraft?.value.id == id {
                projectDraft = nil
                clearTransientEditorInputIssues(for: .project)
                clearActiveDraftRoute(.project)
            }
            reconcileDeletedProject(id)
            selectedProjectID = book.projects.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePaymentAcceptanceDetail(id: UUID) {
        var candidate = book
        candidate.paymentAcceptanceDetails.removeAll { $0.id == id }
        for index in candidate.invoices.indices {
            candidate.invoices[index].acceptedPaymentDetailIDs.removeAll { $0 == id }
        }

        do {
            try applyPersistedCandidate(candidate)
            reconcileDeletedPaymentAcceptanceDetail(id)
            if var session = settingsDraft {
                session.baseline.paymentAcceptanceDetails.removeAll { $0.id == id }
                session.value.paymentAcceptanceDetails.removeAll { $0.id == id }
                settingsDraft = session
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var activeDraftKind: DraftKind? {
        if let activeDraftRoute, draftExists(for: activeDraftRoute) {
            return activeDraftRoute
        }

        switch selectedSection {
        case .invoices where invoiceDraft != nil:
            return .invoice
        case .clients where clientDraft != nil:
            return .client
        case .projects where projectDraft != nil:
            return .project
        default:
            if settingsDraft != nil { return .settings }
            if invoiceDraft != nil { return .invoice }
            if clientDraft != nil { return .client }
            if projectDraft != nil { return .project }
            return nil
        }
    }

    private var activeDirtyDraftKind: DraftKind? {
        if let activeDraftKind, isDraftDirty(activeDraftKind) {
            return activeDraftKind
        }
        if isDraftDirty(.invoice) { return .invoice }
        if isDraftDirty(.client) { return .client }
        if isDraftDirty(.project) { return .project }
        if isDraftDirty(.settings) { return .settings }
        return nil
    }

    private func persistedCandidate(
        _ candidate: InvoiceBook,
        now: Date = Date()
    ) throws -> InvoiceBook {
        guard loadedStoreSuccessfully else {
            throw AppPersistenceError.storeWasNotLoaded
        }

        var candidate = candidate
        candidate.generateAutomaticInvoices(now: now)
        candidate.refreshInvoiceStatuses(now: now)
        try store.save(candidate)
        return candidate
    }

    private func applyPersistedCandidate(
        _ candidate: InvoiceBook,
        now: Date = Date()
    ) throws {
        let persisted = try persistedCandidate(candidate, now: now)
        book = persisted
        loadedStoreSuccessfully = true
        errorMessage = nil
        scheduleAutomaticGenerationCheck(now: now)
    }

    private func continueNavigation(to intent: NavigationIntent) {
        switch intent {
        case let .section(section):
            selectedSection = section
        case let .invoice(id):
            selectedSection = .invoices
            selectedInvoiceID = id
        case let .client(id):
            selectedSection = .clients
            selectedClientID = id
        case let .project(id):
            selectedSection = .projects
            selectedProjectID = id
        case .closeWindow:
            NSApp.keyWindow?.performClose(nil)
        }
    }

    private func draftExists(for kind: DraftKind) -> Bool {
        switch kind {
        case .invoice:
            return invoiceDraft != nil
        case .client:
            return clientDraft != nil
        case .project:
            return projectDraft != nil
        case .settings:
            return settingsDraft != nil
        }
    }

    private func isDraftDirty(_ kind: DraftKind) -> Bool {
        switch kind {
        case .invoice:
            return invoiceDraft?.isDirty == true || hasTransientEditorInputIssue(for: .invoice)
        case .client:
            return clientDraft?.isDirty == true || hasTransientEditorInputIssue(for: .client)
        case .project:
            return projectDraft?.isDirty == true || hasTransientEditorInputIssue(for: .project)
        case .settings:
            return settingsDraft?.isDirty == true || hasTransientEditorInputIssue(for: .settings)
        }
    }

    private func clearActiveDraftRoute(_ kind: DraftKind) {
        guard activeDraftRoute == kind else { return }

        if kind == .settings,
           contextualReturnSection == .invoices,
           invoiceDraft != nil {
            activeDraftRoute = .invoice
        } else {
            activeDraftRoute = nil
        }
    }

    private func reconcileDeletedClient(_ id: UUID) {
        if var session = invoiceDraft {
            if session.baseline.clientId == id {
                session.baseline.clientId = nil
            }
            if session.value.clientId == id {
                session.value.clientId = nil
            }
            invoiceDraft = session
        }

        if var session = projectDraft {
            if session.baseline.clientId == id {
                session.baseline.clientId = nil
            }
            if session.value.clientId == id {
                session.value.clientId = nil
            }
            projectDraft = session
        }
    }

    private func reconcileDeletedProject(_ id: UUID) {
        guard var session = invoiceDraft else { return }
        if session.baseline.projectId == id {
            session.baseline.projectId = nil
        }
        if session.value.projectId == id {
            session.value.projectId = nil
        }
        invoiceDraft = session
    }

    private func reconcileDeletedPaymentAcceptanceDetail(_ id: UUID) {
        guard var session = invoiceDraft else { return }
        session.baseline.acceptedPaymentDetailIDs.removeAll { $0 == id }
        session.value.acceptedPaymentDetailIDs.removeAll { $0 == id }
        invoiceDraft = session
    }

    private func draftKind(for field: EditorField) -> DraftKind {
        switch field {
        case .invoiceNumber,
             .invoiceDueDate,
             .invoiceCurrency,
             .automaticGenerationInterval,
             .lineItemTitle(_),
             .lineItemQuantity(_),
             .lineItemUnitPrice(_),
             .lineItemTaxRate(_):
            return .invoice
        case .clientName:
            return .client
        case .projectName, .projectHourlyRate:
            return .project
        case .businessCurrency, .paymentTermsDays, .paymentDetailLabel(_):
            return .settings
        }
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

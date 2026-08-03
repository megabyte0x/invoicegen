import XCTest
import InvoiceCore
@testable import InvoiceGenApp

final class DraftEditingTests: XCTestCase {
    @MainActor
    func testNewInvoiceDoesNotPersistUntilCommit() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)

        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(try store.load().invoices.isEmpty)
        try model.commitInvoiceDraft()
        XCTAssertEqual(try store.load().invoices.count, 1)
    }

    @MainActor
    func testCancelNewClientLeavesBookAndStoreUnchanged() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)

        model.beginNewClient()
        model.clientDraft?.value.name = "Discard Me"
        model.cancelClientDraft()

        XCTAssertTrue(model.book.clients.isEmpty)
        XCTAssertTrue(try store.load().clients.isEmpty)
    }

    @MainActor
    func testFailedCommitLeavesBookAndStoreAtBaseline() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let regularFileURL = rootURL.appendingPathComponent("not-a-directory")
        try Data("block writes below this file".utf8).write(to: regularFileURL)

        let store = LocalInvoiceStore(
            url: regularFileURL.appendingPathComponent("store.json")
        )
        let model = AppModel(store: store)
        let baselineBook = model.book
        let baselineStore = try store.load()

        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))

        XCTAssertThrowsError(try model.commitInvoiceDraft())
        XCTAssertEqual(model.book, baselineBook)
        XCTAssertEqual(try store.load(), baselineStore)
    }

    @MainActor
    func testDirtyDraftDefersSectionNavigation() {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Unsaved navigation guard"

        model.requestNavigation(to: .section(.clients))

        XCTAssertEqual(model.selectedSection, .invoices)
        XCTAssertEqual(model.pendingNavigation, .section(.clients))
        XCTAssertEqual(model.dirtyDraftRequiringDecision, .invoice)
    }

    @MainActor
    func testSameKindNewInvoiceWaitsForDirtyDraftDecision() throws {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Do not replace"
        let originalID = try XCTUnwrap(model.invoiceDraft?.value.id)

        model.requestNavigation(to: .newInvoice)

        XCTAssertEqual(model.invoiceDraft?.value.id, originalID)
        XCTAssertEqual(model.pendingNavigation, .newInvoice)
        XCTAssertEqual(model.dirtyDraftRequiringDecision, .invoice)

        model.discardDirtyDraftsAndContinue()

        XCTAssertNotEqual(model.invoiceDraft?.value.id, originalID)
        XCTAssertNil(model.pendingNavigation)
    }

    @MainActor
    func testDiscardPromptsAgainForAnotherDirtyDraft() {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Dirty invoice"
        model.beginEditingSettings()
        model.settingsDraft?.value.businessProfile.name = "Dirty settings"

        model.requestNavigation(to: .section(.clients))
        XCTAssertEqual(model.dirtyDraftRequiringDecision, .invoice)

        model.discardDirtyDraftsAndContinue()

        XCTAssertNil(model.invoiceDraft)
        XCTAssertNotNil(model.settingsDraft)
        XCTAssertEqual(model.pendingNavigation, .section(.clients))
        XCTAssertEqual(model.dirtyDraftRequiringDecision, .settings)
        XCTAssertEqual(model.selectedSection, .invoices)

        model.discardDirtyDraftsAndContinue()

        XCTAssertNil(model.settingsDraft)
        XCTAssertNil(model.pendingNavigation)
        XCTAssertEqual(model.selectedSection, .clients)
    }

    @MainActor
    func testActionDismissalRepresentsSaveAndRequeueNavigationAlert() throws {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Save this invoice"
        model.beginEditingSettings()
        model.settingsDraft?.value.businessProfile.name = "Unsaved settings"
        model.activeDraftRoute = .invoice
        model.requestNavigation(to: .section(.clients))

        var coordinator = PendingNavigationAlertCoordinator()
        coordinator.synchronize(hasPendingNavigation: model.pendingNavigation != nil)
        coordinator.beginActionDrivenDismissal()

        let intent = try XCTUnwrap(model.pendingNavigation)
        try model.commitDraft(.invoice, now: Date(timeIntervalSince1970: 0))
        model.cancelPendingNavigation()
        model.requestNavigation(to: intent)

        XCTAssertEqual(model.dirtyDraftRequiringDecision, .settings)
        coordinator.presentationChanged(to: false)
        XCTAssertFalse(coordinator.isPresented)
        XCTAssertEqual(coordinator.dismissalGeneration, 1)

        XCTAssertEqual(
            coordinator.resolveDismissal(
                hasPendingNavigation: model.pendingNavigation != nil
            ),
            .preservePendingNavigation
        )

        XCTAssertTrue(coordinator.isPresented)
        XCTAssertEqual(model.pendingNavigation, .section(.clients))
    }

    @MainActor
    func testActionDismissalRepresentsMultiDraftDiscardAlert() {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Discard this invoice"
        model.beginEditingSettings()
        model.settingsDraft?.value.businessProfile.name = "Still unsaved"
        model.activeDraftRoute = .invoice
        model.requestNavigation(to: .section(.clients))

        var coordinator = PendingNavigationAlertCoordinator()
        coordinator.synchronize(hasPendingNavigation: model.pendingNavigation != nil)
        coordinator.presentationChanged(to: false)
        coordinator.beginActionDrivenDismissal()
        model.discardDirtyDraftsAndContinue()

        XCTAssertEqual(model.dirtyDraftRequiringDecision, .settings)
        XCTAssertFalse(coordinator.isPresented)
        XCTAssertEqual(coordinator.dismissalGeneration, 1)

        XCTAssertEqual(
            coordinator.resolveDismissal(
                hasPendingNavigation: model.pendingNavigation != nil
            ),
            .preservePendingNavigation
        )

        XCTAssertTrue(coordinator.isPresented)
        XCTAssertEqual(model.pendingNavigation, .section(.clients))
    }

    func testPassiveNavigationAlertDismissalCancelsPendingTransition() {
        var coordinator = PendingNavigationAlertCoordinator()
        coordinator.synchronize(hasPendingNavigation: true)
        coordinator.presentationChanged(to: false)

        XCTAssertEqual(
            coordinator.resolveDismissal(hasPendingNavigation: true),
            .cancelPendingNavigation
        )
        XCTAssertFalse(coordinator.isPresented)
    }

    @MainActor
    func testSettingsSessionLifecycleDoesNotReplaceMainDraftRoute() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.activeDraftRoute = .invoice

        model.beginEditingSettings()
        XCTAssertEqual(model.activeDraftRoute, .invoice)

        try model.commitSettingsDraft()
        XCTAssertEqual(model.activeDraftRoute, .invoice)
    }

    @MainActor
    func testContextualClientNavigationPreservesInvoiceDraft() throws {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        model.beginNewInvoice(now: Date(timeIntervalSince1970: 0))
        model.invoiceDraft?.value.notes = "Keep this invoice draft"
        let invoiceDraft = try XCTUnwrap(model.invoiceDraft?.value)

        model.requestNavigation(to: .section(.clients), preserveCurrentDraft: true)

        XCTAssertEqual(model.invoiceDraft?.value, invoiceDraft)
        XCTAssertEqual(model.contextualReturnSection, .invoices)
    }

    @MainActor
    func testCancelSettingsDraftRestoresBusinessAndPaymentBaseline() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        let baselineBook = model.book
        let baselineStore = try store.load()

        model.beginEditingSettings()
        model.settingsDraft?.value.businessProfile.name = "Discarded Business"
        model.settingsDraft?.value.paymentAcceptanceDetails.append(
            PaymentAcceptanceDetail(
                kind: .bankDetails,
                label: "Discarded bank account"
            )
        )
        model.cancelSettingsDraft()

        XCTAssertEqual(model.book, baselineBook)
        XCTAssertEqual(try store.load(), baselineStore)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("store.json")
    }
}

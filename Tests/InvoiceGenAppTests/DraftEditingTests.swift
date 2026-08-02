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

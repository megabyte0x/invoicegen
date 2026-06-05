import XCTest
@testable import InvoiceGenApp
@testable import InvoiceCore

@MainActor
final class AppModelBindingTests: XCTestCase {
    func testEntityBindingsRemainSafeIfEntityIsDeletedBeforeSwiftUIRefreshes() throws {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        let invoice = Invoice(number: "INV-DELETE", dueDate: Date())
        let client = Client(name: "Delete Me")
        let project = Project(name: "Delete Me")

        model.book.invoices = [invoice]
        model.book.clients = [client]
        model.book.projects = [project]
        model.selectedInvoiceID = invoice.id
        model.selectedClientID = client.id
        model.selectedProjectID = project.id

        let invoiceBinding = try XCTUnwrap(model.invoiceBinding(id: invoice.id))
        let clientBinding = try XCTUnwrap(model.clientBinding(id: client.id))
        let projectBinding = try XCTUnwrap(model.projectBinding(id: project.id))

        model.deleteSelectedInvoice()
        model.deleteSelectedClient()
        model.deleteSelectedProject()

        XCTAssertEqual(invoiceBinding.wrappedValue.id, invoice.id)
        XCTAssertEqual(clientBinding.wrappedValue.id, client.id)
        XCTAssertEqual(projectBinding.wrappedValue.id, project.id)
    }

    func testNormalSaveDoesNotOverwriteStoreAfterLoadFailure() throws {
        let url = temporaryStoreURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)

        let model = AppModel(store: LocalInvoiceStore(url: url))
        XCTAssertNotNil(model.errorMessage)

        model.book = .sample()
        model.save()

        let persisted = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(persisted, "not valid json")
    }

    func testDeletingClientUnassignsRelatedProjectsAndInvoices() {
        let model = AppModel(store: LocalInvoiceStore(url: temporaryStoreURL()))
        let client = Client(name: "Acme")
        let project = Project(clientId: client.id, name: "Launch")
        let invoice = Invoice(number: "INV-CLIENT", clientId: client.id, projectId: project.id, dueDate: Date())

        model.book.clients = [client]
        model.book.projects = [project]
        model.book.invoices = [invoice]
        model.selectedClientID = client.id

        model.deleteSelectedClient()

        XCTAssertNil(model.book.projects.first?.clientId)
        XCTAssertNil(model.book.invoices.first?.clientId)
    }

    func testSaveGeneratesAndPersistsDueAutomaticInvoices() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        let generationDate = Date(timeIntervalSince1970: 0)
        let sourceInvoice = Invoice(
            number: "INV-1970-0001",
            issueDate: generationDate.addingTimeInterval(-86_400),
            dueDate: generationDate,
            lineItems: [
                InvoiceLineItem(title: "Retainer", unitPriceMinorUnits: 10_000)
            ],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalDays: 1,
                nextGenerationDate: generationDate
            )
        )
        model.book.invoices = [sourceInvoice]

        model.save(now: generationDate)

        let loaded = try store.load()
        XCTAssertEqual(loaded.invoices.count, 2)
        XCTAssertEqual(loaded.invoices.last?.number, "INV-1970-0002")
        XCTAssertEqual(loaded.invoices.last?.status, .draft)
        XCTAssertFalse(loaded.invoices.last?.autoGeneration.isEnabled ?? true)
    }

    func testSaveSchedulesNextAutomaticGenerationCheck() {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        let nextGenerationDate = now.addingTimeInterval(10)
        let sourceInvoice = Invoice(
            number: "INV-1970-0001",
            issueDate: now,
            dueDate: now,
            lineItems: [
                InvoiceLineItem(title: "Retainer", unitPriceMinorUnits: 10_000)
            ],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalDays: 1,
                nextGenerationDate: nextGenerationDate
            )
        )
        model.book.invoices = [sourceInvoice]

        model.save(now: now)

        XCTAssertEqual(model.automaticGenerationCheckScheduledFor, nextGenerationDate)
    }

    func testScheduledAutomaticGenerationCheckPersistsDueInvoicesWithoutManualSave() throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        let generationDate = Date(timeIntervalSince1970: 1_000)
        let sourceInvoice = Invoice(
            number: "INV-1970-0001",
            issueDate: generationDate.addingTimeInterval(-86_400),
            dueDate: generationDate,
            lineItems: [
                InvoiceLineItem(title: "Retainer", unitPriceMinorUnits: 10_000)
            ],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalDays: 1,
                nextGenerationDate: generationDate
            )
        )
        model.book.invoices = [sourceInvoice]

        model.runScheduledAutomaticGenerationCheck(now: generationDate)

        let loaded = try store.load()
        XCTAssertEqual(loaded.invoices.count, 2)
        XCTAssertEqual(loaded.invoices.last?.number, "INV-1970-0002")
        XCTAssertEqual(model.automaticGenerationCheckScheduledFor, generationDate.addingTimeInterval(86_400))
    }

    func testAutomaticGenerationTimerFiresWithoutManualSaveOrInteraction() async throws {
        let store = LocalInvoiceStore(url: temporaryStoreURL())
        let model = AppModel(store: store)
        let now = Date()
        let generationDate = now.addingTimeInterval(0.1)
        let sourceInvoice = Invoice(
            number: "INV-1970-0001",
            issueDate: now.addingTimeInterval(-86_400),
            dueDate: now,
            lineItems: [
                InvoiceLineItem(title: "Retainer", unitPriceMinorUnits: 10_000)
            ],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalDays: 1,
                nextGenerationDate: generationDate
            )
        )
        model.book.invoices = [sourceInvoice]

        model.save(now: now)
        try await Task.sleep(nanoseconds: 800_000_000)

        let loaded = try store.load()
        XCTAssertEqual(loaded.invoices.count, 2)
        XCTAssertEqual(loaded.invoices.last?.status, .draft)
        XCTAssertFalse(loaded.invoices.last?.autoGeneration.isEnabled ?? true)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("store.json")
    }
}

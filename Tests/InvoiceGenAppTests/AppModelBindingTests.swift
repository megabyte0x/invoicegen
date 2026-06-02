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

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("store.json")
    }
}

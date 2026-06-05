import XCTest
@testable import InvoiceCore

final class InvoiceCoreTests: XCTestCase {
    func testMoneyParsingAndFormatting() throws {
        XCTAssertEqual(try Money.parseMinorUnits("1,234.50"), 123450)
        XCTAssertEqual(Money.format(minorUnits: 123450, currencyCode: "USD"), "USD 1234.50")
        XCTAssertThrowsError(try Money.parseMinorUnits("12.345"))
    }

    func testInvoiceTotalsAndPaidStatus() {
        var invoice = Invoice(
            number: "INV-2026-0001",
            dueDate: Date(),
            lineItems: [
                InvoiceLineItem(title: "Work", quantity: 2, unitPriceMinorUnits: 10000, taxRatePercent: 10)
            ]
        )

        XCTAssertEqual(invoice.subtotalMinorUnits, 20000)
        XCTAssertEqual(invoice.taxMinorUnits, 2000)
        XCTAssertEqual(invoice.totalMinorUnits, 22000)

        invoice.payments.append(Payment(amountMinorUnits: 22000))
        invoice.refreshStatus()
        XCTAssertEqual(invoice.status, .paid)
        XCTAssertEqual(invoice.balanceDueMinorUnits, 0)
    }

    func testPaidInvoiceCanBeMarkedUnpaid() {
        let now = Date(timeIntervalSince1970: 0)
        var invoice = Invoice(
            number: "INV-2026-0002",
            dueDate: now.addingTimeInterval(86_400),
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 10000)
            ]
        )

        invoice.payments.append(Payment(amountMinorUnits: 10000, paidAt: now))
        invoice.refreshStatus(now: now)
        XCTAssertEqual(invoice.status, .paid)

        invoice.markUnpaid(now: now)

        XCTAssertEqual(invoice.payments, [])
        XCTAssertEqual(invoice.paidMinorUnits, 0)
        XCTAssertEqual(invoice.balanceDueMinorUnits, 10000)
        XCTAssertEqual(invoice.status, .sent)
    }

    func testOverdueInvoiceReturnsToSentWhenDueDateMovesForward() {
        let now = Date(timeIntervalSince1970: 0)
        var invoice = Invoice(
            number: "INV-2026-0003",
            dueDate: now.addingTimeInterval(86_400),
            status: .overdue,
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 10000)
            ]
        )

        invoice.refreshStatus(now: now)

        XCTAssertEqual(invoice.status, .sent)
    }

    func testAutomaticGenerationIntervalSecondsClampToSupportedRange() {
        XCTAssertEqual(InvoiceAutoGenerationSettings.normalizedIntervalSeconds(0), 1)
        XCTAssertEqual(InvoiceAutoGenerationSettings.normalizedIntervalSeconds(30), 30)
        XCTAssertEqual(InvoiceAutoGenerationSettings.normalizedIntervalSeconds(400_000_000), 315_360_000)
    }

    func testAutomaticGenerationNextDateIsDerivedFromIntervalSeconds() {
        let baseDate = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(
            InvoiceAutoGenerationSettings.nextGenerationDate(intervalSeconds: 7, from: baseDate),
            Date(timeIntervalSince1970: 7)
        )
        XCTAssertEqual(
            InvoiceAutoGenerationSettings.nextGenerationDate(intervalSeconds: 0, from: baseDate),
            Date(timeIntervalSince1970: 1)
        )
    }

    func testAutomaticGenerationSettingsEncodeIntervalSeconds() throws {
        let settings = InvoiceAutoGenerationSettings(
            isEnabled: true,
            intervalSeconds: 30,
            nextGenerationDate: Date(timeIntervalSince1970: 0)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(settings)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["intervalSeconds"] as? Int, 30)
        XCTAssertNil(json["intervalDays"])
    }

    func testAutomaticGenerationSettingsDecodeLegacyIntervalDaysAsSeconds() throws {
        let legacyJSON = """
        {
          "isEnabled": true,
          "intervalDays": 2,
          "nextGenerationDate": "1970-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let settings = try decoder.decode(InvoiceAutoGenerationSettings.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(settings.intervalSeconds, 172_800)
    }

    func testDueAutomaticGenerationCreatesDraftInvoiceCopyAndAdvancesSchedule() {
        let issueDate = date(year: 2026, month: 1, day: 1)
        let generationDate = date(year: 2026, month: 1, day: 8)
        let sourceInvoice = Invoice(
            number: "INV-2026-0001",
            clientId: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            projectId: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            issueDate: issueDate,
            dueDate: date(year: 2026, month: 1, day: 15),
            status: .sent,
            currencyCode: "USD",
            lineItems: [
                InvoiceLineItem(title: "Retainer", quantity: 1, unitPriceMinorUnits: 250_000)
            ],
            payments: [
                Payment(amountMinorUnits: 250_000, paidAt: issueDate)
            ],
            notes: "Monthly support",
            terms: "Net 14.",
            acceptedPaymentDetailIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000401")!],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalSeconds: 7 * 86_400,
                nextGenerationDate: generationDate
            )
        )
        var book = InvoiceBook(invoices: [sourceInvoice])

        let generated = book.generateAutomaticInvoices(now: date(year: 2026, month: 1, day: 9))

        XCTAssertEqual(generated.count, 1)
        XCTAssertEqual(book.invoices.count, 2)
        XCTAssertEqual(book.invoices[0].autoGeneration.nextGenerationDate, date(year: 2026, month: 1, day: 15))

        let generatedInvoice = book.invoices[1]
        XCTAssertEqual(generatedInvoice.number, "INV-2026-0002")
        XCTAssertEqual(generatedInvoice.issueDate, generationDate)
        XCTAssertEqual(generatedInvoice.dueDate, date(year: 2026, month: 1, day: 22))
        XCTAssertEqual(generatedInvoice.status, .draft)
        XCTAssertEqual(generatedInvoice.clientId, sourceInvoice.clientId)
        XCTAssertEqual(generatedInvoice.projectId, sourceInvoice.projectId)
        XCTAssertEqual(generatedInvoice.lineItems.map(\.title), ["Retainer"])
        XCTAssertEqual(generatedInvoice.payments, [])
        XCTAssertEqual(generatedInvoice.notes, "Monthly support")
        XCTAssertEqual(generatedInvoice.terms, "Net 14.")
        XCTAssertEqual(generatedInvoice.acceptedPaymentDetailIDs, sourceInvoice.acceptedPaymentDetailIDs)
        XCTAssertFalse(generatedInvoice.autoGeneration.isEnabled)
    }

    func testAutomaticGenerationCatchesUpMissedPeriodsWithoutGeneratingFromGeneratedCopies() {
        let sourceInvoice = Invoice(
            number: "INV-2026-0001",
            issueDate: date(year: 2026, month: 1, day: 1),
            dueDate: date(year: 2026, month: 1, day: 2),
            lineItems: [
                InvoiceLineItem(title: "Weekly service", unitPriceMinorUnits: 100_000)
            ],
            autoGeneration: InvoiceAutoGenerationSettings(
                isEnabled: true,
                intervalSeconds: 7 * 86_400,
                nextGenerationDate: date(year: 2026, month: 1, day: 8)
            )
        )
        var book = InvoiceBook(invoices: [sourceInvoice])

        let generated = book.generateAutomaticInvoices(now: date(year: 2026, month: 1, day: 23))

        XCTAssertEqual(generated.map(\.issueDate), [
            date(year: 2026, month: 1, day: 8),
            date(year: 2026, month: 1, day: 15),
            date(year: 2026, month: 1, day: 22)
        ])
        XCTAssertEqual(book.invoices.map(\.number), [
            "INV-2026-0001",
            "INV-2026-0002",
            "INV-2026-0003",
            "INV-2026-0004"
        ])
        XCTAssertEqual(book.invoices[0].autoGeneration.nextGenerationDate, date(year: 2026, month: 1, day: 29))
        XCTAssertEqual(book.invoices.dropFirst().filter { $0.autoGeneration.isEnabled }.count, 0)
    }

    func testLocalStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let store = LocalInvoiceStore(url: url)
        let book = InvoiceBook.sample()

        try store.save(book)
        let loaded = try store.load()

        XCTAssertEqual(loaded.clients.count, 2)
        XCTAssertEqual(loaded.projects.count, 1)
        XCTAssertEqual(loaded.invoices.count, 2)
    }

    func testLocalStoreKeepsBackupBeforeReplacingExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let backupURL = url.appendingPathExtension("bak")
        let store = LocalInvoiceStore(url: url)

        try store.save(InvoiceBook(businessProfile: BusinessProfile(name: "Original Business")))
        try store.save(InvoiceBook(businessProfile: BusinessProfile(name: "Updated Business")))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupBook = try decoder.decode(InvoiceBook.self, from: Data(contentsOf: backupURL))
        let loaded = try store.load()

        XCTAssertEqual(backupBook.businessProfile.name, "Original Business")
        XCTAssertEqual(loaded.businessProfile.name, "Updated Business")
    }

    func testLocalStoreRejectsInvalidInvoiceBookWithoutReplacingExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let store = LocalInvoiceStore(url: url)
        let validInvoice = Invoice(
            number: "INV-VALID",
            issueDate: Date(timeIntervalSince1970: 0),
            dueDate: Date(timeIntervalSince1970: 86_400),
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 10_000)
            ]
        )
        try store.save(InvoiceBook(businessProfile: BusinessProfile(name: "Valid Co"), invoices: [validInvoice]))

        let invalidInvoice = Invoice(
            number: "   ",
            issueDate: Date(timeIntervalSince1970: 86_400),
            dueDate: Date(timeIntervalSince1970: 0),
            currencyCode: "usd",
            lineItems: [
                InvoiceLineItem(title: "", quantity: 0, unitPriceMinorUnits: -1, taxRatePercent: -5)
            ]
        )

        XCTAssertThrowsError(try store.save(InvoiceBook(invoices: [invalidInvoice]))) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invoice number is required"), "\(error)")
            XCTAssertTrue(error.localizedDescription.contains("Due date cannot be before issue date"), "\(error)")
        }

        let loaded = try store.load()
        XCTAssertEqual(loaded.businessProfile.name, "Valid Co")
        XCTAssertEqual(loaded.invoices.first?.number, "INV-VALID")
    }

    func testLocalStoreExportsAndRestoresStoreFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let exportURL = directory.appendingPathComponent("backups/exported-store.json")
        let store = LocalInvoiceStore(url: url)

        try store.save(InvoiceBook(businessProfile: BusinessProfile(name: "Original Co")))
        try store.exportStore(to: exportURL)
        try store.save(InvoiceBook(businessProfile: BusinessProfile(name: "Changed Co")))
        try store.restoreStore(from: exportURL)

        let restored = try store.load()
        XCTAssertEqual(restored.businessProfile.name, "Original Co")
    }

    func testAppStoreOverrides() {
        let appURL = LocalInvoiceStore.defaultStoreURL(
            environment: ["INVOICEGEN_APP_STORE": "/tmp/invoicegen-app.json"]
        )

        XCTAssertEqual(appURL.path, "/tmp/invoicegen-app.json")
    }

    func testSelectedPaymentAcceptanceDetailsRoundTripAndRender() throws {
        let timestamp = Date(timeIntervalSince1970: 0)
        let bankDetails = PaymentAcceptanceDetail(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            kind: .bankDetails,
            label: "Primary bank account",
            details: "Account: 123456789\nRouting: 987654321",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let cryptoDetails = PaymentAcceptanceDetail(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            kind: .cryptocurrency,
            label: "USDC wallet",
            details: "USDC on Base: 0xabc123",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let invoice = Invoice(
            number: "INV-2026-0003",
            issueDate: timestamp,
            dueDate: timestamp.addingTimeInterval(86_400),
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 10000)
            ],
            acceptedPaymentDetailIDs: [bankDetails.id, cryptoDetails.id]
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let store = LocalInvoiceStore(url: url)
        let book = InvoiceBook(
            paymentAcceptanceDetails: [bankDetails, cryptoDetails],
            invoices: [invoice]
        )

        try store.save(book)
        let loaded = try store.load()

        XCTAssertEqual(loaded.paymentAcceptanceDetails, [bankDetails, cryptoDetails])
        XCTAssertEqual(loaded.invoices.first?.acceptedPaymentDetailIDs, [bankDetails.id, cryptoDetails.id])

        let rendered = InvoiceTextRenderer.render(invoice: invoice, book: loaded)
        XCTAssertTrue(rendered.contains("Payment Acceptance"))
        XCTAssertTrue(rendered.contains("Bank Details: Primary bank account"))
        XCTAssertTrue(rendered.contains("Cryptocurrency: USDC wallet"))
        XCTAssertTrue(rendered.contains("Account: 123456789"))
        XCTAssertTrue(rendered.contains("USDC on Base: 0xabc123"))
    }

    func testInvoiceTextRendererOmitsStatusFromClientFacingOutput() {
        let invoice = Invoice(
            number: "INV-NO-STATUS",
            dueDate: Date(timeIntervalSince1970: 0),
            status: .paid,
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 10000)
            ]
        )
        let book = InvoiceBook(invoices: [invoice])

        let rendered = InvoiceTextRenderer.render(invoice: invoice, book: book)

        XCTAssertTrue(rendered.contains("INVOICE INV-NO-STATUS"))
        XCTAssertFalse(rendered.contains("Status:"), rendered)
    }

    func testInvoicePDFFileNameUsesInvoiceNumber() {
        let invoice = Invoice(
            number: "INV 2026/0001",
            dueDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(InvoiceExportNaming.pdfFileName(for: invoice), "INV-2026-0001.pdf")
    }

    func testLegacyStoreWithoutPaymentAcceptanceDetailsDecodes() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "businessProfile": {
            "name": "Legacy Co",
            "email": "",
            "address": "",
            "taxIdentifier": "",
            "currencyCode": "USD",
            "paymentTermsDays": 14
          },
          "clients": [],
          "projects": [],
          "invoices": [
            {
              "id": "00000000-0000-0000-0000-000000000201",
              "number": "INV-LEGACY",
              "issueDate": "2026-01-01T00:00:00Z",
              "dueDate": "2026-01-15T00:00:00Z"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let book = try decoder.decode(InvoiceBook.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(book.paymentAcceptanceDetails, [])
        XCTAssertEqual(book.invoices.first?.acceptedPaymentDetailIDs, [])
        XCTAssertEqual(book.invoices.first?.autoGeneration, .disabled)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}

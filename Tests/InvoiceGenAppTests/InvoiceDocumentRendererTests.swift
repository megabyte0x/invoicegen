import AppKit
import InvoiceCore
@testable import InvoiceGenApp
import PDFKit
import XCTest

@MainActor
final class InvoiceDocumentRendererTests: XCTestCase {
    func testPDFDataRendersVisibleContentOnEveryPage() throws {
        let renderedDocument = try XCTUnwrap(
            PDFDocument(data: InvoiceDocumentRenderer.pdfData(document: twoPageDocument()))
        )

        XCTAssertEqual(renderedDocument.pageCount, 2)
        XCTAssertTrue(renderedDocument.page(at: 0)?.string?.contains("FIRST PAGE CONTENT") == true)
        XCTAssertTrue(renderedDocument.page(at: 1)?.string?.contains("SECOND PAGE CONTENT") == true)
    }

    func testWritePDFExportsEveryRenderedPageToDisk() throws {
        let document = twoPageDocument()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoiceGen-export-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try InvoiceDocumentRenderer.writePDF(document: document, to: outputURL)

        let exportedDocument = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertEqual(exportedDocument.pageCount, 2)
        XCTAssertEqual(exportedDocument.page(at: 0)?.bounds(for: .mediaBox).size, InvoiceDocument.pageSize)
        XCTAssertEqual(exportedDocument.page(at: 1)?.bounds(for: .mediaBox).size, InvoiceDocument.pageSize)
        XCTAssertTrue(exportedDocument.page(at: 0)?.string?.contains("FIRST PAGE CONTENT") == true)
        XCTAssertTrue(exportedDocument.page(at: 1)?.string?.contains("SECOND PAGE CONTENT") == true)
    }

    func testPDFRendersTaxCodeColumnAndLineItemValue() throws {
        let invoice = Invoice(
            number: "INV-TAX-CODE",
            dueDate: Date(timeIntervalSince1970: 0),
            lineItems: [
                InvoiceLineItem(
                    title: "Implementation",
                    taxCode: "SAC-998313",
                    unitPriceMinorUnits: 10_000
                )
            ]
        )
        let document = InvoiceDocumentPaginator.paginate(
            invoice: invoice,
            book: InvoiceBook(invoices: [invoice])
        )

        let renderedDocument = try XCTUnwrap(
            PDFDocument(data: InvoiceDocumentRenderer.pdfData(document: document))
        )
        let renderedText = (0..<renderedDocument.pageCount)
            .compactMap { renderedDocument.page(at: $0)?.string }
            .joined(separator: "\n")

        XCTAssertTrue(renderedText.contains("Code"), renderedText)
        XCTAssertTrue(renderedText.contains("SAC-998313"), renderedText)
    }

    private func twoPageDocument() -> InvoiceDocument {
        InvoiceDocument(
            pages: [
                textPage(id: 0, text: "FIRST PAGE CONTENT", currentPage: 1),
                textPage(id: 1, text: "SECOND PAGE CONTENT", currentPage: 2)
            ]
        )
    }

    private func textPage(id: Int, text: String, currentPage: Int) -> InvoiceDocumentPage {
        InvoiceDocumentPage(
            id: id,
            blocks: [
                .titledText(
                    InvoiceTitledTextFragment(
                        title: "",
                        lines: [InvoiceDocumentTextLine(text: text, style: .bodyStrong)],
                        showsTitle: false,
                        isLast: true
                    )
                ),
                .pageNumber(current: currentPage, total: 2)
            ]
        )
    }
}

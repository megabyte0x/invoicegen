import AppKit
import PDFKit
import SwiftUI

enum InvoiceDocumentRenderError: LocalizedError {
    case pageEncodingFailed(index: Int)
    case documentEncodingFailed

    var errorDescription: String? {
        switch self {
        case .pageEncodingFailed(let index):
            "Could not render invoice page \(index + 1)."
        case .documentEncodingFailed:
            "Could not encode the invoice PDF."
        }
    }
}

@MainActor
enum InvoiceDocumentRenderer {
    static func pdfData(document: InvoiceDocument) throws -> Data {
        let pdf = PDFDocument()
        for (index, page) in document.pages.enumerated() {
            let view = NSHostingView(
                rootView: InvoiceDocumentPageView(page: page)
                    .frame(
                        width: InvoiceDocument.pageSize.width,
                        height: InvoiceDocument.pageSize.height
                    )
            )
            view.frame = NSRect(
                origin: .zero,
                size: InvoiceDocument.pageSize
            )

            let pageData = NSMutableData()
            let pagePrintInfo = NSPrintInfo()
            pagePrintInfo.paperSize = InvoiceDocument.pageSize
            pagePrintInfo.orientation = .portrait
            pagePrintInfo.leftMargin = 0
            pagePrintInfo.rightMargin = 0
            pagePrintInfo.topMargin = 0
            pagePrintInfo.bottomMargin = 0
            let pageOperation = NSPrintOperation.pdfOperation(
                with: view,
                inside: view.bounds,
                to: pageData,
                printInfo: pagePrintInfo
            )
            pageOperation.showsPrintPanel = false
            pageOperation.showsProgressPanel = false

            guard pageOperation.run() else {
                throw InvoiceDocumentRenderError.pageEncodingFailed(index: index)
            }
            guard let pdfPage = PDFDocument(data: pageData as Data)?.page(at: 0) else {
                throw InvoiceDocumentRenderError.pageEncodingFailed(index: index)
            }
            pdf.insert(pdfPage, at: index)
        }

        guard let data = pdf.dataRepresentation() else {
            throw InvoiceDocumentRenderError.documentEncodingFailed
        }
        return data
    }

    static func writePDF(document: InvoiceDocument, to url: URL) throws {
        try pdfData(document: document).write(to: url, options: .atomic)
    }
}

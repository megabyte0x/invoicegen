import AppKit
import PDFKit
import SwiftUI

enum InvoiceDocumentRenderError: LocalizedError {
    case pageEncodingFailed(index: Int)
    case documentEncodingFailed
    case documentLoadingFailed

    var errorDescription: String? {
        switch self {
        case .pageEncodingFailed(let index):
            "Could not render invoice page \(index + 1)."
        case .documentEncodingFailed:
            "Could not encode the invoice PDF."
        case .documentLoadingFailed:
            "Could not load the rendered invoice PDF."
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
            view.layoutSubtreeIfNeeded()

            guard let pdfPage = PDFPage(data: view.dataWithPDF(inside: view.bounds)) else {
                throw InvoiceDocumentRenderError.pageEncodingFailed(index: index)
            }
            pdf.insert(pdfPage, at: index)
        }

        guard let data = pdf.dataRepresentation() else {
            throw InvoiceDocumentRenderError.documentEncodingFailed
        }
        return data
    }

    static func print(document: InvoiceDocument, jobTitle: String) throws {
        let data = try pdfData(document: document)
        guard let pdf = PDFDocument(data: data) else {
            throw InvoiceDocumentRenderError.documentLoadingFailed
        }
        pdf.documentAttributes = [PDFDocumentAttribute.titleAttribute: jobTitle]

        let pdfView = PDFView(
            frame: NSRect(origin: .zero, size: InvoiceDocument.pageSize)
        )
        pdfView.document = pdf
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = InvoiceDocument.pageSize
        printInfo.orientation = .portrait
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.leftMargin = InvoiceDocument.pageInsets.leading
        printInfo.rightMargin = InvoiceDocument.pageInsets.trailing
        printInfo.topMargin = InvoiceDocument.pageInsets.top
        printInfo.bottomMargin = InvoiceDocument.pageInsets.bottom

        pdfView.print(with: printInfo, autoRotate: false)
    }
}

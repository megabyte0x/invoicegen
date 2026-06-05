import SwiftUI
import InvoiceCore
import AppKit

struct InvoicePreviewView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var invoice: Invoice
    var book: InvoiceBook
    @State private var isConfirmingMarkSent = false
    @State private var isChoosingMailMethod = false
    @State private var mailNotice: String?

    var body: some View {
        VStack(spacing: 20) {
            // Actions Toolbar
            HStack {
                if let mailNotice {
                    Label(mailNotice, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color.runeyMuted)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: {
                    isChoosingMailMethod = true
                }) {
                    Label("Mail Invoice", systemImage: "envelope.fill")
                }
                .buttonStyle(RuneyButtonStyle())

                Button(action: {
                    printInvoice()
                }) {
                    Label("Print or Export PDF...", systemImage: "printer.fill")
                }
                .buttonStyle(RuneyButtonStyle(variant: .prominent))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Invoice Sheet Container
            ScrollView([.vertical, .horizontal]) {
                InvoiceSheetView(invoice: invoice, book: book)
                    .frame(width: 612) // Fixed width for standard Letter layout aspect
                    .padding(36)
                    .background(Color.white) // Fixed white paper sheet background
                    .cornerRadius(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color.runeyBackground)
        .sheet(isPresented: $isChoosingMailMethod) {
            MailInvoiceMethodSheet {
                isChoosingMailMethod = false
                runAfterMailMethodSheetDismisses {
                    mailInvoiceWithMailApp()
                }
            } useBrowser: {
                isChoosingMailMethod = false
                runAfterMailMethodSheetDismisses {
                    mailInvoiceWithBrowser()
                }
            } cancel: {
                isChoosingMailMethod = false
            }
        }
        .alert("Mark invoice as sent?", isPresented: $isConfirmingMarkSent) {
            Button("Mark as Sent") {
                invoice.status = .sent
                model.save()
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("The email compose window has been opened. Mark this invoice as sent only if you intend to send it.")
        }
    }

    private func printInvoice() {
        // Build view explicitly sized for Letter printing
        let printView = InvoiceSheetView(invoice: invoice, book: book)
            .frame(width: 612, height: 792)
            .background(Color.white)
        
        let hostingView = NSHostingView(rootView: printView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 612, height: 792)

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.orientation = .portrait
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36

        let printOp = NSPrintOperation(view: hostingView, printInfo: printInfo)
        printOp.jobTitle = InvoiceExportNaming.pdfFileStem(for: invoice)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()
    }

    private func mailInvoiceWithMailApp() {
        let draft = InvoiceMailDraft(invoice: invoice, book: book)

        do {
            let attachmentURL = try writeTemporaryInvoicePDF()
            try InvoiceMailAppleScript.compose(draft: draft, attachmentURL: attachmentURL)
            scheduleTemporaryAttachmentCleanup(for: attachmentURL)

            mailNotice = draft.isMissingRecipient ? "No client email. Mail opened without a recipient." : nil
            isConfirmingMarkSent = true
        } catch {
            model.errorMessage = "Could not prepare invoice email: \(error.localizedDescription)"
        }
    }

    private func mailInvoiceWithBrowser() {
        let draft = InvoiceMailDraft(invoice: invoice, book: book)

        do {
            let attachmentURL = try writeTemporaryInvoicePDF()

            guard let mailtoURL = InvoiceMailtoURL.url(for: draft) else {
                throw NSError(
                    domain: "InvoiceGen.Mailto",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not open the browser email composer."
                    ]
                )
            }

            NSWorkspace.shared.activateFileViewerSelecting([attachmentURL])

            guard NSWorkspace.shared.open(mailtoURL) else {
                throw NSError(
                    domain: "InvoiceGen.Mailto",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not open the browser email composer."
                    ]
                )
            }

            scheduleTemporaryAttachmentCleanup(for: attachmentURL, delay: Self.browserMailCleanupDelay)
            mailNotice = browserMailNotice(isMissingRecipient: draft.isMissingRecipient)
            isConfirmingMarkSent = true
        } catch {
            model.errorMessage = "Could not prepare browser email: \(error.localizedDescription)"
        }
    }

    private func writeTemporaryInvoicePDF() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoiceGen-Mail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(InvoiceExportNaming.pdfFileName(for: invoice))
        try invoicePDFData().write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func invoicePDFData() -> Data {
        let pdfView = InvoiceSheetView(invoice: invoice, book: book)
            .frame(width: 612, height: 792)
            .background(Color.white)

        let hostingView = NSHostingView(rootView: pdfView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.dataWithPDF(inside: hostingView.bounds)
    }

    private func scheduleTemporaryAttachmentCleanup(
        for attachmentURL: URL,
        delay: TimeInterval = Self.successfulShareCleanupDelay
    ) {
        let directoryURL = attachmentURL.deletingLastPathComponent()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    private func browserMailNotice(isMissingRecipient: Bool) -> String {
        if isMissingRecipient {
            return "Browser email opened without a recipient. Attach the revealed PDF manually."
        }

        return "Browser email opened. Attach the revealed PDF manually."
    }

    private func runAfterMailMethodSheetDismisses(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: action)
    }

    private static let successfulShareCleanupDelay: TimeInterval = 600
    private static let browserMailCleanupDelay: TimeInterval = 3600
}

private struct MailInvoiceMethodSheet: View {
    var useMailApp: () -> Void
    var useBrowser: () -> Void
    var cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.title2)
                    .foregroundStyle(Color.runeyAccent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mail Invoice")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.runeyPrimary)
                    Text("Choose where to compose this invoice email.")
                        .font(.subheadline)
                        .foregroundStyle(Color.runeyMuted)
                }
            }

            VStack(spacing: 10) {
                Button(action: useMailApp) {
                    MailInvoiceMethodRow(
                        icon: "envelope.fill",
                        title: "Mail App",
                        subtitle: "Opens Apple Mail with the PDF attached."
                    )
                }
                .buttonStyle(.plain)

                Button(action: useBrowser) {
                    MailInvoiceMethodRow(
                        icon: "safari.fill",
                        title: "Browser or Default Email",
                        subtitle: "Opens a mailto draft and reveals the PDF."
                    )
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
            }
        }
        .padding(22)
        .frame(width: 430)
        .background(Color.runeyBackground)
    }
}

private struct MailInvoiceMethodRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.runeyAccent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.runeyMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.runeyMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.runeySecondary)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.runeyBorder.opacity(0.8), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct InvoiceSheetView: View {
    var invoice: Invoice
    var book: InvoiceBook

    private var client: Client? {
        book.client(for: invoice)
    }

    private var paymentAcceptanceDetails: [PaymentAcceptanceDetail] {
        book.paymentAcceptanceDetails(for: invoice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Invoice Title + Company Identity
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.businessProfile.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.black) // Dark ink
                    if !book.businessProfile.email.isEmpty {
                        Text(book.businessProfile.email)
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.35))
                    }
                    if !book.businessProfile.address.isEmpty {
                        Text(book.businessProfile.address)
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.35))
                            .lineLimit(3)
                    }
                    if !book.businessProfile.taxIdentifier.isEmpty {
                        Text("Tax ID: \(book.businessProfile.taxIdentifier)")
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.35))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("INVOICE")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(Color.black)
                    Text(invoice.number)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(Color(white: 0.35))
                }
            }
            .padding(.bottom, 36)

            Divider()
                .background(Color(white: 0.85))
                .padding(.bottom, 24)

            // Invoice Metadata: Bill To + Terms
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BILL TO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.45))
                    Text(client?.name ?? "Unassigned Client")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.black)
                    if let company = client?.company, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.35))
                    }
                    if let address = client?.address, !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.35))
                            .lineLimit(4)
                    }
                    if let email = client?.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.35))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Issue Date:")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(white: 0.45))
                            Text(DateFormatting.short.string(from: invoice.issueDate))
                                .font(.subheadline)
                                .foregroundStyle(Color.black)
                        }
                        GridRow {
                            Text("Due Date:")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(white: 0.45))
                            Text(DateFormatting.short.string(from: invoice.dueDate))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.black)
                        }
                    }
                }
            }
            .padding(.bottom, 36)

            // Line Items Table
            VStack(alignment: .leading, spacing: 0) {
                // Table Header
                HStack(spacing: 8) {
                    Text("Description")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Qty")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(width: 50, alignment: .center)
                    Text("Unit Price")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(width: 90, alignment: .trailing)
                    Text("Tax")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(width: 50, alignment: .trailing)
                    Text("Total")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(white: 0.35))
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(white: 0.94))
                
                Divider()
                    .background(Color(white: 0.85))

                // Items List
                ForEach(invoice.lineItems) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.black)
                                if !item.details.isEmpty {
                                    Text(item.details)
                                        .font(.caption)
                                        .foregroundStyle(Color(white: 0.4))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(trimmedQty(item.quantity))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color.black)
                                .frame(width: 50, alignment: .center)

                            Text(Money.format(minorUnits: item.unitPriceMinorUnits, currencyCode: invoice.currencyCode).replacingOccurrences(of: invoice.currencyCode + " ", with: ""))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color.black)
                                .frame(width: 90, alignment: .trailing)

                            Text("\(trimmedQty(item.taxRatePercent))%")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color.black)
                                .frame(width: 50, alignment: .trailing)

                            Text(Money.format(minorUnits: item.totalMinorUnits, currencyCode: invoice.currencyCode).replacingOccurrences(of: invoice.currencyCode + " ", with: ""))
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .foregroundStyle(Color.black)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        
                        Divider()
                            .background(Color(white: 0.88))
                    }
                }
            }
            .padding(.bottom, 24)

            // Bottom Summary: Notes/Terms + Totals Box
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    if !invoice.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(white: 0.45))
                            Text(invoice.notes)
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.35))
                        }
                    }
                    if !invoice.terms.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Terms & Conditions")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(white: 0.45))
                            Text(invoice.terms)
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.35))
                        }
                    }
                    if !paymentAcceptanceDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Payment Acceptance")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(white: 0.45))

                            ForEach(paymentAcceptanceDetails) { detail in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(detail.kind.label): \(detail.label)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.black)

                                    ForEach(detailLines(for: detail), id: \.self) { line in
                                        Text(line)
                                            .font(.caption)
                                            .foregroundStyle(Color(white: 0.35))
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 0) {
                    Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            Text("Subtotal")
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.4))
                            Text(Money.format(minorUnits: invoice.subtotalMinorUnits, currencyCode: invoice.currencyCode))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(Color.black)
                        }
                        GridRow {
                            Text("Tax")
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.4))
                            Text(Money.format(minorUnits: invoice.taxMinorUnits, currencyCode: invoice.currencyCode))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(Color.black)
                        }
                        if invoice.paidMinorUnits > 0 {
                            GridRow {
                                Text("Amount Paid")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(white: 0.4))
                                  Text(Money.format(minorUnits: invoice.paidMinorUnits, currencyCode: invoice.currencyCode))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(Color.black)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                    
                    Divider()
                        .frame(width: 220)
                        .background(Color(white: 0.8))
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 24) {
                        Text("Balance Due")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black)
                        Text(Money.format(minorUnits: invoice.balanceDueMinorUnits, currencyCode: invoice.currencyCode))
                            .font(.system(.headline, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.black) // Dark ink
                    }
                }
            }
        }
        .padding(32)
        .background(Color.white)
    }

    private func trimmedQty(_ val: Double) -> String {
        if val.rounded() == val {
            return String(Int(val))
        }
        return String(format: "%.2f", val)
    }

    private func detailLines(for detail: PaymentAcceptanceDetail) -> [String] {
        detail.details
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

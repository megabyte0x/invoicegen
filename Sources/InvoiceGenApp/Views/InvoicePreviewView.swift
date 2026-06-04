import SwiftUI
import InvoiceCore
import AppKit

struct InvoicePreviewView: View {
    var invoice: Invoice
    var book: InvoiceBook

    var body: some View {
        VStack(spacing: 20) {
            // Actions Toolbar
            HStack {
                Spacer()
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
            ScrollView {
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

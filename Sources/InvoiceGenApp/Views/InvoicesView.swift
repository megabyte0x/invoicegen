import SwiftUI
import InvoiceCore

struct InvoicesView: View {
    @EnvironmentObject private var model: AppModel

    private var filteredInvoices: [Invoice] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.book.invoices
            .filter { invoice in
                guard !query.isEmpty else { return true }
                let clientName = model.book.client(for: invoice)?.name ?? ""
                return invoice.number.localizedCaseInsensitiveContains(query)
                    || clientName.localizedCaseInsensitiveContains(query)
                    || invoice.status.rawValue.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.issueDate > $1.issueDate }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedInvoiceID) {
                ForEach(filteredInvoices) { invoice in
                    InvoiceSummaryRow(invoice: invoice, client: model.book.client(for: invoice))
                        .tag(invoice.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                model.selectedInvoiceID = invoice.id
                                model.deleteSelectedInvoice()
                            }
                        }
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 340)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    model.addInvoice()
                }) {
                    Label("New Invoice", systemImage: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.runeySecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.runeyPrimary, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding()
            }
        } detail: {
            if let id = model.selectedInvoiceID,
               let binding = model.invoiceBinding(id: id) {
                InvoiceEditorView(invoice: binding)
            } else {
                EmptyStateView(
                    title: "Select an invoice",
                    subtitle: "Choose an invoice from the list or create a new one.",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .navigationTitle("Invoices")
        .onAppear {
            if model.selectedInvoiceID == nil {
                model.selectedInvoiceID = filteredInvoices.first?.id
            }
        }
    }
}

struct InvoiceSummaryRow: View {
    var invoice: Invoice
    var client: Client?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(invoice.number)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.runeyPrimary)
                    StatusBadge(status: invoice.status)
                }
                Text(client?.name ?? "Unassigned client")
                    .font(.caption)
                    .foregroundStyle(Color.runeyMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.format(minorUnits: invoice.balanceDueMinorUnits, currencyCode: invoice.currencyCode).replacingOccurrences(of: invoice.currencyCode + " ", with: ""))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                Text(DateFormatting.short.string(from: invoice.dueDate))
                    .font(.caption2)
                    .foregroundStyle(Color.runeyMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    var status: InvoiceStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .draft: return Color.runeyMuted
        case .sent: return Color.runeyInfo
        case .paid: return Color.runeySuccess
        case .overdue: return Color.runeyDestructive
        case .void: return Color.runeyOrange
        }
    }
}


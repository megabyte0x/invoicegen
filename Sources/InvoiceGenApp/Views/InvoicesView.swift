import SwiftUI
import InvoiceCore

struct InvoicesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var invoiceIDPendingDeletion: UUID?

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
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 10))
                        .tag(invoice.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                invoiceIDPendingDeletion = invoice.id
                            }
                        }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 340)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    model.addInvoice()
                }) {
                    Label("New Invoice", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
        .alert("Delete invoice?", isPresented: Binding(
            get: { invoiceIDPendingDeletion != nil },
            set: { if !$0 { invoiceIDPendingDeletion = nil } }
        )) {
            Button("Delete Invoice", role: .destructive) {
                if let id = invoiceIDPendingDeletion {
                    model.selectedInvoiceID = id
                    model.deleteSelectedInvoice()
                }
                invoiceIDPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                invoiceIDPendingDeletion = nil
            }
        } message: {
            Text("This permanently removes the selected invoice from the local store.")
        }
    }
}

struct InvoiceSummaryRow: View {
    var invoice: Invoice
    var client: Client?

    var body: some View {
        let content = InvoiceSummaryRowContent(
            invoice: invoice,
            clientName: client?.name ?? "Unassigned client"
        )

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.invoiceNumber)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                Text(content.amountText)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .center, spacing: 6) {
                Text(content.clientName)
                    .font(.caption)
                    .foregroundStyle(Color.runeyMuted)
                    .lineLimit(1)
                    .layoutPriority(1)

                StatusBadge(status: invoice.status)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                Text(content.dueDateText)
                    .font(.caption2)
                    .foregroundStyle(Color.runeyMuted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: content.minimumHeight, alignment: .center)
        .contentShape(Rectangle())
    }
}

struct InvoiceSummaryRowContent {
    let invoiceNumber: String
    let statusLabel: String
    let amountText: String
    let clientName: String
    let dueDateText: String
    let minimumHeight: CGFloat

    init(invoice: Invoice, clientName: String) {
        self.invoiceNumber = invoice.number
        self.statusLabel = invoice.status.label
        self.amountText = Money.format(
            minorUnits: invoice.balanceDueMinorUnits,
            currencyCode: invoice.currencyCode
        )
        .replacingOccurrences(of: invoice.currencyCode + " ", with: "")
        self.clientName = clientName
        self.dueDateText = DateFormatting.short.string(from: invoice.dueDate)
        self.minimumHeight = 58
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

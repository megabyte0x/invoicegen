import SwiftUI
import InvoiceCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveredTile: String? = nil

    private var invoices: [Invoice] {
        model.book.invoices.sorted { $0.issueDate > $1.issueDate }
    }

    private var outstandingMinorUnits: Int64 {
        model.book.invoices.reduce(0) { $0 + $1.balanceDueMinorUnits }
    }

    private var paidMinorUnits: Int64 {
        model.book.invoices.reduce(0) { $0 + $1.paidMinorUnits }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricTile(
                        title: "Outstanding",
                        value: money(outstandingMinorUnits),
                        systemImage: "clock.badge.exclamationmark",
                        iconColor: Color.runeyWarning,
                        isHovered: hoveredTile == "outstanding"
                    )
                    .onHover { isHovered in hoveredTile = isHovered ? "outstanding" : nil }
                    .onTapGesture {
                        model.selectedSection = .invoices
                    }

                    MetricTile(
                        title: "Paid to Date",
                        value: money(paidMinorUnits),
                        systemImage: "checkmark.circle.fill",
                        iconColor: Color.runeySuccess,
                        isHovered: hoveredTile == "paid"
                    )
                    .onHover { isHovered in hoveredTile = isHovered ? "paid" : nil }
                    .onTapGesture {
                        model.selectedSection = .invoices
                    }

                    MetricTile(
                        title: "Total Clients",
                        value: "\(model.book.clients.count)",
                        systemImage: "person.2.fill",
                        iconColor: Color.runeyInfo,
                        isHovered: hoveredTile == "clients"
                    )
                    .onHover { isHovered in hoveredTile = isHovered ? "clients" : nil }
                    .onTapGesture {
                        model.selectedSection = .clients
                    }

                    MetricTile(
                        title: "Overdue Invoices",
                        value: "\(model.book.invoices.filter { $0.status == .overdue }.count)",
                        systemImage: "exclamationmark.triangle.fill",
                        iconColor: Color.runeyDestructive,
                        isHovered: hoveredTile == "overdue"
                    )
                    .onHover { isHovered in hoveredTile = isHovered ? "overdue" : nil }
                    .onTapGesture {
                        model.selectedSection = .invoices
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Recent Invoices", actionTitle: "New Invoice") {
                        model.addInvoice()
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(invoices.prefix(8)) { invoice in
                            Button {
                                model.selectedSection = .invoices
                                model.selectedInvoiceID = invoice.id
                            } label: {
                                InvoiceSummaryRow(invoice: invoice, client: model.book.client(for: invoice))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if invoice.id != invoices.prefix(8).last?.id {
                                Divider()
                                    .background(Color.runeyBorder)
                            }
                        }

                        if invoices.isEmpty {
                            EmptyStateView(
                                title: "No invoices yet",
                                subtitle: "Create your first local invoice or seed sample data from Settings.",
                                systemImage: "doc.text"
                            )
                        }
                    }
                    .background(Color.runeySecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.book.businessProfile.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.runeyPrimary)
                Text("Local-first invoicing, clients, and payments recorded on this machine.")
                    .font(.subheadline)
                    .foregroundStyle(Color.runeyMuted)
            }

            Spacer()
            LocalBadge()
        }
        .padding(20)
        .background(TahoeHeaderBackground())
    }

    private func money(_ value: Int64) -> String {
        Money.format(minorUnits: value, currencyCode: model.book.businessProfile.currencyCode)
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var systemImage: String
    var iconColor: Color
    var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.runeyMuted)
                Spacer()
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12), in: Circle())
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.runeyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .runeyCard(padding: 16, isHovered: isHovered)
        .contentShape(Rectangle())
    }
}

struct SectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.runeyPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.runeyPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(Color.runeyMuted)
                .frame(width: 56, height: 56)
                .background(Color.runeyBorder.opacity(0.3), in: Circle())
            
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.runeyMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

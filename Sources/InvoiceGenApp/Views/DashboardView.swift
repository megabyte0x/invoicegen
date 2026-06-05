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
                    GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)
                ], spacing: 14) {
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
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.book.businessProfile.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.runeyPrimary)
                Text("Local-first invoicing, clients, and payments recorded on this machine.")
                    .font(.subheadline)
                    .foregroundStyle(Color.runeyMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                LocalBadge()
                HStack(spacing: 8) {
                    HeaderStat(value: "\(model.book.invoices.count)", title: "Invoices")
                    HeaderStat(value: "\(model.book.clients.count)", title: "Clients")
                }
            }
        }
        .padding(20)
        .background(TahoeHeaderBackground())
    }

    private func money(_ value: Int64) -> String {
        Money.format(minorUnits: value, currencyCode: model.book.businessProfile.currencyCode)
    }
}

struct HeaderStat: View {
    var value: String
    var title: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.runeyPrimary)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.runeyMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.runeyBorder.opacity(0.55), lineWidth: 1)
        }
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
                    .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
                }
                .buttonStyle(RuneyButtonStyle())
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

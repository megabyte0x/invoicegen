import SwiftUI
import InvoiceCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isConfirmingSeedSampleData = false
    @State private var paymentDetailIDPendingDeletion: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Business Profile
                VStack(alignment: .leading, spacing: 16) {
                    Text("Business Profile")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            runeyField("Business Name", text: $model.book.businessProfile.name)
                            runeyField("Billing Email Address", text: $model.book.businessProfile.email)
                        }
                        
                        GridRow {
                            runeyField("Tax Identifier (e.g. VAT / EIN)", text: $model.book.businessProfile.taxIdentifier)
                            runeyField("Currency Code (e.g. USD / EUR)", text: $model.book.businessProfile.currencyCode)
                        }
                        
                        GridRow {
                            runeyField("Business Address", text: $model.book.businessProfile.address, isMultiline: true)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Payment Terms (Due Date Offset)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.runeyMuted)

                                HStack(spacing: 8) {
                                    Text("Net")
                                        .font(.body)
                                        .foregroundStyle(Color.runeyPrimary)

                                    TextField("", value: paymentTermsDaysBinding, format: .number)
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 56)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                        }

                                    Text("Days")
                                        .font(.body)
                                        .foregroundStyle(Color.runeyPrimary)
                                }
                                .frame(height: 30)
                            }
                        }
                    }
                }
                .runeyCard()

                // Section 2: Payment Acceptance Details
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Payment Acceptance Details")
                            .font(.headline)
                            .foregroundStyle(Color.runeyPrimary)

                        Spacer()

                        Button(action: {
                            model.addPaymentAcceptanceDetail(kind: .bankDetails)
                        }) {
                            Label("Add Bank Details", systemImage: "building.columns")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.runeyPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            model.addPaymentAcceptanceDetail(kind: .cryptocurrency)
                        }) {
                            Label("Add Cryptocurrency", systemImage: "bitcoinsign.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.runeyPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    if model.book.paymentAcceptanceDetails.isEmpty {
                        Text("No payment details saved.")
                            .font(.subheadline)
                            .foregroundStyle(Color.runeyMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 12) {
                            ForEach($model.book.paymentAcceptanceDetails) { $detail in
                                PaymentAcceptanceDetailEditor(detail: $detail) {
                                    paymentDetailIDPendingDeletion = detail.id
                                }
                            }
                        }
                    }
                }
                .runeyCard()
                
                // Section 3: Local Database Store
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local Data Storage")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Store Path")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.runeyMuted)
                        
                        Text(model.store.url.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.runeyPrimary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
                            }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            model.reload()
                        }) {
                            Label("Reload From Disk", systemImage: "arrow.clockwise")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.runeyPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            isConfirmingSeedSampleData = true
                        }) {
                            Label("Seed Sample Data", systemImage: "doc.text.fill.badge.plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.runeyInfo, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .runeyCard()
            }
            .padding(24)
        }
        .background(Color.runeyBackground)
        .onChange(of: model.book.businessProfile) { _, _ in
            model.save()
        }
        .onChange(of: model.book.paymentAcceptanceDetails) { _, _ in
            model.save()
        }
        .alert("Replace local data with sample data?", isPresented: $isConfirmingSeedSampleData) {
            Button("Seed Sample Data", role: .destructive) {
                model.seedSampleData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current local invoice store with sample clients, projects, invoices, and payment details.")
        }
        .alert("Delete payment details?", isPresented: Binding(
            get: { paymentDetailIDPendingDeletion != nil },
            set: { if !$0 { paymentDetailIDPendingDeletion = nil } }
        )) {
            Button("Delete Payment Details", role: .destructive) {
                if let id = paymentDetailIDPendingDeletion {
                    model.deletePaymentAcceptanceDetail(id: id)
                }
                paymentDetailIDPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                paymentDetailIDPendingDeletion = nil
            }
        } message: {
            Text("This removes the payment details from Settings and detaches them from every invoice that used them.")
        }
    }

    private var paymentTermsDaysBinding: Binding<Int> {
        Binding(
            get: { model.book.businessProfile.paymentTermsDays },
            set: { newValue in
                model.book.businessProfile.paymentTermsDays = min(max(newValue, 0), 120)
            }
        )
    }

    private func runeyField(_ label: String, text: Binding<String>, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)
            if isMultiline {
                RuneyMultilineEditor(text: text)
            } else {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                    }
            }
        }
    }
}

struct PaymentAcceptanceDetailEditor: View {
    @Binding var detail: PaymentAcceptanceDetail
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: detail.kind == .bankDetails ? "building.columns" : "bitcoinsign.circle")
                    .font(.body)
                    .foregroundStyle(Color.runeyMuted)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.label.isEmpty ? detail.kind.label : detail.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.runeyPrimary)
                    Text(detail.kind.label)
                        .font(.caption)
                        .foregroundStyle(Color.runeyMuted)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.runeyDestructive)
                        .frame(width: 28, height: 28)
                        .background(Color.runeyDestructive.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                GridRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.runeyMuted)
                        Picker("", selection: $detail.kind) {
                            ForEach(PaymentAcceptanceKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .frame(height: 30)
                    }

                    runeyField("Label", text: $detail.label)
                }

                GridRow {
                    PaymentDetailLinesEditor(details: $detail.details)
                        .gridCellColumns(2)
                }
            }
        }
        .padding(12)
        .background(Color.runeyBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.runeyBorder, lineWidth: 1)
        }
    }

    private func runeyField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                }
        }
    }
}

struct PaymentDetailLinesEditor: View {
    @Binding var details: String

    private var lines: [String] {
        let storedLines = details.components(separatedBy: .newlines)
        return storedLines.isEmpty ? [""] : storedLines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detail Lines")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)

            VStack(spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 8) {
                        TextField("", text: lineBinding(at: index))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
                            }

                        Button(role: .destructive) {
                            removeLine(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.runeyDestructive)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .disabled(lines.count == 1 && lines[0].isEmpty)
                        .opacity(lines.count == 1 && lines[0].isEmpty ? 0.4 : 1.0)
                    }
                }
            }

            Button {
                appendLine()
            } label: {
                Label("Add Detail Line", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func lineBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                let currentLines = lines
                guard currentLines.indices.contains(index) else { return "" }
                return currentLines[index]
            },
            set: { newValue in
                var currentLines = lines
                while currentLines.count <= index {
                    currentLines.append("")
                }
                currentLines[index] = newValue
                details = currentLines.joined(separator: "\n")
            }
        )
    }

    private func appendLine() {
        var currentLines = lines
        currentLines.append("")
        details = currentLines.joined(separator: "\n")
    }

    private func removeLine(at index: Int) {
        var currentLines = lines
        guard currentLines.indices.contains(index) else { return }
        currentLines.remove(at: index)
        details = currentLines.joined(separator: "\n")
    }
}

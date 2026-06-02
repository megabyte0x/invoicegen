import SwiftUI
import InvoiceCore

struct InvoiceEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var invoice: Invoice
    @State private var selectedTab = 0 // 0 = Details, 1 = Preview
    @State private var isConfirmingMarkUnpaid = false
    @State private var isConfirmingDelete = false
    @State private var lineItemIDPendingDeletion: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Tab Switcher
            Picker("", selection: $selectedTab) {
                Text("Edit Details").tag(0)
                Text("Invoice Preview").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
                .background(Color.runeyBorder)

            if selectedTab == 1 {
                InvoicePreviewView(invoice: invoice, book: model.book)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Basic Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Invoice Details")
                                .font(.headline)
                                .foregroundStyle(Color.runeyPrimary)
                            
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                                GridRow {
                                    runeyField("Invoice Number", text: $invoice.number)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Status")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.runeyMuted)
                                        Picker("", selection: $invoice.status) {
                                            ForEach(InvoiceStatus.allCases) { status in
                                                Text(status.label).tag(status)
                                            }
                                        }
                                        .frame(height: 30)
                                    }
                                }
                                
                                GridRow {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Client")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.runeyMuted)
                                        Picker("", selection: optionalClientBinding) {
                                            Text("Unassigned").tag(UUID?.none)
                                            ForEach(model.book.clients) { client in
                                                Text(client.name).tag(Optional(client.id))
                                            }
                                        }
                                        .frame(height: 30)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Project")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.runeyMuted)
                                        Picker("", selection: optionalProjectBinding) {
                                            Text("None").tag(UUID?.none)
                                            ForEach(model.book.projects) { project in
                                                Text(project.name).tag(Optional(project.id))
                                            }
                                        }
                                        .frame(height: 30)
                                    }
                                }
                                
                                GridRow {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Issue Date")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.runeyMuted)
                                        DatePicker("", selection: $invoice.issueDate, displayedComponents: .date)
                                            .labelsHidden()
                                            .frame(height: 30)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Due Date")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.runeyMuted)
                                        DatePicker("", selection: $invoice.dueDate, displayedComponents: .date)
                                            .labelsHidden()
                                            .frame(height: 30)
                                    }
                                }
                            }
                        }
                        .runeyCard()
                        
                        // Section 2: Line Items
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Line Items")
                                    .font(.headline)
                                    .foregroundStyle(Color.runeyPrimary)
                                Spacer()
                                Button(action: {
                                    invoice.lineItems.append(InvoiceLineItem(title: "New Item", quantity: 1, unitPriceMinorUnits: 0))
                                    model.save()
                                }) {
                                    Label("Add Item", systemImage: "plus")
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
                            
                            ForEach($invoice.lineItems) { $item in
                                VStack(spacing: 8) {
                                    HStack {
                                        LineItemEditor(item: $item, currencyCode: invoice.currencyCode)
                                        
                                        Button(role: .destructive) {
                                            lineItemIDPendingDeletion = item.id
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(Color.runeyDestructive)
                                                .frame(width: 28, height: 28)
                                                .background(Color.runeyDestructive.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Divider()
                                        .background(Color.runeyBorder)
                                }
                            }
                            
                            if invoice.lineItems.isEmpty {
                                Text("No line items added yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.runeyMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            }
                        }
                        .runeyCard()
                        
                        // Section 3: Notes & Terms
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Notes & Terms")
                                .font(.headline)
                                .foregroundStyle(Color.runeyPrimary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Memo / Client Notes")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.runeyMuted)
                                RuneyMultilineEditor(text: $invoice.notes, minHeight: 78)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Terms & Conditions")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.runeyMuted)
                                RuneyMultilineEditor(text: $invoice.terms, minHeight: 58)
                            }
                        }
                        .runeyCard()

                        // Section 4: Payment Acceptance
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Payment Acceptance")
                                .font(.headline)
                                .foregroundStyle(Color.runeyPrimary)

                            if model.book.paymentAcceptanceDetails.isEmpty {
                                Text("No payment acceptance details available.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.runeyMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(model.book.paymentAcceptanceDetails) { detail in
                                        Toggle(isOn: paymentDetailSelectionBinding(for: detail.id)) {
                                            PaymentAcceptanceSelectionLabel(detail: detail)
                                        }
                                        .toggleStyle(.checkbox)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(Color.runeyBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                        }
                                    }
                                }
                            }
                        }
                        .runeyCard()

                        // Section 5: Totals & Summary
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Summary")
                                .font(.headline)
                                .foregroundStyle(Color.runeyPrimary)
                            
                            VStack(spacing: 10) {
                                summaryRow(title: "Subtotal", value: invoice.subtotalMinorUnits, currencyCode: invoice.currencyCode)
                                summaryRow(title: "Estimated Tax", value: invoice.taxMinorUnits, currencyCode: invoice.currencyCode)
                                summaryRow(title: "Amount Paid", value: invoice.paidMinorUnits, currencyCode: invoice.currencyCode)
                                
                                Divider()
                                    .background(Color.runeyBorder)
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    Text("Balance Due")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(Color.runeyPrimary)
                                    Spacer()
                                    Text(Money.format(minorUnits: invoice.balanceDueMinorUnits, currencyCode: invoice.currencyCode))
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(invoice.balanceDueMinorUnits > 0 ? Color.runeyPrimary : Color.runeySuccess)
                                }
                            }
                        }
                        .runeyCard()

                        // Actions Section
                        HStack(spacing: 16) {
                            Button(action: {
                                invoice.status = .sent
                                model.save()
                            }) {
                                Label("Mark as Sent", systemImage: "paperplane.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.runeyPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            if invoice.status == .paid {
                                Button(action: {
                                    isConfirmingMarkUnpaid = true
                                }) {
                                    Label("Mark as Unpaid", systemImage: "arrow.uturn.backward.circle.fill")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.runeyPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    invoice.payments.append(Payment(amountMinorUnits: invoice.balanceDueMinorUnits))
                                    invoice.refreshStatus()
                                    model.save()
                                }) {
                                    Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.runeySuccess, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .disabled(invoice.balanceDueMinorUnits == 0)
                                .opacity(invoice.balanceDueMinorUnits == 0 ? 0.5 : 1.0)
                            }

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(InvoiceTextRenderer.render(invoice: invoice, book: model.book), forType: .string)
                            }) {
                                Label("Copy Raw Text", systemImage: "doc.on.doc.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.runeyPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Danger Zone: Delete Button
                        VStack(alignment: .leading, spacing: 14) {
                            Button(role: .destructive, action: {
                                isConfirmingDelete = true
                            }) {
                                Label("Delete Invoice", systemImage: "trash.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.runeyDestructive, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .runeyCard()
                        .padding(.bottom, 24)
                    }
                    .padding(24)
                }
            }
        }
        .background(Color.runeyBackground)
        .navigationTitle(invoice.number)
        .alert("Mark invoice as unpaid?", isPresented: $isConfirmingMarkUnpaid) {
            Button("Mark as Unpaid", role: .destructive) {
                invoice.markUnpaid()
                model.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes recorded payments for this invoice and recalculates its unpaid status.")
        }
        .alert("Delete invoice?", isPresented: $isConfirmingDelete) {
            Button("Delete Invoice", role: .destructive) {
                model.deleteSelectedInvoice()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the selected invoice from the local store.")
        }
        .alert("Delete line item?", isPresented: Binding(
            get: { lineItemIDPendingDeletion != nil },
            set: { if !$0 { lineItemIDPendingDeletion = nil } }
        )) {
            Button("Delete Line Item", role: .destructive) {
                if let id = lineItemIDPendingDeletion {
                    invoice.lineItems.removeAll { $0.id == id }
                    model.save()
                }
                lineItemIDPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                lineItemIDPendingDeletion = nil
            }
        } message: {
            Text("This removes the selected line item from the invoice.")
        }
    }

    private var optionalClientBinding: Binding<UUID?> {
        Binding(
            get: { invoice.clientId },
            set: { newValue in
                invoice.clientId = newValue
                model.save()
            }
        )
    }

    private var optionalProjectBinding: Binding<UUID?> {
        Binding(
            get: { invoice.projectId },
            set: { newValue in
                invoice.projectId = newValue
                model.save()
            }
        )
    }

    private func paymentDetailSelectionBinding(for detailID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                invoice.acceptedPaymentDetailIDs.contains(detailID)
            },
            set: { isSelected in
                if isSelected {
                    if !invoice.acceptedPaymentDetailIDs.contains(detailID) {
                        invoice.acceptedPaymentDetailIDs.append(detailID)
                    }
                } else {
                    invoice.acceptedPaymentDetailIDs.removeAll { $0 == detailID }
                }
                model.save()
            }
        )
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

    private func summaryRow(title: String, value: Int64, currencyCode: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.runeyMuted)
            Spacer()
            Text(Money.format(minorUnits: value, currencyCode: currencyCode))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.runeyPrimary)
        }
    }
}

struct PaymentAcceptanceSelectionLabel: View {
    var detail: PaymentAcceptanceDetail

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: detail.kind == .bankDetails ? "building.columns" : "bitcoinsign.circle")
                .font(.body)
                .foregroundStyle(Color.runeyMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(detail.label.isEmpty ? detail.kind.label : detail.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                Text(detail.kind.label)
                    .font(.caption)
                    .foregroundStyle(Color.runeyMuted)
                if !detail.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(detail.details)
                        .font(.caption)
                        .foregroundStyle(Color.runeyMuted)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

struct LineItemEditor: View {
    @Binding var item: InvoiceLineItem
    var currencyCode: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                runeyField("Title", text: $item.title)
                    .gridCellColumns(2)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Qty")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.runeyMuted)
                    TextField("", value: $item.quantity, format: .number)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 60)
                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unit Price")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.runeyMuted)
                    TextField("", text: $item.unitPriceMinorUnits.moneyString(currencyCode: currencyCode))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 84)
                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tax %")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.runeyMuted)
                    TextField("", value: $item.taxRatePercent, format: .number)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 56)
                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                        }
                }
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Total")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.runeyMuted)
                    Text(Money.format(minorUnits: item.totalMinorUnits, currencyCode: currencyCode).replacingOccurrences(of: currencyCode + " ", with: ""))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color.runeyPrimary)
                        .frame(height: 28, alignment: .trailing)
                }
            }
            GridRow {
                runeyField("Item Details", text: $item.details)
                    .gridCellColumns(6)
            }
        }
        .padding(.vertical, 5)
    }

    private func runeyField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                }
        }
    }
}

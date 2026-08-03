import SwiftUI
import InvoiceCore

struct InvoiceEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var requestedPresentation: InvoiceEditorPresentation
    @State private var isConfirmingMarkUnpaid = false
    @State private var isConfirmingDelete = false
    @State private var lineItemIDPendingDeletion: UUID?
    @State private var autoGenerationIntervalDraft: String?
    @State private var touchedFields: Set<EditorField> = []
    @State private var numericInputResetGeneration = 0
    @FocusState private var focusedField: EditorField?

    var body: some View {
        Group {
            if let session = model.invoiceDraft {
                editor(session: session)
            } else {
                EmptyStateView(
                    title: "Select an invoice",
                    subtitle: "Choose an invoice from the list or create a new one.",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .alert("Mark invoice as unpaid?", isPresented: $isConfirmingMarkUnpaid) {
            Button("Mark as Unpaid", role: .destructive) {
                updateInvoice { $0.markUnpaid() }
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
                    updateInvoice { invoice in
                        invoice.lineItems.removeAll { $0.id == id }
                    }
                    removeFieldState(forLineItemID: id)
                }
                lineItemIDPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                lineItemIDPendingDeletion = nil
            }
        } message: {
            Text("This removes the selected line item from the invoice.")
        }
        .onChange(of: model.invoiceDraft?.value.id) { _, _ in
            resetEditorState()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if let oldValue {
                touchedFields.insert(oldValue)
            }
            if oldValue == .automaticGenerationInterval,
               newValue != .automaticGenerationInterval,
               autoGenerationIntervalDraftIsValid {
                autoGenerationIntervalDraft = nil
            }
        }
        .onChange(of: model.focusedEditorField) { _, field in
            guard let field, isInvoiceField(field) else { return }
            focusedField = field
        }
    }

    private func editor(session: DraftSession<Invoice>) -> some View {
        let invoice = draftInvoiceBinding(fallback: session.value)

        return GeometryReader { geometry in
            let presentation = WorkspaceLayoutPolicy.invoiceEditor(
                width: max(0, geometry.size.width),
                requested: requestedPresentation
            )

            VStack(spacing: 0) {
                if presentation != .sideBySide {
                    HStack {
                        Spacer()

                        Picker("Invoice mode", selection: $requestedPresentation) {
                            Text("Edit").tag(InvoiceEditorPresentation.edit)
                            Text("Preview").tag(InvoiceEditorPresentation.preview)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                }

                editorContent(
                    presentation: presentation,
                    invoice: invoice,
                    session: session
                )
            }
        }
        .navigationTitle(invoice.wrappedValue.number)
    }

    @ViewBuilder
    private func editorContent(
        presentation: InvoiceEditorPresentation,
        invoice: Binding<Invoice>,
        session: DraftSession<Invoice>
    ) -> some View {
        switch presentation {
        case .edit:
            invoiceFormPane(invoice: invoice, session: session)
        case .preview:
            invoicePreviewPane(invoice: invoice)
        case .sideBySide:
            HSplitView {
                invoiceFormPane(invoice: invoice, session: session)
                invoicePreviewPane(invoice: invoice)
            }
        }
    }

    private func invoiceFormPane(
        invoice: Binding<Invoice>,
        session: DraftSession<Invoice>
    ) -> some View {
        GeometryReader { geometry in
            let padding = WorkspaceContentMetrics.padding(for: geometry.size.width)
            let contentWidth = WorkspaceContentMetrics.contentWidth(for: geometry.size.width)
            let fieldRowWidth = max(0, contentWidth - (padding * 2) - 32)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        EditorActionBar(
                            title: "Invoice editor actions",
                            isDirty: session.isDirty
                                || hasInvalidNumericDraft
                                || !autoGenerationIntervalDraftIsValid,
                            save: saveInvoice,
                            cancel: cancelInvoice
                        )

                        invoiceDetailsCard(invoice: invoice, availableWidth: fieldRowWidth)
                        automaticGenerationCard(invoice: invoice)
                        lineItemsCard(
                            invoice: invoice,
                            proxy: proxy,
                            availableWidth: fieldRowWidth
                        )
                        notesAndTermsCard(invoice: invoice)
                        paymentAcceptanceCard(invoice: invoice)
                        summaryCard(invoice: invoice.wrappedValue)
                        invoiceActions(invoice: invoice)

                        if session.origin == .persisted {
                            VStack(alignment: .leading, spacing: 14) {
                                Button(role: .destructive) {
                                    isConfirmingDelete = true
                                } label: {
                                    Label("Delete Invoice", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RuneyButtonStyle(variant: .destructive))
                            }
                            .runeyCard()
                            .padding(.bottom, 24)
                        }
                    }
                    .padding(padding)
                    .responsiveEditorFrame(availableWidth: geometry.size.width)
                }
                .onChange(of: model.focusedEditorField) { _, field in
                    guard let itemID = lineItemID(from: field) else { return }
                    withAnimation {
                        proxy.scrollTo(itemID, anchor: .center)
                    }
                }
            }
        }
    }

    private func invoicePreviewPane(invoice: Binding<Invoice>) -> some View {
        InvoicePreviewView(
            invoice: invoice,
            book: model.book,
            isPaused: hasInvalidLineItemValues
        )
    }

    private func invoiceDetailsCard(
        invoice: Binding<Invoice>,
        availableWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Details")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)

            VStack(alignment: .leading, spacing: 14) {
                AdaptiveFieldRow(availableWidth: availableWidth) {
                    invoiceNumberField(invoice: invoice)
                    invoiceStatusField(invoice: invoice)
                }

                AdaptiveFieldRow(availableWidth: availableWidth) {
                    invoiceClientField(invoice: invoice)
                    invoiceProjectField(invoice: invoice)
                }

                AdaptiveFieldRow(availableWidth: availableWidth) {
                    invoiceIssueDateField(invoice: invoice)
                    invoiceDueDateField(invoice: invoice)
                }

                AdaptiveFieldRow(availableWidth: availableWidth) {
                    invoiceCurrencyField(invoice: invoice)
                    Color.clear.frame(height: 1)
                }
            }
        }
        .runeyCard()
    }

    private func invoiceNumberField(invoice: Binding<Invoice>) -> some View {
        runeyField(
            "Invoice Number",
            text: invoice.number,
            field: .invoiceNumber,
            issue: issueMessage(for: .invoiceNumber, invoice: invoice.wrappedValue)
        )
    }

    private func invoiceStatusField(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Status")
            Picker("", selection: invoice.status) {
                ForEach(InvoiceStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .frame(height: 30)
        }
    }

    private func invoiceClientField(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Client")
            Picker("", selection: invoice.clientId) {
                Text("Unassigned").tag(UUID?.none)
                ForEach(model.book.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }
            .frame(height: 30)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    editSelectedClientButton(invoice: invoice.wrappedValue)
                    manageClientsButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    editSelectedClientButton(invoice: invoice.wrappedValue)
                    manageClientsButton
                }
            }
        }
    }

    private func editSelectedClientButton(invoice: Invoice) -> some View {
        Button("Edit Selected Client") {
            editSelectedClient(invoice: invoice)
        }
        .buttonStyle(RuneyButtonStyle())
        .disabled(invoice.clientId == nil || hasInvalidUncommittedInput)
    }

    private var manageClientsButton: some View {
        Button("Manage Clients", action: manageClients)
            .buttonStyle(RuneyButtonStyle())
            .disabled(hasInvalidUncommittedInput)
    }

    private func invoiceProjectField(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Project")
            Picker("", selection: invoice.projectId) {
                Text("None").tag(UUID?.none)
                ForEach(model.book.projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
            .frame(height: 30)
        }
    }

    private func invoiceIssueDateField(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Issue Date")
            DatePicker("", selection: invoice.issueDate, displayedComponents: .date)
                .labelsHidden()
                .frame(height: 30)
        }
    }

    private func invoiceDueDateField(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Due Date")
            DatePicker("", selection: invoice.dueDate, displayedComponents: .date)
                .labelsHidden()
                .frame(height: 30)
            if let issue = issueMessage(
                for: .invoiceDueDate,
                invoice: invoice.wrappedValue
            ) {
                inlineIssue(issue)
            }
        }
    }

    private func invoiceCurrencyField(invoice: Binding<Invoice>) -> some View {
        runeyField(
            "Currency Code",
            text: invoice.currencyCode,
            field: .invoiceCurrency,
            issue: issueMessage(for: .invoiceCurrency, invoice: invoice.wrappedValue)
        )
    }

    private func automaticGenerationCard(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Automatic Generation")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)

            Toggle("Generate invoice copies", isOn: autoGenerationEnabledBinding(invoice: invoice))
                .toggleStyle(.switch)

            if invoice.wrappedValue.autoGeneration.isEnabled {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                    GridRow {
                        VStack(alignment: .leading, spacing: 6) {
                            RuneyFormLabel(title: "Interval")
                            HStack(spacing: 8) {
                                TextField("", text: autoGenerationIntervalTextBinding(invoice: invoice))
                                    .font(.system(.body, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .runeyFieldInput(width: 72)
                                    .focused($focusedField, equals: .automaticGenerationInterval)
                                    .onSubmit {
                                        touchedFields.insert(.automaticGenerationInterval)
                                        if autoGenerationIntervalDraftIsValid {
                                            autoGenerationIntervalDraft = nil
                                        }
                                    }

                                Text("days")
                                    .foregroundStyle(Color.runeyPrimary)
                            }
                            .frame(height: 30)

                            if let issue = automaticGenerationIssue(invoice: invoice.wrappedValue) {
                                inlineIssue(issue)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            RuneyFormLabel(title: "Next Date")
                            Text(DateFormatting.dateTime.string(
                                from: invoice.wrappedValue.autoGeneration.nextGenerationDate
                            ))
                            .foregroundStyle(Color.runeyPrimary)
                            .frame(height: 30, alignment: .center)
                        }
                    }
                }
            }
        }
        .runeyCard()
    }

    private func lineItemsCard(
        invoice: Binding<Invoice>,
        proxy: ScrollViewProxy,
        availableWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Line Items")
                    .font(.headline)
                    .foregroundStyle(Color.runeyPrimary)
                Spacer()
                Button {
                    let newItem = InvoiceLineItem(
                        title: "New Item",
                        quantity: 1,
                        unitPriceMinorUnits: 0
                    )
                    var value = invoice.wrappedValue
                    value.lineItems.append(newItem)
                    invoice.wrappedValue = value

                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(newItem.id, anchor: .center)
                        }
                        model.focusedEditorField = .lineItemTitle(newItem.id)
                        focusedField = .lineItemTitle(newItem.id)
                    }
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(RuneyButtonStyle())
            }

            ForEach(invoice.lineItems) { item in
                let itemID = item.wrappedValue.id
                VStack(spacing: 8) {
                    LineItemEditor(
                        item: item,
                        currencyCode: invoice.wrappedValue.currencyCode,
                        titleIssue: issueMessage(
                            for: .lineItemTitle(itemID),
                            invoice: invoice.wrappedValue
                        ),
                        quantityIssue: issueMessage(
                            for: .lineItemQuantity(itemID),
                            invoice: invoice.wrappedValue
                        ),
                        unitPriceIssue: issueMessage(
                            for: .lineItemUnitPrice(itemID),
                            invoice: invoice.wrappedValue
                        ),
                        taxRateIssue: issueMessage(
                            for: .lineItemTaxRate(itemID),
                            invoice: invoice.wrappedValue
                        ),
                        isTotalPaused: lineItemHasInvalidAmount(item.wrappedValue)
                            || numericFields(for: itemID).contains {
                                model.transientEditorInputIssue(for: $0) != nil
                            },
                        availableWidth: availableWidth,
                        numericInputResetGeneration: numericInputResetGeneration,
                        focusedField: $focusedField,
                        touched: { touchedFields.insert($0) },
                        numericValidityChanged: updateNumericValidity
                    )

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            lineItemIDPendingDeletion = itemID
                        } label: {
                            Label("Delete Item", systemImage: "trash")
                        }
                        .buttonStyle(RuneyButtonStyle(variant: .destructive))
                        .focusable(false)
                    }

                    Divider()
                        .background(Color.runeyBorder)
                }
                .id(itemID)
            }

            if invoice.wrappedValue.lineItems.isEmpty {
                Text("No line items added yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.runeyMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .runeyCard()
    }

    private func notesAndTermsCard(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes & Terms")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)

            VStack(alignment: .leading, spacing: 6) {
                RuneyFormLabel(title: "Memo / Client Notes")
                RuneyMultilineEditor(text: invoice.notes, minHeight: 78)
            }

            VStack(alignment: .leading, spacing: 6) {
                RuneyFormLabel(title: "Terms & Conditions")
                RuneyMultilineEditor(text: invoice.terms, minHeight: 58)
            }
        }
        .runeyCard()
    }

    private func paymentAcceptanceCard(invoice: Binding<Invoice>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Payment Acceptance")
                    .font(.headline)
                    .foregroundStyle(Color.runeyPrimary)
                Spacer()
                if !model.book.paymentAcceptanceDetails.isEmpty {
                    Button("Manage Payment Details", action: managePaymentDetails)
                        .buttonStyle(RuneyButtonStyle())
                        .disabled(hasInvalidUncommittedInput)
                }
            }

            if model.book.paymentAcceptanceDetails.isEmpty {
                VStack(spacing: 10) {
                    Text("No payment acceptance details available.")
                        .font(.subheadline)
                        .foregroundStyle(Color.runeyMuted)
                    Button("Add Payment Details", action: managePaymentDetails)
                        .buttonStyle(RuneyButtonStyle())
                        .disabled(hasInvalidUncommittedInput)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.book.paymentAcceptanceDetails) { detail in
                        Toggle(isOn: paymentDetailSelectionBinding(
                            for: detail.id,
                            invoice: invoice
                        )) {
                            PaymentAcceptanceSelectionLabel(detail: detail)
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.runeyBorder.opacity(0.7), lineWidth: 1)
                        }
                    }
                }
            }
        }
        .runeyCard()
    }

    @ViewBuilder
    private func summaryCard(invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)

            if hasInvalidLineItemValues {
                Label(
                    "Fix invalid line-item values to calculate totals.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.runeyDestructive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    summaryRow(
                        title: "Subtotal",
                        value: invoice.subtotalMinorUnits,
                        currencyCode: invoice.currencyCode
                    )
                    summaryRow(
                        title: "Estimated Tax",
                        value: invoice.taxMinorUnits,
                        currencyCode: invoice.currencyCode
                    )
                    summaryRow(
                        title: "Amount Paid",
                        value: invoice.paidMinorUnits,
                        currencyCode: invoice.currencyCode
                    )

                    Divider()
                        .background(Color.runeyBorder)
                        .padding(.vertical, 4)

                    HStack {
                        Text("Balance Due")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Color.runeyPrimary)
                        Spacer()
                        Text(Money.format(
                            minorUnits: invoice.balanceDueMinorUnits,
                            currencyCode: invoice.currencyCode
                        ))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(invoice.balanceDueMinorUnits > 0 ? Color.runeyPrimary : Color.runeySuccess)
                    }
                }
            }
        }
        .runeyCard()
    }

    private func invoiceActions(invoice: Binding<Invoice>) -> some View {
        HStack(spacing: 16) {
            Button {
                invoice.status.wrappedValue = .sent
            } label: {
                Label("Mark as Sent", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RuneyButtonStyle())
            .disabled(hasInvalidLineItemValues)
            .opacity(hasInvalidLineItemValues ? 0.5 : 1)

            if invoice.wrappedValue.status == .paid {
                Button {
                    isConfirmingMarkUnpaid = true
                } label: {
                    Label("Mark as Unpaid", systemImage: "arrow.uturn.backward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RuneyButtonStyle())
                .disabled(hasInvalidLineItemValues)
                .opacity(hasInvalidLineItemValues ? 0.5 : 1)
            } else {
                Button {
                    updateInvoice { draft in
                        draft.payments.append(Payment(amountMinorUnits: draft.balanceDueMinorUnits))
                        draft.refreshStatus()
                    }
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RuneyButtonStyle(variant: .success))
                .disabled(hasInvalidLineItemValues || invoice.wrappedValue.balanceDueMinorUnits == 0)
                .opacity(
                    hasInvalidLineItemValues || invoice.wrappedValue.balanceDueMinorUnits == 0
                        ? 0.5
                        : 1
                )
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    InvoiceTextRenderer.render(invoice: invoice.wrappedValue, book: model.book),
                    forType: .string
                )
            } label: {
                Label("Copy Raw Text", systemImage: "doc.on.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RuneyButtonStyle())
            .disabled(hasInvalidLineItemValues)
        }
    }

    private var hasInvalidNumericDraft: Bool {
        model.transientInputIssues(for: .invoice).contains {
            switch $0.field {
            case .lineItemQuantity(_), .lineItemUnitPrice(_), .lineItemTaxRate(_):
                return true
            default:
                return false
            }
        }
    }

    private var autoGenerationIntervalDraftIsValid: Bool {
        model.transientEditorInputIssue(for: .automaticGenerationInterval) == nil
    }

    private var hasInvalidLineItemValues: Bool {
        guard let invoice = model.invoiceDraft?.value else {
            return hasInvalidNumericDraft
        }
        return hasInvalidNumericDraft || invoice.lineItems.contains {
            lineItemHasInvalidAmount($0)
        }
    }

    private var hasInvalidUncommittedInput: Bool {
        hasInvalidNumericDraft || !autoGenerationIntervalDraftIsValid
    }

    private func draftInvoiceBinding(fallback: Invoice) -> Binding<Invoice> {
        Binding(
            get: { model.invoiceDraft?.value ?? fallback },
            set: { value in
                guard var session = model.invoiceDraft else { return }
                session.value = value
                model.invoiceDraft = session
            }
        )
    }

    private func updateInvoice(_ update: (inout Invoice) -> Void) {
        guard var session = model.invoiceDraft else { return }
        update(&session.value)
        model.invoiceDraft = session
    }

    private func saveInvoice() {
        guard let invoice = model.invoiceDraft?.value else { return }
        var issues = EditorValidator.invoiceIssues(for: invoice, in: model.book)

        for issue in numericDraftIssues(invoice: invoice) where !issues.contains(where: { $0.field == issue.field }) {
            issues.append(issue)
        }
        if !autoGenerationIntervalDraftIsValid,
           !issues.contains(where: { $0.field == .automaticGenerationInterval }) {
            issues.append(EditorIssue(
                field: .automaticGenerationInterval,
                message: "Automatic generation interval must be between 1 and 3650 days."
            ))
        }

        touchedFields.formUnion(issues.map(\.field))
        guard issues.isEmpty else {
            model.presentEditorIssues(issues)
            focusedField = issues.first?.field
            return
        }

        do {
            try model.commitInvoiceDraft()
            model.clearEditorIssues()
            touchedFields.removeAll()
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
            touchedFields.formUnion(error.issues.map(\.field))
            focusedField = error.issues.first?.field
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func cancelInvoice() {
        let baselineID = model.invoiceDraft?.origin == .persisted
            ? model.invoiceDraft?.baseline.id
            : nil

        model.cancelInvoiceDraft()
        model.clearEditorIssues()
        resetEditorState()

        if let baselineID {
            model.beginEditingInvoice(id: baselineID)
        }
    }

    private func manageClients() {
        model.requestNavigation(to: .section(.clients), preserveCurrentDraft: true)
    }

    private func editSelectedClient(invoice: Invoice) {
        guard let id = invoice.clientId else { return }
        model.requestNavigation(to: .client(id), preserveCurrentDraft: true)
        model.beginEditingClient(id: id)
    }

    private func managePaymentDetails() {
        model.requestNavigation(to: .section(.settings), preserveCurrentDraft: true)
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        } else {
            model.activeDraftRoute = .settings
        }
    }

    private func autoGenerationEnabledBinding(invoice: Binding<Invoice>) -> Binding<Bool> {
        Binding(
            get: { invoice.wrappedValue.autoGeneration.isEnabled },
            set: { isEnabled in
                var value = invoice.wrappedValue
                let intervalDays = InvoiceAutoGenerationSettings.normalizedIntervalDays(
                    value.autoGeneration.intervalDays
                )
                value.autoGeneration.intervalDays = intervalDays
                if isEnabled,
                   (!value.autoGeneration.isEnabled || value.autoGeneration.nextGenerationDate <= Date()) {
                    value.autoGeneration.nextGenerationDate = InvoiceAutoGenerationSettings.nextGenerationDate(
                        intervalDays: intervalDays
                    )
                }
                value.autoGeneration.isEnabled = isEnabled
                if !isEnabled {
                    autoGenerationIntervalDraft = nil
                    model.clearTransientEditorInputIssue(for: .automaticGenerationInterval)
                }
                invoice.wrappedValue = value
            }
        )
    }

    private func autoGenerationIntervalTextBinding(invoice: Binding<Invoice>) -> Binding<String> {
        Binding(
            get: {
                autoGenerationIntervalDraft
                    ?? InvoiceAutoGenerationIntervalInput.text(
                        for: invoice.wrappedValue.autoGeneration.intervalDays
                    )
            },
            set: { newValue in
                autoGenerationIntervalDraft = newValue
                guard let intervalDays = InvoiceAutoGenerationIntervalInput.intervalDays(from: newValue) else {
                    model.updateTransientEditorInputValidity(
                        field: .automaticGenerationInterval,
                        isValid: false,
                        invalidMessage: "Automatic generation interval must be between 1 and 3650 days."
                    )
                    return
                }

                model.updateTransientEditorInputValidity(
                    field: .automaticGenerationInterval,
                    isValid: true,
                    invalidMessage: "Automatic generation interval must be between 1 and 3650 days."
                )
                var value = invoice.wrappedValue
                value.autoGeneration.intervalDays = intervalDays
                if value.autoGeneration.isEnabled {
                    value.autoGeneration.nextGenerationDate = InvoiceAutoGenerationSettings.nextGenerationDate(
                        intervalDays: intervalDays
                    )
                }
                invoice.wrappedValue = value
            }
        )
    }

    private func paymentDetailSelectionBinding(
        for detailID: UUID,
        invoice: Binding<Invoice>
    ) -> Binding<Bool> {
        Binding(
            get: { invoice.wrappedValue.acceptedPaymentDetailIDs.contains(detailID) },
            set: { isSelected in
                var value = invoice.wrappedValue
                if isSelected {
                    if !value.acceptedPaymentDetailIDs.contains(detailID) {
                        value.acceptedPaymentDetailIDs.append(detailID)
                    }
                } else {
                    value.acceptedPaymentDetailIDs.removeAll { $0 == detailID }
                }
                invoice.wrappedValue = value
            }
        )
    }

    private func updateNumericValidity(field: EditorField, isValid: Bool) {
        let message: String
        switch field {
        case .lineItemQuantity(_):
            message = "Enter a valid line item quantity."
        case .lineItemUnitPrice(_):
            message = "Enter a valid line item unit price."
        case .lineItemTaxRate(_):
            message = "Enter a valid line item tax rate."
        default:
            return
        }
        model.updateTransientEditorInputValidity(
            field: field,
            isValid: isValid,
            invalidMessage: message
        )
    }

    private func numericDraftIssues(invoice: Invoice) -> [EditorIssue] {
        var issues: [EditorIssue] = []
        for item in invoice.lineItems {
            let messages: [(EditorField, String)] = [
                (.lineItemQuantity(item.id), "Enter a valid line item quantity."),
                (.lineItemUnitPrice(item.id), "Enter a valid line item unit price."),
                (.lineItemTaxRate(item.id), "Enter a valid line item tax rate.")
            ]
            for (field, message) in messages
            where model.transientEditorInputIssue(for: field) != nil {
                issues.append(EditorIssue(field: field, message: message))
            }
        }
        return issues
    }

    private func issueMessage(for field: EditorField, invoice: Invoice) -> String? {
        let wasSubmitted = model.editorIssues.contains(where: { $0.field == field })
        guard touchedFields.contains(field) || wasSubmitted else { return nil }

        if let issue = EditorValidator.invoiceIssues(for: invoice, in: model.book)
            .first(where: { $0.field == field }) {
            return issue.message
        }
        if wasSubmitted, model.transientEditorInputIssue(for: field) != nil {
            return numericDraftIssues(invoice: invoice).first(where: { $0.field == field })?.message
        }
        return nil
    }

    private func automaticGenerationIssue(invoice: Invoice) -> String? {
        guard touchedFields.contains(.automaticGenerationInterval)
                || model.editorIssues.contains(where: { $0.field == .automaticGenerationInterval }) else {
            return nil
        }
        if !autoGenerationIntervalDraftIsValid {
            return "Automatic generation interval must be between 1 and 3650 days."
        }
        return issueMessage(for: .automaticGenerationInterval, invoice: invoice)
    }

    private func numericFields(for itemID: UUID) -> [EditorField] {
        [
            .lineItemQuantity(itemID),
            .lineItemUnitPrice(itemID),
            .lineItemTaxRate(itemID)
        ]
    }

    private func lineItemHasInvalidAmount(_ item: InvoiceLineItem) -> Bool {
        item.quantity <= 0
            || !item.quantity.isFinite
            || item.unitPriceMinorUnits < 0
            || item.taxRatePercent < 0
            || item.taxRatePercent > 100
            || !item.taxRatePercent.isFinite
    }

    private func removeFieldState(forLineItemID id: UUID) {
        let fields: [EditorField] = [
            .lineItemTitle(id),
            .lineItemQuantity(id),
            .lineItemUnitPrice(id),
            .lineItemTaxRate(id)
        ]
        touchedFields.subtract(Set(fields))
        for field in fields {
            model.clearTransientEditorInputIssue(for: field)
        }
    }

    private func lineItemID(from field: EditorField?) -> UUID? {
        guard let field else { return nil }
        switch field {
        case let .lineItemTitle(id),
             let .lineItemQuantity(id),
             let .lineItemUnitPrice(id),
             let .lineItemTaxRate(id):
            return id
        default:
            return nil
        }
    }

    private func isInvoiceField(_ field: EditorField) -> Bool {
        switch field {
        case .invoiceNumber,
             .invoiceDueDate,
             .invoiceCurrency,
             .automaticGenerationInterval,
             .lineItemTitle(_),
             .lineItemQuantity(_),
             .lineItemUnitPrice(_),
             .lineItemTaxRate(_):
            return true
        default:
            return false
        }
    }

    private func resetEditorState() {
        autoGenerationIntervalDraft = nil
        touchedFields.removeAll()
        numericInputResetGeneration += 1
        focusedField = nil
    }

    private func runeyField(
        _ label: String,
        text: Binding<String>,
        field: EditorField? = nil,
        issue: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: label)
            if let field {
                TextField("", text: text)
                    .runeyFieldInput()
                    .focused($focusedField, equals: field)
            } else {
                TextField("", text: text)
                    .runeyFieldInput()
            }
            if let issue {
                inlineIssue(issue)
            }
        }
    }

    private func inlineIssue(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.runeyDestructive)
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
    var titleIssue: String?
    var quantityIssue: String?
    var unitPriceIssue: String?
    var taxRateIssue: String?
    var isTotalPaused: Bool
    var availableWidth: CGFloat
    var numericInputResetGeneration: Int
    var focusedField: FocusState<EditorField?>.Binding
    var touched: (EditorField) -> Void
    var numericValidityChanged: (EditorField, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdaptiveFieldRow(availableWidth: availableWidth, spacing: 12) {
                titleField
                quantityField
                unitPriceField
                taxRateField
                totalField
            }

            detailsField
        }
        .padding(.vertical, 5)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Title")
            TextField("", text: $item.title)
                .runeyFieldInput()
                .focused(focusedField, equals: .lineItemTitle(item.id))
            if let titleIssue {
                inlineIssue(titleIssue)
            }
        }
    }

    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Qty")
            RuneyDecimalTextField(
                value: $item.quantity,
                width: 60,
                resetID: NumericEditorResetID(
                    entityID: item.id,
                    generation: numericInputResetGeneration
                ),
                onValidityChanged: {
                    numericValidityChanged(.lineItemQuantity(item.id), $0)
                },
                onCommitDraft: { touched(.lineItemQuantity(item.id)) }
            )
            .focused(focusedField, equals: .lineItemQuantity(item.id))
            if let quantityIssue {
                inlineIssue(quantityIssue)
            }
        }
    }

    private var unitPriceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Unit Price")
            RuneyMoneyTextField(
                minorUnits: $item.unitPriceMinorUnits,
                width: 84,
                resetID: NumericEditorResetID(
                    entityID: item.id,
                    generation: numericInputResetGeneration
                ),
                onValidityChanged: {
                    numericValidityChanged(.lineItemUnitPrice(item.id), $0)
                },
                onCommitDraft: { touched(.lineItemUnitPrice(item.id)) }
            )
            .focused(focusedField, equals: .lineItemUnitPrice(item.id))
            if let unitPriceIssue {
                inlineIssue(unitPriceIssue)
            }
        }
    }

    private var taxRateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Tax %")
            RuneyDecimalTextField(
                value: $item.taxRatePercent,
                width: 56,
                resetID: NumericEditorResetID(
                    entityID: item.id,
                    generation: numericInputResetGeneration
                ),
                onValidityChanged: {
                    numericValidityChanged(.lineItemTaxRate(item.id), $0)
                },
                onCommitDraft: { touched(.lineItemTaxRate(item.id)) }
            )
            .focused(focusedField, equals: .lineItemTaxRate(item.id))
            if let taxRateIssue {
                inlineIssue(taxRateIssue)
            }
        }
    }

    private var totalField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            RuneyFormLabel(title: "Total")
            if isTotalPaused {
                Text("—")
                    .foregroundStyle(Color.runeyMuted)
                    .frame(height: 28, alignment: .trailing)
            } else {
                Text(Money.format(
                    minorUnits: item.totalMinorUnits,
                    currencyCode: currencyCode
                ).replacingOccurrences(of: currencyCode + " ", with: ""))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(Color.runeyPrimary)
                .frame(height: 28, alignment: .trailing)
            }
        }
    }

    private var detailsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Item Details")
            RuneyMultilineEditor(text: $item.details, minHeight: 52)
        }
    }

    private func inlineIssue(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.runeyDestructive)
    }
}

import SwiftUI
import InvoiceCore
import AppKit

enum SettingsPresentation {
    case workspace
    case dedicated
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let sceneID: UUID
    let presentation: SettingsPresentation
    @State private var paymentDetailIDPendingDeletion: UUID?
    @State private var paymentTermsDraft: String?
    @State private var inputResetGeneration = 0
    @State private var touchedFields: Set<EditorField> = []
    @State private var commandTargetID = UUID()
    @FocusState private var focusedField: EditorField?

    var body: some View {
        Group {
            if let session = model.settingsDraft {
                settingsEditor(session: session)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .focusedSceneValue(
            \.draftCommandTarget,
            DraftCommandTarget(
                id: commandTargetID,
                kind: .settings,
                save: saveSettings,
                cancel: cancelSettings
            )
        )
        .onAppear(perform: activateSettingsDraft)
        .onDisappear {
            model.cancelStoreReplacement(from: sceneID)
        }
        .onChange(of: model.storeReplacementGeneration) { _, _ in
            activateSettingsDraftAfterBookReplacement()
        }
        .onChange(of: focusedField) { oldValue, _ in
            if let oldValue {
                touchedFields.insert(oldValue)
            }
        }
        .onChange(of: model.focusedEditorField) { _, field in
            guard let field, isSettingsField(field) else { return }
            focusedField = field
        }
        .alert("Replace local data?", isPresented: replacementConfirmationPresented) {
            Button(scenePendingStoreReplacement?.request.actionTitle ?? "Replace Local Data", role: .destructive) {
                model.confirmStoreReplacement(from: sceneID)
            }
            Button("Cancel", role: .cancel) {
                model.cancelStoreReplacement(from: sceneID)
            }
        } message: {
            Text(replacementWarning)
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

    private func settingsEditor(session: DraftSession<WorkspaceSettingsDraft>) -> some View {
        let settings = settingsBinding(fallback: session.value)
        let isDirty = session.isDirty || paymentTermsDraft != nil

        return GeometryReader { geometry in
            let padding = WorkspaceContentMetrics.padding(for: geometry.size.width)
            let contentWidth = WorkspaceContentMetrics.contentWidth(for: geometry.size.width)
            let fieldRowWidth = max(0, contentWidth - (padding * 2) - 32)
            let paymentDetailFieldRowWidth = max(0, fieldRowWidth - 24)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        if contextualInvoiceNumber != nil {
                            Button(returnToInvoiceTitle, action: returnToInvoice)
                                .buttonStyle(RuneyButtonStyle())
                                .disabled(isDirty)
                                .help(isDirty ? "Save or Cancel business and payment changes before returning." : "")
                        }

                        EditorActionBar(
                            title: "Business and payment editor actions",
                            isDirty: isDirty,
                            save: saveSettings,
                            cancel: cancelSettings
                        )
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Business Profile")
                            .font(.headline)
                            .foregroundStyle(Color.runeyPrimary)

                        VStack(alignment: .leading, spacing: 14) {
                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                businessNameField(settings: settings)
                                businessEmailField(settings: settings)
                            }

                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                businessTaxIdentifierField(settings: settings)
                                businessCurrencyField(settings: settings)
                            }

                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                businessAddressField(settings: settings)
                                paymentTermsField(settings: settings)
                            }
                        }
                    }
                    .runeyCard()

                    VStack(alignment: .leading, spacing: 16) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Payment Acceptance Details")
                                    .font(.headline)
                                    .foregroundStyle(Color.runeyPrimary)

                                Spacer()

                                paymentAcceptanceAddActions
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Payment Acceptance Details")
                                    .font(.headline)
                                    .foregroundStyle(Color.runeyPrimary)

                                paymentAcceptanceAddActions
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if settings.wrappedValue.paymentAcceptanceDetails.isEmpty {
                            Text("No payment details saved.")
                                .font(.subheadline)
                                .foregroundStyle(Color.runeyMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(settings.paymentAcceptanceDetails) { detail in
                                    let detailID = detail.wrappedValue.id
                                    PaymentAcceptanceDetailEditor(
                                        detail: detail,
                                        issue: issueMessage(
                                            for: .paymentDetailLabel(detailID),
                                            settings: settings.wrappedValue
                                        ),
                                        availableWidth: paymentDetailFieldRowWidth,
                                        focusedField: $focusedField,
                                        onDelete: { paymentDetailIDPendingDeletion = detailID }
                                    )
                                }
                            }
                        }
                    }
                    .runeyCard()

                    localStorageCard
                }
                .padding(padding)
                .responsiveEditorFrame(availableWidth: geometry.size.width)
            }
        }
    }

    private func businessNameField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        runeyField("Business Name", text: settings.businessProfile.name)
    }

    private func businessEmailField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        runeyField("Billing Email Address", text: settings.businessProfile.email)
    }

    private func businessTaxIdentifierField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        runeyField(
            "Tax Identifier (e.g. VAT / EIN)",
            text: settings.businessProfile.taxIdentifier
        )
    }

    private func businessCurrencyField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        runeyField(
            "Currency Code (e.g. USD / EUR)",
            text: settings.businessProfile.currencyCode,
            field: .businessCurrency,
            issue: issueMessage(
                for: .businessCurrency,
                settings: settings.wrappedValue
            )
        )
    }

    private func businessAddressField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        runeyField(
            "Business Address",
            text: settings.businessProfile.address,
            isMultiline: true
        )
    }

    private func paymentTermsField(
        settings: Binding<WorkspaceSettingsDraft>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Payment Terms (Due Date Offset)")

            HStack(spacing: 8) {
                Text("Net")
                    .font(.body)
                    .foregroundStyle(Color.runeyPrimary)

                RuneyIntegerTextField(
                    value: settings.businessProfile.paymentTermsDays,
                    draft: $paymentTermsDraft,
                    validRange: 0...120,
                    width: 56,
                    resetID: inputResetGeneration,
                    accessibilityLabel: "Payment terms in days",
                    onValidityChange: { isValid in
                        model.updateTransientEditorInputValidity(
                            field: .paymentTermsDays,
                            isValid: isValid,
                            invalidMessage: "Payment terms must be a whole number between 0 and 120 days."
                        )
                    }
                )
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .paymentTermsDays)

                Text("Days")
                    .font(.body)
                    .foregroundStyle(Color.runeyPrimary)
            }
            .frame(height: 30)

            if let issue = model.transientEditorInputIssue(for: .paymentTermsDays)?.message {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            } else if let issue = issueMessage(
                for: .paymentTermsDays,
                settings: settings.wrappedValue
            ) {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
    }

    private var localStorageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local Data Storage")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)

            VStack(alignment: .leading, spacing: 6) {
                RuneyFormLabel(title: "Active Store Path")

                Text(model.store.url.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.runeyPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        storageMaintenanceActionButtons(fullWidth: false)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        storageMaintenanceActionButtons(fullWidth: true)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        storageLocationActionButtons(fullWidth: false)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        storageLocationActionButtons(fullWidth: true)
                    }
                }
            }
            .padding(.top, 4)
        }
        .runeyCard()
    }

    @ViewBuilder
    private var paymentAcceptanceAddActions: some View {
        Button {
            model.addPaymentAcceptanceDetail(kind: .bankDetails)
        } label: {
            Label("Add Bank Details", systemImage: "building.columns")
        }
        .buttonStyle(RuneyButtonStyle())

        Button {
            model.addPaymentAcceptanceDetail(kind: .cryptocurrency)
        } label: {
            Label("Add Cryptocurrency", systemImage: "bitcoinsign.circle")
        }
        .buttonStyle(RuneyButtonStyle())
    }

    @ViewBuilder
    private func storageMaintenanceActionButtons(fullWidth: Bool) -> some View {
        Button {
            model.requestStoreReplacement(.reloadFromDisk, from: sceneID)
        } label: {
            Label("Reload From Disk", systemImage: "arrow.clockwise")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle())
        .help("Reload the local store from disk after confirmation.")

        Button(action: exportStoreBackup) {
            Label("Export Backup", systemImage: "square.and.arrow.up")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle())

        Button(action: chooseStoreBackupToRestore) {
            Label("Restore Backup", systemImage: "arrow.down.doc")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle())

        Button {
            model.requestStoreReplacement(.sampleData, from: sceneID)
        } label: {
            Label("Seed Sample Data", systemImage: "doc.text.fill.badge.plus")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle(variant: .prominent))
    }

    @ViewBuilder
    private func storageLocationActionButtons(fullWidth: Bool) -> some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([model.store.url])
        } label: {
            Label("Open Store Folder", systemImage: "folder")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle())

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.store.url.path, forType: .string)
            model.errorMessage = "Copied local store path."
        } label: {
            Label("Copy Store Path", systemImage: "doc.on.doc")
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(RuneyButtonStyle())
    }

    private func settingsBinding(fallback: WorkspaceSettingsDraft) -> Binding<WorkspaceSettingsDraft> {
        Binding(
            get: { model.settingsDraft?.value ?? fallback },
            set: { value in
                guard var session = model.settingsDraft else { return }
                session.value = value
                model.settingsDraft = session
            }
        )
    }

    private var contextualInvoiceNumber: String? {
        guard presentation == .workspace,
              model.contextualReturnSection == .invoices,
              let invoice = model.invoiceDraft?.value else { return nil }
        return invoice.number.isEmpty ? "Invoice" : invoice.number
    }

    private var returnToInvoiceTitle: String {
        "Return to \(contextualInvoiceNumber ?? "Invoice")"
    }

    private func activateSettingsDraft() {
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        }
    }

    private func activateSettingsDraftAfterBookReplacement() {
        paymentDetailIDPendingDeletion = nil
        resetPaymentTermsInput()
        touchedFields.removeAll()
        focusedField = nil
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        }
    }

    private var scenePendingStoreReplacement: PendingStoreReplacement? {
        guard let pendingStoreReplacement = model.pendingStoreReplacement,
              pendingStoreReplacement.sceneID == sceneID else { return nil }
        return pendingStoreReplacement
    }

    private var replacementConfirmationPresented: Binding<Bool> {
        Binding(
            get: { scenePendingStoreReplacement != nil },
            set: { isPresented in
                guard !isPresented else { return }
                model.cancelStoreReplacement(from: sceneID)
            }
        )
    }

    private var replacementWarning: String {
        guard scenePendingStoreReplacement != nil else { return "" }
        let dirty = model.dirtyDraftKinds.map(\.displayName)
        let suffix = dirty.isEmpty
            ? ""
            : " Unsaved \(ListFormatter.localizedString(byJoining: dirty)) changes will be discarded."
        return "This replaces the complete local invoice store.\(suffix)"
    }

    private func saveSettings() {
        guard let settings = model.settingsDraft?.value else { return }
        var issues = EditorValidator.settingsIssues(for: settings)
        for issue in model.transientInputIssues(for: .settings)
        where !issues.contains(where: { $0.field == issue.field }) {
            issues.append(issue)
        }
        touchedFields.formUnion(issues.map(\.field))

        guard issues.isEmpty else {
            model.presentEditorIssues(issues)
            focusedField = issues.first?.field
            return
        }

        do {
            try model.commitSettingsDraft()
            model.clearEditorIssues()
            resetPaymentTermsInput()
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
            focusedField = error.issues.first?.field
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func cancelSettings() {
        let wasContextual = contextualInvoiceNumber != nil
        model.cancelSettingsDraft()
        model.clearEditorIssues()
        resetPaymentTermsInput()
        touchedFields.removeAll()

        if wasContextual {
            returnToInvoice()
        } else {
            model.beginEditingSettings()
        }
    }

    private func returnToInvoice() {
        guard model.settingsDraft?.isDirty != true else { return }
        model.cancelSettingsDraft()
        resetPaymentTermsInput()
        model.contextualReturnSection = nil
        model.activeDraftRoute = .invoice
        model.selectedSection = .invoices
    }

    private func resetPaymentTermsInput() {
        inputResetGeneration &+= 1
        paymentTermsDraft = nil
        model.clearTransientEditorInputIssue(for: .paymentTermsDays)
    }

    private func issueMessage(
        for field: EditorField,
        settings: WorkspaceSettingsDraft
    ) -> String? {
        guard touchedFields.contains(field) || model.editorIssues.contains(where: { $0.field == field }) else {
            return nil
        }
        return EditorValidator.settingsIssues(for: settings).first(where: { $0.field == field })?.message
    }

    private func isSettingsField(_ field: EditorField) -> Bool {
        switch field {
        case .businessCurrency, .paymentTermsDays, .paymentDetailLabel(_):
            return true
        default:
            return false
        }
    }

    private func exportStoreBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Local-Invoice-store-backup.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.exportStore(to: url)
        }
    }

    private func chooseStoreBackupToRestore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.requestStoreReplacement(.backup(url), from: sceneID)
        }
    }

    private func runeyField(
        _ label: String,
        text: Binding<String>,
        field: EditorField? = nil,
        issue: String? = nil,
        isMultiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: label)
            if isMultiline {
                RuneyMultilineEditor(text: text, accessibilityLabel: label)
            } else if let field {
                TextField("", text: text)
                    .accessibilityLabel(label)
                    .runeyFieldInput()
                    .focused($focusedField, equals: field)
            } else {
                TextField("", text: text)
                    .accessibilityLabel(label)
                    .runeyFieldInput()
            }
            if let issue {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
    }
}

struct PaymentAcceptanceDetailEditor: View {
    @Binding var detail: PaymentAcceptanceDetail
    var issue: String?
    var availableWidth: CGFloat
    var focusedField: FocusState<EditorField?>.Binding
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
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(RuneyButtonStyle(variant: .destructiveIcon))
                .accessibilityLabel(
                    "Delete payment details \(detail.label.isEmpty ? detail.kind.label : detail.label)"
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                AdaptiveFieldRow(availableWidth: availableWidth) {
                    typeField
                    labelField
                }

                detailsField
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.runeyBorder.opacity(0.7), lineWidth: 1)
        }
    }

    private var typeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)
            Picker("", selection: $detail.kind) {
                ForEach(PaymentAcceptanceKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .accessibilityLabel("Payment detail type")
            .frame(height: 30)
        }
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Label")
            TextField("", text: $detail.label)
                .accessibilityLabel("Payment detail label")
                .runeyFieldInput()
                .focused(focusedField, equals: .paymentDetailLabel(detail.id))
            if let issue {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
    }

    private var detailsField: some View {
        PaymentDetailLinesEditor(details: $detail.details)
    }
}

struct PaymentDetailLinesEditor: View {
    @Binding var details: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RuneyFormLabel(title: "Detail Lines")
            RuneyMultilineEditor(
                text: $details,
                minHeight: 72,
                accessibilityLabel: "Payment detail lines"
            )
        }
    }
}

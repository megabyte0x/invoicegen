import SwiftUI
import InvoiceCore

struct ClientsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPresentingDetail = false

    private var filteredClients: [Client] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.book.clients
            .filter { client in
                guard !query.isEmpty else { return true }
                return client.name.localizedCaseInsensitiveContains(query)
                    || client.company.localizedCaseInsensitiveContains(query)
                    || client.email.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        AdaptiveMasterDetailView(
            hasDetail: isPresentingDetail,
            back: { isPresentingDetail = false }
        ) {
            List(selection: clientSelection) {
                ForEach(filteredClients) { client in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.runeyPrimary)
                        Text(client.email.isEmpty ? client.company : client.email)
                            .font(.caption)
                            .foregroundStyle(Color.runeyMuted)
                    }
                    .padding(.vertical, 4)
                    .tag(client.id)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                Button {
                    isPresentingDetail = true
                    model.requestNavigation(to: .newClient)
                } label: {
                    Label("New Client", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        } detail: {
            if model.clientDraft != nil {
                ClientEditorView()
            } else {
                VStack(spacing: 16) {
                    EmptyStateView(
                        title: "Select a client",
                        subtitle: "Clients anchor projects and invoices.",
                        systemImage: "person.2.fill"
                    )

                    if contextualInvoiceNumber != nil {
                        Button(returnToInvoiceTitle, action: returnToInvoice)
                            .buttonStyle(RuneyButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("Clients")
        .onAppear {
            if model.selectedClientID != nil || model.clientDraft != nil {
                isPresentingDetail = true
            }
            activateSelectedClientIfNeeded()
        }
        .onChange(of: model.selectedClientID) { _, id in
            if id != nil {
                isPresentingDetail = true
                activateSelectedClientIfNeeded()
            } else if model.clientDraft == nil {
                isPresentingDetail = false
            }
        }
        .onChange(of: model.clientDraft?.value.id) { _, id in
            if id != nil {
                isPresentingDetail = true
            } else if model.selectedClientID == nil {
                isPresentingDetail = false
            }
        }
    }

    private var clientSelection: Binding<UUID?> {
        Binding(
            get: { isPresentingDetail ? model.selectedClientID : nil },
            set: { id in
                guard let id else { return }
                isPresentingDetail = true
                guard model.clientDraft?.value.id != id else { return }
                model.requestNavigation(to: .client(id))
            }
        )
    }

    private var contextualInvoiceNumber: String? {
        guard model.contextualReturnSection == .invoices,
              let invoice = model.invoiceDraft?.value else { return nil }
        return invoice.number.isEmpty ? "Invoice" : invoice.number
    }

    private var returnToInvoiceTitle: String {
        "Return to \(contextualInvoiceNumber ?? "Invoice")"
    }

    private func activateSelectedClientIfNeeded() {
        if model.clientDraft != nil {
            model.activeDraftRoute = .client
        }
        let id = model.selectedClientID ?? filteredClients.first?.id
        guard let id else { return }
        guard model.clientDraft?.value.id != id else { return }
        guard model.clientDraft?.isDirty != true else { return }
        model.beginEditingClient(id: id)
    }

    private func returnToInvoice() {
        model.contextualReturnSection = nil
        model.activeDraftRoute = .invoice
        model.selectedSection = .invoices
    }
}

struct ClientEditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isConfirmingDelete = false
    @State private var touchedFields: Set<EditorField> = []
    @State private var commandTargetID = UUID()
    @FocusState private var focusedField: EditorField?

    var body: some View {
        Group {
            if let session = model.clientDraft {
                editor(session: session)
            } else {
                EmptyStateView(
                    title: "Select a client",
                    subtitle: "Clients anchor projects and invoices.",
                    systemImage: "person.2.fill"
                )
            }
        }
        .focusedSceneValue(
            \.draftCommandTarget,
            DraftCommandTarget(
                id: commandTargetID,
                kind: .client,
                save: saveClient,
                cancel: cancelClient
            )
        )
        .onChange(of: focusedField) { oldValue, _ in
            if let oldValue {
                touchedFields.insert(oldValue)
            }
        }
        .onChange(of: model.focusedEditorField) { _, field in
            guard field == .clientName else { return }
            focusedField = field
        }
        .alert("Delete client?", isPresented: $isConfirmingDelete) {
            Button("Delete Client", role: .destructive) {
                model.deleteSelectedClient()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the client from the local store and unassigns it from related invoices and projects.")
        }
    }

    private func editor(session: DraftSession<Client>) -> some View {
        let client = draftClientBinding(fallback: session.value)

        return GeometryReader { geometry in
            let padding = WorkspaceContentMetrics.padding(for: geometry.size.width)
            let contentWidth = WorkspaceContentMetrics.contentWidth(for: geometry.size.width)
            let fieldRowWidth = max(0, contentWidth - (padding * 2) - 32)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        if contextualInvoiceNumber != nil {
                            Button(returnToInvoiceTitle, action: returnToInvoice)
                                .buttonStyle(RuneyButtonStyle())
                                .disabled(session.isDirty)
                                .help(session.isDirty ? "Save or Cancel client changes before returning." : "")
                        }

                        EditorActionBar(
                            title: "Client editor actions",
                            isDirty: session.isDirty,
                            save: saveClient,
                            cancel: cancelClient
                        )
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Client Information")
                            .font(.headline)
                            .foregroundStyle(Color.runeyPrimary)

                        VStack(alignment: .leading, spacing: 14) {
                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                runeyField(
                                    "Client Name",
                                    text: client.name,
                                    field: .clientName,
                                    issue: issueMessage(for: .clientName, client: client.wrappedValue)
                                )
                                runeyField("Company / Organization", text: client.company)
                            }

                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                runeyField("Email Address", text: client.email)
                                runeyField("Billing Address", text: client.address, isMultiline: true)
                            }
                        }
                    }
                    .runeyCard()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Internal Notes")
                            .font(.headline)
                            .foregroundStyle(Color.runeyPrimary)

                        RuneyMultilineEditor(
                            text: client.notes,
                            minHeight: 120,
                            accessibilityLabel: "Internal notes"
                        )
                    }
                    .runeyCard()

                    if session.origin == .persisted {
                        VStack(alignment: .leading, spacing: 14) {
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Label("Delete Client", systemImage: "trash.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(RuneyButtonStyle(variant: .destructive))
                        }
                        .runeyCard()
                    }
                }
                .padding(padding)
                .responsiveEditorFrame(availableWidth: geometry.size.width)
            }
        }
        .navigationTitle(client.wrappedValue.name)
    }

    private func draftClientBinding(fallback: Client) -> Binding<Client> {
        Binding(
            get: { model.clientDraft?.value ?? fallback },
            set: { value in
                guard var session = model.clientDraft else { return }
                session.value = value
                model.clientDraft = session
            }
        )
    }

    private var contextualInvoiceNumber: String? {
        guard model.contextualReturnSection == .invoices,
              let invoice = model.invoiceDraft?.value else { return nil }
        return invoice.number.isEmpty ? "Invoice" : invoice.number
    }

    private var returnToInvoiceTitle: String {
        "Return to \(contextualInvoiceNumber ?? "Invoice")"
    }

    private func saveClient() {
        guard let client = model.clientDraft?.value else { return }
        let issues = EditorValidator.clientIssues(for: client)
        touchedFields.formUnion(issues.map(\.field))

        do {
            try model.commitClientDraft()
            model.clearEditorIssues()
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
            focusedField = error.issues.first?.field
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func cancelClient() {
        let wasContextual = contextualInvoiceNumber != nil
        let baselineID = model.clientDraft?.origin == .persisted
            ? model.clientDraft?.baseline.id
            : nil

        model.cancelClientDraft()
        model.clearEditorIssues()
        touchedFields.removeAll()

        if wasContextual {
            returnToInvoice()
        } else if let baselineID {
            model.beginEditingClient(id: baselineID)
        }
    }

    private func returnToInvoice() {
        guard model.clientDraft?.isDirty != true else { return }
        model.cancelClientDraft()
        model.contextualReturnSection = nil
        model.activeDraftRoute = .invoice
        model.selectedSection = .invoices
    }

    private func issueMessage(for field: EditorField, client: Client) -> String? {
        guard touchedFields.contains(field) || model.editorIssues.contains(where: { $0.field == field }) else {
            return nil
        }
        return EditorValidator.clientIssues(for: client).first(where: { $0.field == field })?.message
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

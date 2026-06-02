import SwiftUI
import InvoiceCore

struct ClientsView: View {
    @EnvironmentObject private var model: AppModel

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
        NavigationSplitView {
            List(selection: $model.selectedClientID) {
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
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    model.addClient()
                }) {
                    Label("New Client", systemImage: "plus")
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
            if let id = model.selectedClientID,
               let binding = model.clientBinding(id: id) {
                ClientEditorView(client: binding)
            } else {
                EmptyStateView(title: "Select a client", subtitle: "Clients anchor projects and invoices.", systemImage: "person.2.fill")
            }
        }
        .navigationTitle("Clients")
        .onAppear {
            if model.selectedClientID == nil {
                model.selectedClientID = filteredClients.first?.id
            }
        }
    }
}

struct ClientEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var client: Client

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Client Information")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            runeyField("Client Name", text: $client.name)
                            runeyField("Company / Organization", text: $client.company)
                        }
                        
                        GridRow {
                            runeyField("Email Address", text: $client.email)
                            runeyField("Billing Address", text: $client.address, isMultiline: true)
                        }
                    }
                }
                .runeyCard()
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Internal Notes")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    TextEditor(text: $client.notes)
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.runeyBorder, lineWidth: 1)
                        }
                }
                .runeyCard()
                
                // Danger Zone: Delete Button
                VStack(alignment: .leading, spacing: 14) {
                    Button(role: .destructive, action: {
                        model.deleteSelectedClient()
                    }) {
                        Label("Delete Client", systemImage: "trash.fill")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.runeyDestructive, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .runeyCard()
            }
            .padding(24)
        }
        .background(Color.runeyBackground)
        .navigationTitle(client.name)
    }

    private func runeyField(_ label: String, text: Binding<String>, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.runeyMuted)
            if isMultiline {
                TextField("", text: text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.runeyBorder, lineWidth: 1)
                    }
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


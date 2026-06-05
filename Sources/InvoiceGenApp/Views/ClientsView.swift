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
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    model.addClient()
                }) {
                    Label("New Client", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
    @State private var isConfirmingDelete = false

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
                    
                    RuneyMultilineEditor(text: $client.notes, minHeight: 120)
                }
                .runeyCard()
                
                // Danger Zone: Delete Button
                VStack(alignment: .leading, spacing: 14) {
                    Button(role: .destructive, action: {
                        isConfirmingDelete = true
                    }) {
                        Label("Delete Client", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RuneyButtonStyle(variant: .destructive))
                }
                .runeyCard()
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(client.name)
        .alert("Delete client?", isPresented: $isConfirmingDelete) {
            Button("Delete Client", role: .destructive) {
                model.deleteSelectedClient()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the client from the local store and unassigns it from related invoices and projects.")
        }
    }

    private func runeyField(_ label: String, text: Binding<String>, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: label)
            if isMultiline {
                RuneyMultilineEditor(text: text)
            } else {
                TextField("", text: text)
                    .runeyFieldInput()
            }
        }
    }
}

import SwiftUI
import InvoiceCore

struct ProjectsView: View {
    @EnvironmentObject private var model: AppModel

    private var filteredProjects: [Project] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.book.projects
            .filter { project in
                guard !query.isEmpty else { return true }
                return project.name.localizedCaseInsensitiveContains(query)
                    || project.summary.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedProjectID) {
                ForEach(filteredProjects) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.runeyPrimary)
                        Text(model.book.clients.first(where: { $0.id == project.clientId })?.name ?? "No client")
                            .font(.caption)
                            .foregroundStyle(Color.runeyMuted)
                    }
                    .padding(.vertical, 4)
                    .tag(project.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    model.addProject()
                }) {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RuneyButtonStyle(variant: .prominent))
                .padding()
            }
        } detail: {
            if let id = model.selectedProjectID,
               let binding = model.projectBinding(id: id) {
                ProjectEditorView(project: binding)
            } else {
                EmptyStateView(title: "Select a project", subtitle: "Projects group invoiceable work by client.", systemImage: "folder.fill")
            }
        }
        .navigationTitle("Projects")
        .onAppear {
            if model.selectedProjectID == nil {
                model.selectedProjectID = filteredProjects.first?.id
            }
        }
    }
}

struct ProjectEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var project: Project
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Project Details")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            runeyField("Project Name", text: $project.name)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                RuneyFormLabel(title: "Client Assignment")
                                Picker("", selection: clientBinding) {
                                    Text("No Client").tag(UUID?.none)
                                    ForEach(model.book.clients) { client in
                                        Text(client.name).tag(Optional(client.id))
                                    }
                                }
                                .frame(height: 30)
                            }
                        }
                        
                        GridRow {
                            runeyField("Hourly Billing Rate", text: $project.hourlyRateMinorUnits.moneyString(currencyCode: project.currencyCode))
                            
                            runeyField("Project Summary", text: $project.summary, isMultiline: true)
                        }
                    }
                }
                .runeyCard()
                
                // Danger Zone: Delete Button
                VStack(alignment: .leading, spacing: 14) {
                    Button(role: .destructive, action: {
                        isConfirmingDelete = true
                    }) {
                        Label("Delete Project", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RuneyButtonStyle(variant: .destructive))
                }
                .runeyCard()
            }
            .padding(24)
        }
        .background(Color.runeyBackground)
        .navigationTitle(project.name)
        .alert("Delete project?", isPresented: $isConfirmingDelete) {
            Button("Delete Project", role: .destructive) {
                model.deleteSelectedProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the project from the local store and unassigns it from related invoices.")
        }
    }

    private var clientBinding: Binding<UUID?> {
        Binding(
            get: { project.clientId },
            set: { project.clientId = $0 }
        )
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

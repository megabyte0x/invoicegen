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
                                Text("Client Assignment")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.runeyMuted)
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
                        model.deleteSelectedProject()
                    }) {
                        Label("Delete Project", systemImage: "trash.fill")
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
        .navigationTitle(project.name)
    }

    private var clientBinding: Binding<UUID?> {
        Binding(
            get: { project.clientId },
            set: { project.clientId = $0 }
        )
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


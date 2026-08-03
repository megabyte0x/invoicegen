import SwiftUI
import InvoiceCore

struct ProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPresentingDetail = false

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
        AdaptiveMasterDetailView(
            hasDetail: isPresentingDetail,
            back: { isPresentingDetail = false }
        ) {
            List(selection: projectSelection) {
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
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                Button {
                    isPresentingDetail = true
                    model.requestNavigation(to: .newProject)
                } label: {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        } detail: {
            if model.projectDraft != nil {
                ProjectEditorView()
            } else {
                EmptyStateView(
                    title: "Select a project",
                    subtitle: "Projects group invoiceable work by client.",
                    systemImage: "folder.fill"
                )
            }
        }
        .navigationTitle("Projects")
        .onAppear {
            if model.selectedProjectID != nil || model.projectDraft != nil {
                isPresentingDetail = true
            }
            activateSelectedProjectIfNeeded()
        }
        .onChange(of: model.selectedProjectID) { _, id in
            if id != nil {
                isPresentingDetail = true
                activateSelectedProjectIfNeeded()
            } else if model.projectDraft == nil {
                isPresentingDetail = false
            }
        }
        .onChange(of: model.projectDraft?.value.id) { _, id in
            if id != nil {
                isPresentingDetail = true
            } else if model.selectedProjectID == nil {
                isPresentingDetail = false
            }
        }
    }

    private var projectSelection: Binding<UUID?> {
        Binding(
            get: { isPresentingDetail ? model.selectedProjectID : nil },
            set: { id in
                guard let id else { return }
                isPresentingDetail = true
                guard model.projectDraft?.value.id != id else { return }
                model.requestNavigation(to: .project(id))
            }
        )
    }

    private func activateSelectedProjectIfNeeded() {
        if model.projectDraft != nil {
            model.activeDraftRoute = .project
        }
        let id = model.selectedProjectID ?? filteredProjects.first?.id
        guard let id else { return }
        guard model.projectDraft?.value.id != id else { return }
        guard model.projectDraft?.isDirty != true else { return }
        model.beginEditingProject(id: id)
    }
}

struct ProjectEditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isConfirmingDelete = false
    @State private var touchedFields: Set<EditorField> = []
    @State private var numericInputResetGeneration = 0
    @State private var commandTargetID = UUID()
    @FocusState private var focusedField: EditorField?

    var body: some View {
        Group {
            if let session = model.projectDraft {
                editor(session: session)
            } else {
                EmptyStateView(
                    title: "Select a project",
                    subtitle: "Projects group invoiceable work by client.",
                    systemImage: "folder.fill"
                )
            }
        }
        .focusedSceneValue(
            \.draftCommandTarget,
            DraftCommandTarget(
                id: commandTargetID,
                kind: .project,
                save: saveProject,
                cancel: cancelProject
            )
        )
        .onChange(of: focusedField) { oldValue, _ in
            if let oldValue {
                touchedFields.insert(oldValue)
            }
        }
        .onChange(of: model.focusedEditorField) { _, field in
            guard field == .projectName || field == .projectHourlyRate else { return }
            focusedField = field
        }
        .alert("Delete project?", isPresented: $isConfirmingDelete) {
            Button("Delete Project", role: .destructive) {
                model.deleteSelectedProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the project from the local store and unassigns it from related invoices.")
        }
    }

    private func editor(session: DraftSession<Project>) -> some View {
        let project = draftProjectBinding(fallback: session.value)

        return GeometryReader { geometry in
            let padding = WorkspaceContentMetrics.padding(for: geometry.size.width)
            let contentWidth = WorkspaceContentMetrics.contentWidth(for: geometry.size.width)
            let fieldRowWidth = max(0, contentWidth - (padding * 2) - 32)

            ScrollView {
                VStack(spacing: 24) {
                    EditorActionBar(
                        title: "Project editor actions",
                        isDirty: session.isDirty || !hourlyRateDraftIsValid,
                        save: saveProject,
                        cancel: cancelProject
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Project Details")
                            .font(.headline)
                            .foregroundStyle(Color.runeyPrimary)

                        VStack(alignment: .leading, spacing: 14) {
                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                projectNameField(project: project)
                                clientAssignmentField(project: project)
                            }

                            AdaptiveFieldRow(availableWidth: fieldRowWidth) {
                                hourlyRateField(project: project)
                                runeyField("Project Summary", text: project.summary, isMultiline: true)
                            }
                        }
                    }
                    .runeyCard()

                    if session.origin == .persisted {
                        VStack(alignment: .leading, spacing: 14) {
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Label("Delete Project", systemImage: "trash.fill")
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
        .navigationTitle(project.wrappedValue.name)
    }

    private func projectNameField(project: Binding<Project>) -> some View {
        runeyField(
            "Project Name",
            text: project.name,
            field: .projectName,
            issue: issueMessage(for: .projectName, project: project.wrappedValue)
        )
    }

    private func clientAssignmentField(project: Binding<Project>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Client Assignment")
            Picker("", selection: project.clientId) {
                Text("No Client").tag(UUID?.none)
                ForEach(model.book.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }
            .accessibilityLabel("Client assignment")
            .frame(height: 30)
        }
    }

    private func hourlyRateField(project: Binding<Project>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RuneyFormLabel(title: "Hourly Billing Rate")
            RuneyMoneyTextField(
                minorUnits: project.hourlyRateMinorUnits,
                accessibilityLabel: "Hourly billing rate",
                validRange: 0...InvoiceAmountPolicy.maximumMoneyMinorUnits,
                outOfRangeMessage: "Hourly rate must be between 0.00 and 1,000,000,000.00.",
                resetID: NumericEditorResetID(
                    entityID: project.wrappedValue.id,
                    generation: numericInputResetGeneration
                ),
                onValidityChanged: {
                    model.updateTransientEditorInputValidity(
                        field: .projectHourlyRate,
                        isValid: $0,
                        invalidMessage: "Enter a valid hourly billing rate."
                    )
                },
                onCommitDraft: { touchedFields.insert(.projectHourlyRate) }
            )
            .focused($focusedField, equals: .projectHourlyRate)

            if let issue = issueMessage(
                for: .projectHourlyRate,
                project: project.wrappedValue
            ) {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
    }

    private func draftProjectBinding(fallback: Project) -> Binding<Project> {
        Binding(
            get: { model.projectDraft?.value ?? fallback },
            set: { value in
                guard var session = model.projectDraft else { return }
                session.value = value
                model.projectDraft = session
            }
        )
    }

    private func saveProject() {
        guard let project = model.projectDraft?.value else { return }
        var issues = EditorValidator.projectIssues(for: project)
        if !hourlyRateDraftIsValid,
           !issues.contains(where: { $0.field == .projectHourlyRate }) {
            issues.append(EditorIssue(
                field: .projectHourlyRate,
                message: "Enter a valid hourly billing rate."
            ))
        }
        touchedFields.formUnion(issues.map(\.field))

        guard issues.isEmpty else {
            model.presentEditorIssues(issues)
            focusedField = issues.first?.field
            return
        }

        do {
            try model.commitProjectDraft()
            model.clearEditorIssues()
            touchedFields.removeAll()
            numericInputResetGeneration &+= 1
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
            focusedField = error.issues.first?.field
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func cancelProject() {
        let baselineID = model.projectDraft?.origin == .persisted
            ? model.projectDraft?.baseline.id
            : nil

        model.cancelProjectDraft()
        model.clearEditorIssues()
        touchedFields.removeAll()
        numericInputResetGeneration += 1

        if let baselineID {
            model.beginEditingProject(id: baselineID)
        }
    }

    private func issueMessage(for field: EditorField, project: Project) -> String? {
        let wasSubmitted = model.editorIssues.contains(where: { $0.field == field })
        guard touchedFields.contains(field) || wasSubmitted else {
            return nil
        }
        if let issue = EditorValidator.projectIssues(for: project).first(where: { $0.field == field }) {
            return issue.message
        }
        if field == .projectHourlyRate, wasSubmitted, !hourlyRateDraftIsValid {
            return "Enter a valid hourly billing rate."
        }
        return nil
    }

    private var hourlyRateDraftIsValid: Bool {
        model.transientEditorInputIssue(for: .projectHourlyRate) == nil
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

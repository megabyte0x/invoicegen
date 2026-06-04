import SwiftUI
import InvoiceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    InvoiceGenLogoMark(size: 34)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local Invoice")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.runeyPrimary)
                        Text("Workspace")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.runeyMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                List {
                    Section {
                        ForEach(AppSection.allCases) { section in
                            HStack(spacing: 10) {
                                Image(systemName: section.systemImage)
                                    .font(.body)
                                    .foregroundStyle(model.selectedSection == section ? Color.runeyAccent : Color.runeyMuted)
                                    .frame(width: 22, height: 22)
                                
                                Text(section.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.runeyPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectionBackground(for: section))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectedSection = section
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Workspace")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.runeyMuted)
                            .padding(.leading, 8)
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            detail
                .background(Color.runeyBackground.ignoresSafeArea())
                .searchable(text: $model.searchText, placement: .toolbar)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            model.addInvoice()
                        } label: {
                            Label("New Invoice", systemImage: "plus")
                        }
                        .buttonStyle(RuneyButtonStyle(variant: .prominent))
                        .help("New Invoice")

                        Button {
                            model.save()
                        } label: {
                            Label("Save", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(RuneyButtonStyle())
                        .help("Save")
                    }
                }
        }
        .alert("Local Invoice", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func selectionBackground(for section: AppSection) -> some View {
        if model.selectedSection == section {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.runeyAccent.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.runeyAccent.opacity(0.25), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection {
        case .dashboard:
            DashboardView()
        case .invoices:
            InvoicesView()
        case .clients:
            ClientsView()
        case .projects:
            ProjectsView()
        case .settings:
            SettingsView()
        }
    }
}

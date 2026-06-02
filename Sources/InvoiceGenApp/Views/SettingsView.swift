import SwiftUI
import InvoiceCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Business Profile
                VStack(alignment: .leading, spacing: 16) {
                    Text("Business Profile")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                        GridRow {
                            runeyField("Business Name", text: $model.book.businessProfile.name)
                            runeyField("Billing Email Address", text: $model.book.businessProfile.email)
                        }
                        
                        GridRow {
                            runeyField("Tax Identifier (e.g. VAT / EIN)", text: $model.book.businessProfile.taxIdentifier)
                            runeyField("Currency Code (e.g. USD / EUR)", text: $model.book.businessProfile.currencyCode)
                        }
                        
                        GridRow {
                            runeyField("Business Address", text: $model.book.businessProfile.address, isMultiline: true)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Payment Terms (Due Date Offset)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.runeyMuted)
                                
                                Stepper("Net \(model.book.businessProfile.paymentTermsDays) Days", value: $model.book.businessProfile.paymentTermsDays, in: 0...120)
                                    .frame(height: 30)
                            }
                        }
                    }
                }
                .runeyCard()
                
                // Section 2: Local Database Store
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local Data Storage")
                        .font(.headline)
                        .foregroundStyle(Color.runeyPrimary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Store Path")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.runeyMuted)
                        
                        Text(model.store.url.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.runeyPrimary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
                            }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            model.reload()
                        }) {
                            Label("Reload From Disk", systemImage: "arrow.clockwise")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.runeyPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.runeyBorder, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            model.seedSampleData()
                        }) {
                            Label("Seed Sample Data", systemImage: "doc.text.fill.badge.plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.runeyInfo, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .runeyCard()
            }
            .padding(24)
        }
        .background(Color.runeyBackground)
        .onChange(of: model.book.businessProfile) { _, _ in
            model.save()
        }
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


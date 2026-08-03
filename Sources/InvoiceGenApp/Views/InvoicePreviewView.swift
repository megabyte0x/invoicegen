import AppKit
import InvoiceCore
import SwiftUI
import UniformTypeIdentifiers

struct InvoicePreviewView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var invoice: Invoice
    var book: InvoiceBook
    var isPaused = false
    @State private var isConfirmingMarkSent = false
    @State private var isChoosingMailMethod = false
    @State private var mailNotice: String?
    @State private var scaleMode: PreviewScaleMode = .fitWidth

    private var document: InvoiceDocument {
        InvoiceDocumentPaginator.paginate(invoice: invoice, book: book)
    }

    var body: some View {
        VStack(spacing: 0) {
            previewHeader

            Divider()

            if isPaused {
                pausedPreview
            } else {
                InvoicePreviewCanvas(document: document, scaleMode: $scaleMode)
            }
        }
        .background(Color.runeyPreviewBackground)
        .sheet(isPresented: $isChoosingMailMethod) {
            MailInvoiceMethodSheet {
                isChoosingMailMethod = false
                runAfterMailMethodSheetDismisses {
                    mailInvoiceWithMailApp()
                }
            } useBrowser: {
                isChoosingMailMethod = false
                runAfterMailMethodSheetDismisses {
                    mailInvoiceWithBrowser()
                }
            } cancel: {
                isChoosingMailMethod = false
            }
        }
        .alert("Mark invoice as sent?", isPresented: $isConfirmingMarkSent) {
            Button("Mark as Sent") {
                invoice.status = .sent
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("The email compose window has been opened. Mark this invoice as sent only if you intend to send it.")
        }
    }

    private var previewHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                mailNoticeLabel

                Spacer(minLength: 8)

                previewActions
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 10) {
                mailNoticeLabel

                HStack(alignment: .top, spacing: 8) {
                    mailButton
                        .frame(maxWidth: .infinity)

                    exportButton
                        .frame(maxWidth: .infinity)
                }

                scalePicker
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var mailNoticeLabel: some View {
        if let mailNotice {
            Label(mailNotice, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.runeyMuted)
                .lineLimit(2)
        }
    }

    private var previewActions: some View {
        HStack(spacing: 8) {
            mailButton
            exportButton
            scalePicker
                .frame(width: 210)
        }
    }

    private var mailButton: some View {
        Button {
            isChoosingMailMethod = true
        } label: {
            Label("Mail Invoice", systemImage: "envelope")
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .disabled(isPaused)
        .help(isPaused ? "Fix invalid line-item values before mailing this invoice." : "")
    }

    private var exportButton: some View {
        Button(action: exportInvoicePDF) {
            Label("Export PDF...", systemImage: "square.and.arrow.down")
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .disabled(isPaused)
        .help(isPaused ? "Fix invalid line-item values before exporting this invoice." : "")
    }

    private var scalePicker: some View {
        Picker("Preview scale", selection: $scaleMode) {
            ForEach(PreviewScaleMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var pausedPreview: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.runeyDestructive)
            Text("Fix invalid line-item values to update this preview.")
                .font(.headline)
                .foregroundStyle(Color.runeyPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.runeyPreviewBackground)
    }

    private func exportInvoicePDF() {
        let exportDocument = document
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = InvoiceExportNaming.pdfFileName(for: invoice)
        panel.directoryURL = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let destinationURL = panel.url else { return }
            do {
                try InvoiceDocumentRenderer.writePDF(
                    document: exportDocument,
                    to: destinationURL
                )
            } catch {
                model.errorMessage = "Could not export invoice: \(error.localizedDescription)"
            }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            panel.begin(completionHandler: handleResponse)
        }
    }

    private func mailInvoiceWithMailApp() {
        let draft = InvoiceMailDraft(invoice: invoice, book: book)
        var attachmentURL: URL?

        do {
            attachmentURL = try writeTemporaryInvoicePDF()
            guard let attachmentURL else { return }
            try InvoiceMailAppleScript.compose(draft: draft, attachmentURL: attachmentURL)
            scheduleTemporaryAttachmentCleanup(for: attachmentURL)

            mailNotice = draft.isMissingRecipient ? "No client email. Mail opened without a recipient." : nil
            isConfirmingMarkSent = true
        } catch {
            if let attachmentURL {
                removeTemporaryAttachment(at: attachmentURL)
            }
            model.errorMessage = "Could not prepare invoice email: \(error.localizedDescription)"
        }
    }

    private func mailInvoiceWithBrowser() {
        let draft = InvoiceMailDraft(invoice: invoice, book: book)
        var attachmentURL: URL?

        do {
            attachmentURL = try writeTemporaryInvoicePDF()
            guard let attachmentURL else { return }

            guard let mailtoURL = InvoiceMailtoURL.url(for: draft) else {
                throw NSError(
                    domain: "InvoiceGen.Mailto",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not open the browser email composer."
                    ]
                )
            }

            guard NSWorkspace.shared.selectFile(
                attachmentURL.path,
                inFileViewerRootedAtPath: attachmentURL.deletingLastPathComponent().path
            ) else {
                throw NSError(
                    domain: "InvoiceGen.Mailto",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not reveal the temporary invoice PDF."
                    ]
                )
            }

            guard NSWorkspace.shared.open(mailtoURL) else {
                throw NSError(
                    domain: "InvoiceGen.Mailto",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not open the browser email composer."
                    ]
                )
            }

            scheduleTemporaryAttachmentCleanup(for: attachmentURL, delay: Self.browserMailCleanupDelay)
            mailNotice = browserMailNotice(isMissingRecipient: draft.isMissingRecipient)
            isConfirmingMarkSent = true
        } catch {
            if let attachmentURL {
                removeTemporaryAttachment(at: attachmentURL)
            }
            model.errorMessage = "Could not prepare browser email: \(error.localizedDescription)"
        }
    }

    private func writeTemporaryInvoicePDF() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoiceGen-Mail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        do {
            let fileURL = directoryURL.appendingPathComponent(InvoiceExportNaming.pdfFileName(for: invoice))
            try InvoiceDocumentRenderer.pdfData(document: document)
                .write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }
    }

    private func scheduleTemporaryAttachmentCleanup(
        for attachmentURL: URL,
        delay: TimeInterval = Self.successfulShareCleanupDelay
    ) {
        let directoryURL = attachmentURL.deletingLastPathComponent()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Self.removeTemporaryDirectory(at: directoryURL)
        }
    }

    private func removeTemporaryAttachment(at attachmentURL: URL) {
        Self.removeTemporaryDirectory(at: attachmentURL.deletingLastPathComponent())
    }

    private static func removeTemporaryDirectory(at directoryURL: URL) {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private func browserMailNotice(isMissingRecipient: Bool) -> String {
        if isMissingRecipient {
            return "Browser email opened without a recipient. Attach the revealed PDF manually."
        }

        return "Browser email opened. Attach the revealed PDF manually."
    }

    private func runAfterMailMethodSheetDismisses(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: action)
    }

    private static let successfulShareCleanupDelay: TimeInterval = 600
    private static let browserMailCleanupDelay: TimeInterval = 3600
}

private struct MailInvoiceMethodSheet: View {
    var useMailApp: () -> Void
    var useBrowser: () -> Void
    var cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.title2)
                    .foregroundStyle(Color.runeyAccent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mail Invoice")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.runeyPrimary)
                    Text("Choose where to compose this invoice email.")
                        .font(.subheadline)
                        .foregroundStyle(Color.runeyMuted)
                }
            }

            VStack(spacing: 10) {
                Button(action: useMailApp) {
                    MailInvoiceMethodRow(
                        icon: "envelope.fill",
                        title: "Mail App",
                        subtitle: "Opens Apple Mail with the PDF attached."
                    )
                }
                .buttonStyle(.plain)

                Button(action: useBrowser) {
                    MailInvoiceMethodRow(
                        icon: "safari.fill",
                        title: "Browser or Default Email",
                        subtitle: "Opens a mailto draft and reveals the PDF."
                    )
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
            }
        }
        .padding(22)
        .frame(width: 430)
    }
}

private struct MailInvoiceMethodRow: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.runeyAccent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.runeyPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.runeyMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.runeyMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.runeySecondary)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.runeyBorder.opacity(0.8), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

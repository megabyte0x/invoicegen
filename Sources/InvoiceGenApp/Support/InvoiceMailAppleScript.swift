import Foundation

enum InvoiceMailAppleScript {
    static func compose(draft: InvoiceMailDraft, attachmentURL: URL) throws {
        guard let script = NSAppleScript(source: source(draft: draft, attachmentURL: attachmentURL)) else {
            throw NSError(
                domain: "InvoiceGen.MailAppleScript",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Mail could not compile the invoice email script."
                ]
            )
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            throw NSError(
                domain: "InvoiceGen.MailAppleScript",
                code: errorInfo[NSAppleScript.errorNumber] as? Int ?? -1,
                userInfo: [
                    NSLocalizedDescriptionKey: errorInfo[NSAppleScript.errorMessage] as? String
                        ?? "Mail could not create the invoice email."
                ]
            )
        }
    }

    static func source(draft: InvoiceMailDraft, attachmentURL: URL) -> String {
        let recipientLines = draft.recipients.map {
            "        make new to recipient at end of to recipients with properties {address:\(stringLiteral($0))}"
        }
        .joined(separator: "\n")

        let recipientBlock = recipientLines.isEmpty ? "" : "\n\(recipientLines)"

        return """
        set attachmentFile to POSIX file \(stringLiteral(attachmentURL.path))
        using terms from application \(stringLiteral(mailApplicationPath))
            tell application \(stringLiteral(mailApplicationPath))
                activate
                set newMessage to make new outgoing message with properties {subject:\(stringLiteral(draft.subject)), content:\(multilineStringExpression(draft.body)), visible:true}
                tell newMessage\(recipientBlock)
                    make new attachment with properties {file name:attachmentFile} at after the last paragraph
                end tell
            end tell
        end using terms from
        """
    }

    private static let mailApplicationPath = "/System/Applications/Mail.app"

    private static func multilineStringExpression(_ value: String) -> String {
        value.components(separatedBy: .newlines)
            .map(stringLiteral)
            .joined(separator: " & return & ")
    }

    private static func stringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

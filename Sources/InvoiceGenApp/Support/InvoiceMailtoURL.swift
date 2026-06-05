import Foundation

enum InvoiceMailtoURL {
    static func url(for draft: InvoiceMailDraft) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.recipients.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        return components.url
    }
}

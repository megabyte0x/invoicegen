import Foundation

public enum InvoiceExportNaming {
    public static func pdfFileName(for invoice: Invoice) -> String {
        "\(pdfFileStem(for: invoice)).pdf"
    }

    public static func pdfFileStem(for invoice: Invoice) -> String {
        let rawValue = invoice.number.trimmingCharacters(in: .whitespacesAndNewlines)
        var fileStem = ""
        var previousWasSeparator = false

        for scalar in rawValue.unicodeScalars {
            if isAllowedFileNameScalar(scalar) {
                fileStem.append(String(scalar))
                previousWasSeparator = false
            } else if !previousWasSeparator {
                fileStem.append("-")
                previousWasSeparator = true
            }
        }

        let trimmed = fileStem.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "invoice" : trimmed
    }

    private static func isAllowedFileNameScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...90, 97...122:
            return true
        default:
            return scalar == "-" || scalar == "_" || scalar == "."
        }
    }
}

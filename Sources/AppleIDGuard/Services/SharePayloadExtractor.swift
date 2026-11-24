import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum SharePayloadExtractor {
    public static func normalizedReceiptText(from text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func plainText(fromHTML html: String) -> String {
        #if canImport(UIKit)
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
           ) {
            return normalizedReceiptText(from: attributed.string)
        }
        #endif

        return normalizedReceiptText(
            from: html.replacingOccurrences(
                of: "<[^>]+>",
                with: " ",
                options: .regularExpression
            )
        )
    }
}

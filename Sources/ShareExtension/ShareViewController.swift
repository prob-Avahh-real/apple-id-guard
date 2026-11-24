import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        statusLabel.text = "正在分析收据…"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await processSharedItems() }
    }

    @MainActor
    private func processSharedItems() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem], !extensionItems.isEmpty else {
            showFailure("未收到分享内容")
            return
        }

        do {
            let text = try await ShareAttachmentLoader.loadReceiptText(from: extensionItems)
            switch ReceiptIngestService.ingest(text: text, source: .mailShare) {
            case .success(let result):
                await NotificationService.notifyRisk(
                    event: result.event,
                    assessment: result.assessment,
                    settings: PurchaseStore.shared.loadSettings()
                )
                showSuccess(result)
            case .failure:
                showFailure("无法解析 Apple 收据，请在 App 内手动导入。")
            }
        } catch {
            showFailure("读取 Mail 内容失败。")
        }
    }

    @MainActor
    private func showSuccess(_ result: IngestResult) {
        statusLabel.text = "已记录 \(result.event.merchant)\n\(result.event.formattedAmount)\n风险 \(result.assessment.score)"
        finish(after: 1.2, success: true)
    }

    @MainActor
    private func showFailure(_ message: String) {
        statusLabel.text = message
        finish(after: 1.5, success: false)
    }

    @MainActor
    private func finish(after delay: TimeInterval, success: Bool) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            _ = success
        }
    }
}

enum ShareAttachmentLoader {
    enum LoaderError: Error {
        case noText
    }

    static func loadReceiptText(from items: [NSExtensionItem]) async throws -> String {
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try await loadString(from: provider, type: UTType.plainText.identifier) {
                        return SharePayloadExtractor.normalizedReceiptText(from: text)
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    if let text = try await loadString(from: provider, type: UTType.text.identifier) {
                        return SharePayloadExtractor.normalizedReceiptText(from: text)
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                    if let html = try await loadString(from: provider, type: UTType.html.identifier) {
                        return SharePayloadExtractor.plainText(fromHTML: html)
                    }
                }
            }

            if let attributed = item.attributedContentText?.string, !attributed.isEmpty {
                return SharePayloadExtractor.normalizedReceiptText(from: attributed)
            }
            if let title = item.attributedTitle?.string, !title.isEmpty {
                return SharePayloadExtractor.normalizedReceiptText(from: title)
            }
        }
        throw LoaderError.noText
    }

    private static func loadString(from provider: NSItemProvider, type: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let text = item as? String {
                    continuation.resume(returning: text)
                    return
                }
                if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                    return
                }
                if let url = item as? URL, let text = try? String(contentsOf: url) {
                    continuation.resume(returning: text)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
}

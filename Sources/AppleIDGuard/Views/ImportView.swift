import SwiftUI

struct ImportView: View {
    @ObservedObject var viewModel: GuardViewModel
    @State private var merchant = ""
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴 Apple 收据邮件") {
                    TextEditor(text: $viewModel.receiptDraft)
                        .frame(minHeight: 180)
                    Button("AI 解析并评估") {
                        viewModel.importReceiptText(viewModel.receiptDraft)
                    }
                    .disabled(viewModel.receiptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("或手动录入") {
                    TextField("应用/商户名", text: $merchant)
                    TextField("金额", text: $amountText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Button("添加记录") {
                        guard let amount = Decimal(string: amountText), !merchant.isEmpty else { return }
                        viewModel.addManualPurchase(merchant: merchant, amount: amount)
                        merchant = ""
                        amountText = ""
                    }
                }

                if let error = viewModel.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section("推荐工作流") {
                    Label("在 Mail 中打开 Apple 收据 → 分享 → 账户盾", systemImage: "envelope")
                    Label("或在此页粘贴邮件正文作为备用", systemImage: "doc.on.clipboard")
                    Label("开启后台刷新以保持巡检", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("导入收据")
        }
    }
}

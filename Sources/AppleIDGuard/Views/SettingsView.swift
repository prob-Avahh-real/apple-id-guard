import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: GuardViewModel
    @State private var draft: GuardSettings

    init(viewModel: GuardViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("消费限额") {
                    Stepper(value: binding(for: \.singlePurchaseLimit, step: 10), in: 6...999) {
                        Text("单笔上限：¥\(NSDecimalNumber(decimal: draft.singlePurchaseLimit).intValue)")
                    }
                    Stepper(value: binding(for: \.dailySpendLimit, step: 20), in: 20...2000) {
                        Text("日限额：¥\(NSDecimalNumber(decimal: draft.dailySpendLimit).intValue)")
                    }
                }

                Section("后台与通知") {
                    Toggle("后台定时巡检", isOn: $draft.backgroundRefreshEnabled)
                    Toggle("中等风险也推送", isOn: $draft.notifyOnCaution)
                    Toggle("AI 增强文本分析", isOn: $draft.aiEnhancedAnalysis)
                }

                Section("深夜敏感时段") {
                    Stepper(value: $draft.nightQuietStart, in: 0...23) {
                        Text("开始：\(draft.nightQuietStart):00")
                    }
                    Stepper(value: $draft.nightQuietEnd, in: 0...23) {
                        Text("结束：\(draft.nightQuietEnd):00")
                    }
                }

                Section("账户安全") {
                    Link("Apple ID 购买记录", destination: URL(string: "https://reportaproblem.apple.com")!)
                    Link("更改 Apple ID 密码", destination: URL(string: "https://appleid.apple.com")!)
                    Link("联系 Apple 支持", destination: URL(string: "https://support.apple.com/zh-cn/billing")!)
                }

                Section {
                    Button("保存设置") {
                        viewModel.updateSettings(draft)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("设置")
            .onChange(of: viewModel.settings) { _, newValue in
                draft = newValue
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<GuardSettings, Decimal>, step: Decimal) -> Binding<Decimal> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }
}

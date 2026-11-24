import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: GuardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    shieldCard
                    statsRow
                    recentSection
                }
                .padding()
            }
            .navigationTitle("账户盾")
            .refreshable {
                await viewModel.performBackgroundScan()
                viewModel.reload()
            }
        }
    }

    private var shieldCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: viewModel.snapshot.shieldActive ? "shield.checkered" : "shield.slash")
                    .font(.largeTitle)
                    .foregroundStyle(viewModel.snapshot.shieldActive ? .green : .orange)
                VStack(alignment: .leading) {
                    Text("后台防护已开启")
                        .font(.headline)
                    Text("AI 风险引擎 + 定时巡检")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let lastScan = viewModel.snapshot.lastScanAt {
                Text("上次巡检：\(lastScan.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("下拉刷新可立即巡检")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(title: "今日消费", value: formatAmount(viewModel.snapshot.todaySpend), tint: .blue)
            statTile(title: "待处理", value: "\(viewModel.snapshot.pendingAlerts)", tint: .orange)
            statTile(title: "总记录", value: "\(viewModel.events.count)", tint: .purple)
        }
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近购买")
                .font(.headline)

            if viewModel.events.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "tray",
                    description: Text("在「导入」页粘贴 Apple 收据邮件即可开始监控。")
                )
            } else {
                ForEach(viewModel.events.prefix(5)) { event in
                    PurchaseRow(event: event, assessment: viewModel.assessment(for: event))
                }
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "¥\(amount)"
    }
}

struct PurchaseRow: View {
    let event: PurchaseEvent
    let assessment: RiskAssessment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.merchant)
                    .font(.subheadline.bold())
                Text("\(event.formattedAmount) · \(event.source.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            riskBadge
        }
        .padding(.vertical, 8)
    }

    private var riskBadge: some View {
        Text(assessment.level.label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color(for: assessment.level).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: assessment.level))
    }

    private func color(for level: RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .critical: return .red
        }
    }
}

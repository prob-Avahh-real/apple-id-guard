import SwiftUI

struct AlertsView: View {
    @ObservedObject var viewModel: GuardViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.flaggedEvents.isEmpty {
                    ContentUnavailableView(
                        "暂无告警",
                        systemImage: "checkmark.shield",
                        description: Text("可疑购买会在这里等你确认。")
                    )
                } else {
                    List(viewModel.flaggedEvents) { event in
                        AlertDetailRow(
                            event: event,
                            assessment: viewModel.assessment(for: event),
                            onConfirm: { viewModel.confirmLegitimate(event) },
                            onFraud: { viewModel.reportFraud(event) }
                        )
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("风险告警")
        }
    }
}

struct AlertDetailRow: View {
    let event: PurchaseEvent
    let assessment: RiskAssessment
    let onConfirm: () -> Void
    let onFraud: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.merchant)
                    .font(.headline)
                Spacer()
                Text("风险 \(assessment.score)")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            Text(event.formattedAmount)
                .font(.subheadline)

            ForEach(assessment.signals.prefix(3)) { signal in
                Label(signal.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("是我本人", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("不是我", role: .destructive, action: onFraud)
                    .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }
}

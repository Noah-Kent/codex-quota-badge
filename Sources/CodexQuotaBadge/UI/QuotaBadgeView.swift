import SwiftUI
import CodexQuotaBadgeCore

struct QuotaBadgeView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        Group {
            switch store.availability {
            case .fresh(let snapshot): rows(snapshot.windows, opacity: 1)
            case .stale(let snapshot, _): rows(snapshot.windows, opacity: 0.55)
            case .unavailable(let reason): Text("—  \(reason)").foregroundStyle(.secondary).padding(10)
            }
        }
        .padding(8)
        .frame(minWidth: 250)
    }

    @ViewBuilder private func rows(_ windows: [QuotaWindow], opacity: Double) -> some View {
        VStack(spacing: 0) {
            ForEach(windows) { window in
                HStack {
                    Text(window.periodLabel).frame(width: 34, alignment: .leading).foregroundStyle(.secondary)
                    Text("\(window.remainingPercent)%").frame(width: 48, alignment: .leading).foregroundStyle(color(for: window)).monospacedDigit()
                    Spacer()
                    Text("↻ \(countdown(for: window))").monospacedDigit().foregroundStyle(.primary)
                }
                .padding(.vertical, 5)
            }
        }.opacity(opacity)
    }

    private func countdown(for window: QuotaWindow) -> String {
        let seconds = max(0, Int(window.resetsAt.timeIntervalSince(store.now)))
        if seconds >= 86_400 { return "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h" }
        return String(format: "%d:%02d", seconds / 3_600, (seconds % 3_600) / 60)
    }

    private func color(for window: QuotaWindow) -> Color {
        switch window.severity { case .normal: .green; case .warning: .orange; case .critical: .red }
    }
}

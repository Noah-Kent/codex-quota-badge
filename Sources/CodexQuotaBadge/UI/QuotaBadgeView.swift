import SwiftUI
import AppKit
import CodexQuotaBadgeCore

struct QuotaBadgeView: View {
    @ObservedObject var store: QuotaStore
    let onHide: () -> Void
    let onQuit: () -> Void

    var body: some View {
        Group {
            switch store.availability {
            case .fresh(let snapshot): detail(snapshot, isStale: false)
            case .stale(let snapshot, _): detail(snapshot, isStale: true)
            case .unavailable(let reason): Text(reason).foregroundStyle(.secondary).padding(12)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    @ViewBuilder private func detail(_ snapshot: QuotaSnapshot, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(snapshot.windows.sorted { $0.duration < $1.duration }) { window in
                HStack(alignment: .firstTextBaseline) {
                    Text(window.periodLabel).frame(width: 30, alignment: .leading).foregroundStyle(.secondary)
                    Text("\(window.remainingPercent)%").foregroundStyle(color(for: window)).monospacedDigit()
                    Spacer()
                    Text("重置 \(resetTime(for: window))").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Divider()
            HStack {
                Text(isStale ? "最后更新（可能过期）" : "最后更新")
                Spacer()
                Text(LastUpdatedFormatter.text(snapshot.updatedAt)).monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Button(store.isRefreshing ? "正在刷新…" : "立即刷新") { store.refresh() }
                    .disabled(store.isRefreshing)
                Spacer()
                Button("隐藏详情", action: onHide)
                Spacer()
                Button("完全退出", action: onQuit)
            }
            .font(.caption)
        }
    }

    private func resetTime(for window: QuotaWindow) -> String {
        window.resetsAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func color(for window: QuotaWindow) -> Color {
        switch window.severity { case .normal: .green; case .warning: .orange; case .critical: .red }
    }
}

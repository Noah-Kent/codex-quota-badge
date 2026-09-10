import SwiftUI
import AppKit
import CodexQuotaBadgeCore

struct QuotaBadgeView: View {
    @ObservedObject var store: QuotaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousSnapshotUpdate: Date?
    @State private var updateIsHighlighted = false
    @State private var highlightGeneration = 0
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
                    QuotaProgressBar(fraction: window.remainingFraction, tint: color(for: window))
                        .frame(minWidth: 70, maxWidth: .infinity)
                        .accessibilityLabel("\(window.periodLabel) 剩余 \(window.remainingPercent)%")
                    Text("重置 \(resetTime(for: window))").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Divider()
            HStack {
                Text(isStale ? "最后更新（可能过期）" : "最后更新")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(LastUpdatedFormatter.text(snapshot.updatedAt))
                    .monospacedDigit()
                    .foregroundStyle(updateIsHighlighted ? Color.green : Color.secondary)
                    .scaleEffect(updateIsHighlighted && !reduceMotion ? 1.06 : 1)
                    .onAppear {
                        previousSnapshotUpdate = snapshot.updatedAt
                    }
                    .onChange(of: snapshot.updatedAt) { newUpdate in
                        highlightIfNeeded(for: newUpdate)
                    }
            }
            .font(.caption)
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
        ResetTimeFormatter.text(window.resetsAt)
    }

    private func highlightIfNeeded(for newUpdate: Date) {
        let shouldHighlight = UpdateHighlightDecision.shouldHighlight(
            previous: previousSnapshotUpdate,
            current: newUpdate
        )
        previousSnapshotUpdate = newUpdate
        guard shouldHighlight else { return }

        highlightGeneration += 1
        let generation = highlightGeneration
        withAnimation(.easeOut(duration: 0.15)) {
            updateIsHighlighted = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard generation == highlightGeneration else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                updateIsHighlighted = false
            }
        }
    }

    private func color(for window: QuotaWindow) -> Color {
        switch window.severity { case .normal: .green; case .warning: .orange; case .critical: .red }
    }
}

private struct QuotaProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.22))
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

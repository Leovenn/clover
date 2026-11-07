import CloverCore
import SwiftUI

/// One account: who is logged in, then each quota window as a large percentage over a bar.
struct AccountRow: View {
    let row: AppModel.Row
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            details
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contextMenu { actionItems }
    }

    private var title: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            Text(row.account.id).font(.title3.weight(.semibold))
            if case .loggedOut = row.status {
                Text("未登录 · 运行 cl run \(row.account.id) 后 /login").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let plan = row.config.identity?.plan {
                Text(plan).font(.caption).foregroundStyle(.secondary)
            }
            actions
        }
    }

    @ViewBuilder private var details: some View {
        switch row.status {
        case .loggedOut:
            EmptyView()
        case .apiBilling:
            Text("API 计费").font(.caption).foregroundStyle(.secondary)
        case .ok, .failed:
            if let email = row.config.identity?.email {
                Text(email).font(.caption).foregroundStyle(.secondary)
            }
            if let quota = row.config.quota {
                VStack(spacing: 8) {
                    QuotaWindow(title: "5 小时", window: quota.fiveHour, resetStyle: .countdown)
                    QuotaWindow(title: "本周", window: quota.sevenDay, resetStyle: .weekday)
                }
                .padding(.top, 6)
                .opacity(isFailed ? 0.45 : 1)
            }
            if case .failed(let message) = row.status {
                Text(failureText(message)).font(.caption).foregroundStyle(.red).lineLimit(2).padding(.top, 2)
            }
        }
    }

    private var isFailed: Bool { if case .failed = row.status { true } else { false } }

    private func failureText(_ message: String) -> String {
        guard let fetchedAt = row.config.quota?.fetchedAt else { return "刷新失败：\(message)" }
        return "刷新失败：\(message) · 显示的是\(Elapsed.text(since: fetchedAt))的读数"
    }

    private var dotColor: Color {
        switch row.status {
        case .ok, .apiBilling: .green
        case .loggedOut: .gray
        case .failed: .red
        }
    }

    private var actions: some View {
        Menu { actionItems } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
    }

    @ViewBuilder private var actionItems: some View {
        Button("在 Finder 中打开") { model.reveal(row.account) }
        if !row.account.isMain {
            Divider()
            Button("删除账号…", role: .destructive) { model.remove(row.account) }
        }
    }
}

/// "5 小时 25%  ……  1小时3分后恢复" over a full-width bar.
private struct QuotaWindow: View {
    enum ResetStyle { case countdown, weekday }

    let title: String
    let window: ClaudeConfig.Window?
    let resetStyle: ResetStyle

    var body: some View {
        // Re-evaluated every minute, so the countdown runs and a window that ends turns empty.
        TimelineView(.everyMinute) { _ in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(title) \(Int(percent.rounded()))%").font(.headline.monospacedDigit())
                    Spacer()
                    Text(resetText).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: min(percent, 100), total: 100).tint(tint)
            }
        }
    }

    /// When the running window resets. A window without a reset time has not started: it
    /// starts with the next message. One whose reset time has passed is over, and the next
    /// has not started as far as this reading knows.
    private var resetsAt: Date? {
        window?.resetsAt.flatMap { $0 > .now ? $0 : nil }
    }

    private var percent: Double {
        resetsAt == nil ? 0 : window?.percent ?? 0
    }

    /// Claude's own orange; red once the window is nearly used up.
    private var tint: Color {
        percent > 85 ? .red : Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    }

    private var resetText: String {
        guard let resetsAt else { return "未开始" }
        switch resetStyle {
        case .countdown:
            let minutes = Int(resetsAt.timeIntervalSinceNow / 60) + 1
            return (minutes >= 60 ? "\(minutes / 60)小时\(minutes % 60)分" : "\(minutes)分") + "后恢复"
        case .weekday:
            return resetsAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()) + " 恢复"
        }
    }
}

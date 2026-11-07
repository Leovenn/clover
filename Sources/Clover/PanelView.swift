import AppKit
import SwiftUI

/// The menu bar panel: when the readings were taken, then one row per account. Beyond four
/// accounts the list stops growing and scrolls.
struct PanelView: View {
    let model: AppModel
    private static let maxVisibleRows = 4, scrollHeight: CGFloat = 560

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if model.claudeMissing {
                notice("未找到 claude：请先在终端运行一次 cl，或确认 Claude Code 已安装")
            }
            if model.rows.isEmpty {
                notice("还没有账号。登录 ~/.claude，或在终端运行 cl add <名称>")
            }
            if model.rows.count > Self.maxVisibleRows {
                ScrollView { list }.frame(height: Self.scrollHeight)
            } else {
                list
            }
        }
        .frame(width: 340)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.rows) { row in
                if row.id != model.rows.first?.id { Divider() }
                AccountRow(row: row, model: model)
            }
        }
    }

    private var header: some View {
        HStack {
            TimelineView(.everyMinute) { _ in
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.refresh(force: true) } label: {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.rotate, options: .repeat(.continuous), isActive: model.isRefreshing)
            }
            .help("刷新额度")
            Menu {
                Button("退出 Clover") { NSApp.terminate(nil) }
            } label: { Image(systemName: "gearshape") }
                .menuIndicator(.hidden)
                .fixedSize()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var status: String {
        if model.isRefreshing { return "正在刷新…" }
        guard let date = model.lastUpdated else { return "尚无额度读数" }
        return "\(Elapsed.text(since: date))更新"
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
    }
}

/// "刚刚", "3 分钟前", "2 小时前", "1 天前".
enum Elapsed {
    static func text(since date: Date) -> String {
        let minutes = max(0, Int(-date.timeIntervalSinceNow / 60))
        switch minutes {
        case 0: return "刚刚"
        case ..<60: return "\(minutes) 分钟前"
        case ..<1440: return "\(minutes / 60) 小时前"
        default: return "\(minutes / 1440) 天前"
        }
    }
}

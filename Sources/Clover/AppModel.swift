import CloverCore
import Foundation
import Observation

/// What the panel shows. Everything is read from disk on each opening; quotas are refreshed
/// through Claude Code when the panel opens, at most once a minute per account.
@MainActor @Observable
final class AppModel {
    enum Status { case ok, loggedOut, apiBilling, failed(String) }

    struct Row: Identifiable {
        let account: Account
        let config: ClaudeConfig
        let status: Status
        var id: String { account.id }
    }

    private(set) var rows: [Row] = []
    /// Closes the panel, which floats above dialogs.
    var closePanel: () -> Void = {}
    private(set) var claudeMissing = false

    var isRefreshing: Bool { !refreshing.isEmpty }
    /// When the newest quota reading was taken.
    var lastUpdated: Date? { rows.compactMap(\.config.quota?.fetchedAt).max() }

    private let store = AccountStore()
    private var claude: URL?
    private var refreshing: Set<String> = []
    private var failures: [String: String] = [:]
    private var lastRun: [String: Date] = [:]
    private static let refreshInterval: TimeInterval = 60

    // MARK: Panel

    /// After `reload`, once the panel is up: quotas that are due refresh in the background.
    func panelOpened() async {
        if claude == nil { claude = ClaudeBinary.find() }
        if claude == nil { claude = await ClaudeBinary.findThroughLoginShell() }
        claudeMissing = claude == nil
        refresh(force: false)
    }

    /// Starts a /usage run for every subscription account that is due, all at once.
    func refresh(force: Bool) {
        guard let claude else { return }
        let due = rows.filter { row in
            row.config.identity != nil && !refreshing.contains(row.id)
                && (force || lastRun[row.id].map { -$0.timeIntervalSinceNow > Self.refreshInterval } ?? true)
        }
        for row in due {
            refreshing.insert(row.id)
            lastRun[row.id] = .now
            Task {
                do {
                    try await UsageProbe.refresh(row.account, claude: claude)
                    failures[row.id] = nil
                } catch {
                    failures[row.id] = error.localizedDescription
                }
                refreshing.remove(row.id)
                reload()
            }
        }
        reload()
    }

    /// Reads every account from disk: cheap, local and synchronous.
    func reload() {
        rows = store.accounts().map { account in
            let config = account.config()
            return Row(account: account, config: config, status: status(of: account, config))
        }
    }

    private func status(of account: Account, _ config: ClaudeConfig) -> Status {
        if !config.isLoggedIn { return .loggedOut }
        if config.identity == nil { return .apiBilling }
        return failures[account.id].map(Status.failed) ?? .ok
    }

    // MARK: Actions

    func reveal(_ account: Account) {
        System.reveal(account.dir)
    }

    func remove(_ account: Account) {
        closePanel()
        do { try store.checkRemovable(account) } catch { return System.alert(error.message) }
        guard System.confirm("删除账号「\(account.id)」？", detail: "将先退出该账号的登录，再把 \(account.dir.path) 移到废纸篓。") else { return }
        Task {
            do { try await store.remove(account, claude: claude) } catch { System.alert(error.localizedDescription) }
            reload()
        }
    }
}

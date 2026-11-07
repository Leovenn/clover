import Foundation

/// The accounts on disk. The directories are the only state: ~/.claude is `main` when it
/// exists, and every directory in ~/.clover-accounts is an account named after it.
public struct AccountStore: Sendable {
    public let mainDir: URL
    public let root: URL

    public init(mainDir: URL = .homeDirectory.appending(path: ".claude"),
                root: URL = .homeDirectory.appending(path: ".clover-accounts")) {
        self.mainDir = mainDir
        self.root = root
    }

    // MARK: Reading

    /// `main` first, then the others by name. The first one is the one `cl` offers first.
    public func accounts() -> [Account] {
        let fm = FileManager.default
        let main = fm.fileExists(atPath: mainDir.path) ? [Account(id: Account.mainID, dir: mainDir)] : []
        let others = ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { accountAt($0.lastPathComponent) }
            .sorted { $0.id < $1.id }
        return main + others
    }

    public func account(_ id: String) throws(CloverError) -> Account {
        guard let account = accounts().first(where: { $0.id == id }) else {
            throw CloverError("没有账号「\(id)」，可用 cl ls 查看")
        }
        return account
    }

    /// Always spelled `root/<id>`, never as listed or resolved: Claude Code names the account's
    /// Keychain item after this exact path, so it must not change between launches.
    private func accountAt(_ id: String) -> Account {
        Account(id: id, dir: root.appending(path: id, directoryHint: .isDirectory))
    }

    // MARK: Changing

    /// Creates the directory of a new account. Claude Code fills it on first launch.
    public func create(_ id: String) throws(CloverError) -> Account {
        try checkNewID(id)
        let account = accountAt(id)
        do {
            try FileManager.default.createDirectory(at: account.dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            throw CloverError("无法创建 \(account.dir.path)：\(error.localizedDescription)")
        }
        return account
    }

    /// Logs the account out through Claude Code, then moves its directory to the Trash.
    /// `claude` is needed only for an account that is logged in.
    public func remove(_ account: Account, claude: URL?) async throws(CloverError) {
        try checkRemovable(account)
        if account.config().isLoggedIn {
            guard let claude else { throw CloverError("未找到 claude，无法退出账号「\(account.id)」的登录，未删除") }
            let result = try await Subprocess.run(claude, ["auth", "logout"], env: LaunchEnvironment.make(for: account), timeout: .seconds(30))
            guard result.status == 0 else { throw CloverError("账号「\(account.id)」退出登录失败，未删除") }
        }
        do {
            try FileManager.default.trashItem(at: account.dir, resultingItemURL: nil)
        } catch {
            throw CloverError("无法把 \(account.dir.path) 移到废纸篓：\(error.localizedDescription)")
        }
    }

    /// Why the account cannot be removed now, if it cannot.
    public func checkRemovable(_ account: Account) throws(CloverError) {
        guard !account.isMain else { throw CloverError("main 是 ~/.claude，不能删除") }
        guard !account.isRunning else { throw CloverError("账号「\(account.id)」还有 Claude 在运行，请先退出") }
    }

    /// Why `id` cannot name a new account, if it cannot. It becomes the directory's name.
    private func checkNewID(_ id: String) throws(CloverError) {
        guard id.wholeMatch(of: /[a-z0-9][a-z0-9-]{0,31}/) != nil else {
            throw CloverError("账号名只能用小写字母、数字和 -，且以字母或数字开头")
        }
        guard id != Account.mainID, !accounts().contains(where: { $0.id == id }) else {
            throw CloverError("账号「\(id)」已存在")
        }
    }
}

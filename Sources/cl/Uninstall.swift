import CloverCore
import Foundation

/// `cl uninstall`: removes everything Clover put on this Mac. Every account but `main` is
/// logged out through Claude Code and moved to the Trash; `main` (~/.claude) is never touched.
enum Uninstall {
    static func run(_ store: AccountStore) async throws {
        let accounts = store.accounts().filter { !$0.isMain }
        if let busy = accounts.first(where: \.isRunning) {
            throw CloverError("账号「\(busy.id)」还有 Claude 在运行，请先退出后再卸载")
        }
        let app = appBundle, link = commandLink(into: app)
        let claude = try accounts.contains { $0.config().isLoggedIn } ? ClaudeBinary.require() : nil

        print("将卸载 Clover：")
        for account in accounts {
            let count = account.conversationCount
            print("  · 账号 \(account.id)（\(describe(account.config()))\(count > 0 ? " · \(count) 个对话" : "")）")
        }
        if accounts.contains(where: { $0.config().isLoggedIn }) {
            print("    → 先退出登录（无法撤销，之后需要重新登录）")
        }
        if !accounts.isEmpty {
            print("    → 把文件夹移到废纸篓（对话记录可从废纸篓找回）")
        }
        print("  · 删除 " + ([app?.path, link?.path].compactMap(\.self) + ["Clover 的偏好设置"]).joined(separator: "、"))
        print("  · 不会改动 main（~/.claude）\n")
        guard Terminal.confirm("确定卸载？") else { return print("未卸载") }

        run("/usr/bin/pkill", "-x", "Clover")
        for account in accounts {
            let wasLoggedIn = account.config().isLoggedIn
            try await store.remove(account, claude: claude)
            print("✓ 账号 \(account.id)：\(wasLoggedIn ? "已退出登录，" : "")文件夹已移到废纸篓")
        }
        try? FileManager.default.trashItem(at: store.root, resultingItemURL: nil)

        run("/usr/bin/defaults", "delete", "com.leoven.clover")
        if let link { try? FileManager.default.removeItem(at: link) }
        if let app { try FileManager.default.trashItem(at: app, resultingItemURL: nil) }
        print("✓ 已删除 Clover.app、cl 命令和偏好设置\n卸载完成。")
    }

    /// The app this `cl` ships in, else the installed one.
    private static var appBundle: URL? {
        let me = Bundle.main.executableURL?.resolvingSymlinksInPath()
        let bundle = me?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if let bundle, bundle.pathExtension == "app" { return bundle }
        let installed = URL(filePath: "/Applications/Clover.app")
        return FileManager.default.fileExists(atPath: installed.path) ? installed : nil
    }

    /// ~/.local/bin/cl, when it links into the app.
    private static func commandLink(into app: URL?) -> URL? {
        let link = URL.homeDirectory.appending(path: ".local/bin/cl")
        guard let app, let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path),
              target.hasPrefix(app.path) else { return nil }
        return link
    }

    private static func run(_ executable: String, _ arguments: String...) {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

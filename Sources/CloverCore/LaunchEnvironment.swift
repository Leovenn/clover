import Foundation

/// The environment Claude Code runs in for an account.
public enum LaunchEnvironment {
    /// Variables that would choose the login instead of the account's directory.
    static let overriding: Set = [
        "CLAUDE_CONFIG_DIR", "CLAUDE_SECURESTORAGE_CONFIG_DIR",
        "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
    ]

    /// `base` without the overriding variables, pointed at the account. `main` runs without
    /// CLAUDE_CONFIG_DIR, exactly as plain `claude` does, so both share one login.
    public static func make(for account: Account,
                            from base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var env = base.filter { !overriding.contains($0.key) }
        if !account.isMain { env["CLAUDE_CONFIG_DIR"] = account.dir.path }
        return env
    }

    /// Variables that send requests to a cloud provider instead of a Claude account. Clover
    /// leaves them alone, but warns: with one set, the chosen account is not used.
    static let thirdParty: Set = ["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"]

    /// What would still replace the account's login: a cloud provider switched on in the
    /// environment, or an apiKeyHelper or overriding variable in the account's or the
    /// project's settings.
    public static func overrides(for account: Account, in project: URL,
                                 env: [String: String] = ProcessInfo.processInfo.environment) -> [String] {
        let shell = thirdParty.filter { isOn(env[$0]) }.sorted()
            .map { "环境变量 \($0) 会让 Claude 改用第三方平台，不使用账号「\(account.id)」" }
        let files = [
            account.dir.appending(path: "settings.json"),
            project.appending(path: ".claude/settings.json"),
            project.appending(path: ".claude/settings.local.json"),
        ]
        return shell + files.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                  let s = try? JSONDecoder().decode(AuthSettings.self, from: data) else { return nil }
            let vars = (s.env ?? [:]).filter { overriding.union(thirdParty).contains($0.key) && isOn($0.value) }.keys.sorted()
            let keys = (s.apiKeyHelper == nil ? [] : ["apiKeyHelper"]) + vars
            return keys.isEmpty ? nil : "\(file.path) 中的 \(keys.joined(separator: "、")) 会顶替账号「\(account.id)」的登录"
        }
    }

    private static func isOn(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.isEmpty && value != "0"
    }
}

private struct AuthSettings: Decodable {
    let apiKeyHelper: Presence?
    let env: [String: String]?
}

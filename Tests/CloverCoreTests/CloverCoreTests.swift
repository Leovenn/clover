import Foundation
import Testing
@testable import CloverCore

/// A throw-away home: ~/.claude and ~/.clover-accounts under one temp dir.
struct Sandbox {
    let root = FileManager.default.temporaryDirectory.appending(path: "clover-\(UUID().uuidString)")
    var store: AccountStore {
        AccountStore(mainDir: root.appending(path: ".claude"), root: root.appending(path: ".clover-accounts"))
    }

    func write(_ json: String, to path: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: url)
    }
}

@Suite struct AccountStoreTests {
    @Test func scansMainFirstThenOthersByName() throws {
        let box = Sandbox()
        try box.write("{}", to: ".claude/settings.json")
        try box.write("{}", to: ".clover-accounts/work/settings.json")
        try box.write("{}", to: ".clover-accounts/alt/settings.json")
        try box.write("", to: ".clover-accounts/stray-file")

        #expect(box.store.accounts().map(\.id) == ["main", "alt", "work"])
    }

    @Test func mainConfigLivesBesideTheDirectory() throws {
        let box = Sandbox()
        try box.write("{}", to: ".claude/settings.json")
        _ = try box.store.create("work")
        let main = try box.store.account("main"), work = try box.store.account("work")

        #expect(main.configFile == box.root.appending(path: ".claude.json"))
        #expect(work.configFile == work.dir.appending(path: ".claude.json"))
    }

    @Test func createValidatesAndLocksDown() throws {
        let store = Sandbox().store
        let work = try store.create("work-2")
        let mode = try FileManager.default.attributesOfItem(atPath: work.dir.path)[.posixPermissions] as? Int

        #expect(mode == 0o700)
        #expect(throws: CloverError.self) { try store.create("work-2") }
        #expect(throws: CloverError.self) { try store.create("main") }
        #expect(throws: CloverError.self) { try store.create("Work") }
        #expect(throws: CloverError.self) { try store.create("-x") }
    }

    @Test func countsSavedConversations() throws {
        let box = Sandbox()
        let work = try box.store.create("work")
        try box.write("", to: ".clover-accounts/work/projects/-a/1.jsonl")
        try box.write("", to: ".clover-accounts/work/projects/-a/2.jsonl")
        try box.write("", to: ".clover-accounts/work/projects/-b/3.jsonl")
        try box.write("", to: ".clover-accounts/work/projects/-b/memory/notes.md")

        #expect(work.conversationCount == 3)
    }

    @Test func mainCannotBeRemoved() throws {
        let box = Sandbox()
        try box.write("{}", to: ".claude/settings.json")
        #expect(throws: CloverError.self) { try box.store.checkRemovable(box.store.account("main")) }
    }
}

@Suite struct ClaudeConfigTests {
    @Test func readsIdentityAndMatchingQuota() throws {
        let box = Sandbox()
        try box.write("""
        {"oauthAccount": {"accountUuid": "u1", "emailAddress": "me@x.com", "organizationType": "claude_max"},
         "cachedUsageUtilization": {"accountUuid": "u1", "fetchedAtMs": 1762437599000,
           "utilization": {"five_hour": {"utilization": 9, "resets_at": "2026-11-06T13:59:59.840848+00:00"},
                           "seven_day": {"utilization": 17.5, "resets_at": null}}}}
        """, to: "c.json")
        let config = ClaudeConfig(contentsOf: box.root.appending(path: "c.json"))

        #expect(config.identity == .init(uuid: "u1", email: "me@x.com", plan: "Max"))
        #expect(config.quota?.fiveHour?.percent == 9)
        #expect(config.quota?.fiveHour?.resetsAt == Date(timeIntervalSince1970: 1_793_973_599.840848))
        #expect(config.quota?.sevenDay == .init(percent: 17.5, resetsAt: nil))
        #expect(config.isLoggedIn)
    }

    @Test func ignoresQuotaOfAnotherAccount() throws {
        let box = Sandbox()
        try box.write("""
        {"oauthAccount": {"accountUuid": "u2"},
         "cachedUsageUtilization": {"accountUuid": "u1", "fetchedAtMs": 0, "utilization": {}}}
        """, to: "c.json")
        #expect(ClaudeConfig(contentsOf: box.root.appending(path: "c.json")).quota == nil)
    }

    @Test func aFieldInAnUnexpectedShapeHidesOnlyItself() throws {
        let box = Sandbox()
        try box.write("""
        {"oauthAccount": {"accountUuid": "u1", "emailAddress": "me@x.com"},
         "cachedUsageUtilization": {"accountUuid": "u1", "utilization": "changed"}}
        """, to: "c.json")
        let config = ClaudeConfig(contentsOf: box.root.appending(path: "c.json"))

        #expect(config.identity?.email == "me@x.com")
        #expect(config.quota == nil)
    }

    @Test func consoleLoginAndMissingFile() throws {
        let box = Sandbox()
        try box.write(#"{"primaryApiKey": "sk-secret"}"#, to: "c.json")
        let console = ClaudeConfig(contentsOf: box.root.appending(path: "c.json"))
        let missing = ClaudeConfig(contentsOf: box.root.appending(path: "none.json"))

        #expect(console.usesAPIKey && console.isLoggedIn && console.identity == nil)
        #expect(!missing.isLoggedIn)
    }
}

@Suite struct LaunchEnvironmentTests {
    @Test func stripsOverridesAndPointsAtTheAccount() {
        let base = ["PATH": "/bin", "ANTHROPIC_API_KEY": "k", "CLAUDE_CONFIG_DIR": "/elsewhere", "HTTPS_PROXY": "p"]
        let work = Account(id: "work", dir: URL(filePath: "/accounts/work"))
        let main = Account(id: "main", dir: URL(filePath: "/home/.claude"))

        #expect(LaunchEnvironment.make(for: work, from: base) == ["PATH": "/bin", "HTTPS_PROXY": "p", "CLAUDE_CONFIG_DIR": "/accounts/work"])
        #expect(LaunchEnvironment.make(for: main, from: base) == ["PATH": "/bin", "HTTPS_PROXY": "p"])
    }

    /// The Keychain item is named after this exact string, so it must stay the same however
    /// the account was found.
    @Test func configDirIsSpelledTheSameEveryTime() throws {
        let store = Sandbox().store
        let created = try store.create("work")
        let listed = try store.account("work")

        #expect(LaunchEnvironment.make(for: created, from: [:]) == LaunchEnvironment.make(for: listed, from: [:]))
        #expect(LaunchEnvironment.make(for: listed, from: [:])["CLAUDE_CONFIG_DIR"] == store.root.path + "/work")
    }

    @Test func reportsSettingsThatReplaceTheLogin() throws {
        let box = Sandbox()
        let work = try box.store.create("work")
        try box.write(#"{"apiKeyHelper": "/bin/key", "env": {"ANTHROPIC_API_KEY": "k", "FOO": "1"}}"#,
                      to: ".clover-accounts/work/settings.json")
        try box.write(#"{"env": {"FOO": "1"}}"#, to: "project/.claude/settings.json")
        let project = box.root.appending(path: "project")

        let quiet = LaunchEnvironment.overrides(for: work, in: project, env: ["CLAUDE_CODE_USE_VERTEX": "0"])
        #expect(quiet.count == 1)
        #expect(quiet.first?.contains("apiKeyHelper、ANTHROPIC_API_KEY") == true)

        let bedrock = LaunchEnvironment.overrides(for: work, in: project, env: ["CLAUDE_CODE_USE_BEDROCK": "1"])
        #expect(bedrock.count == 2)
        #expect(bedrock.first?.contains("CLAUDE_CODE_USE_BEDROCK") == true)
    }
}

/// Against the real ~/.claude and the real claude: `CLOVER_LIVE=1 make test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["CLOVER_LIVE"] == "1"))
struct LiveTests {
    @Test func refreshesMainQuotaThroughClaude() async throws {
        let main = try #require(AccountStore().accounts().first { $0.isMain })
        let claude = try #require(ClaudeBinary.find())
        let before = main.config().quota?.fetchedAt ?? .distantPast

        try await UsageProbe.refresh(main, claude: claude)
        let quota = try #require(main.config().quota)

        #expect(quota.fetchedAt > before)
        #expect(quota.fiveHour != nil && quota.sevenDay != nil)
    }
}

import CloverCore
import Foundation

// cl [claude arguments...]              pick an account, then become `claude`
// cl run <account> [claude arguments...] the same, without picking
// cl add <name> | cl rm <name> | cl ls   manage accounts
// cl uninstall                          remove Clover and every account but main

let store = AccountStore()
let arguments = Array(CommandLine.arguments.dropFirst())

do {
    switch arguments.first {
    case "run": try run(Array(arguments.dropFirst()))
    case "add": try addAccount(Array(arguments.dropFirst()))
    case "rm": try await removeAccount(Array(arguments.dropFirst()))
    case "ls": listAccounts()
    case "uninstall": try await Uninstall.run(store)
    default: try launch(chooseAccount(), arguments)
    }
} catch {
    Terminal.fail(error.localizedDescription)
}

// MARK: - Commands

/// `cl run <account> ...`: everything after the account goes to claude unchanged.
func run(_ arguments: [String]) throws -> Never {
    guard let id = arguments.first else { throw CloverError("用法：cl run <账号> [claude 参数...]") }
    try launch(store.account(id), Array(arguments.dropFirst()))
}

/// Becomes claude, running as the account.
func launch(_ account: Account, _ arguments: [String]) throws -> Never {
    let claude = try ClaudeBinary.require()
    LaunchEnvironment.overrides(for: account, in: .currentDirectory()).forEach(Terminal.warn)
    try Spawn.exec(claude, arguments, env: LaunchEnvironment.make(for: account))
}

/// Creates the account's directory and starts Claude Code in it, where the user logs in.
func addAccount(_ arguments: [String]) throws {
    guard arguments.count == 1, let id = arguments.first else { throw CloverError("用法：cl add <名称>") }
    let claude = try ClaudeBinary.require()
    let account = try store.create(id)
    print("✓ 已创建 \(account.dir.path)")
    print("→ 以账号 \(id) 启动 Claude，请在其中完成登录，之后退出即可\n")
    Spawn.run(claude, [], env: LaunchEnvironment.make(for: account))

    let config = account.config()
    guard config.isLoggedIn else {
        print("\n账号 \(id) 尚未登录。之后运行 cl run \(id)，在 Claude 中执行 /login")
        return
    }
    print("\n✓ 账号 \(id)：\(describe(config))")
    if let uuid = config.identity?.uuid,
       let twin = store.accounts().first(where: { $0.id != id && $0.config().identity?.uuid == uuid }) {
        Terminal.warn("它和账号「\(twin.id)」登录的是同一个 Claude 账号")
    }
}

/// Logs the account out through Claude Code and moves its directory to the Trash.
func removeAccount(_ arguments: [String]) async throws {
    guard arguments.count == 1, let id = arguments.first else { throw CloverError("用法：cl rm <名称>") }
    let account = try store.account(id)
    try store.checkRemovable(account)
    guard Terminal.confirm("删除账号「\(id)」（\(describe(account.config()))）？将先退出登录，再把文件夹移到废纸篓") else {
        print("未删除")
        return
    }
    try await store.remove(account, claude: ClaudeBinary.find())
    print("✓ 已删除账号 \(id)，文件夹在废纸篓中")
}

func listAccounts() {
    let accounts = store.accounts()
    guard !accounts.isEmpty else { return print(noAccounts) }
    for line in rows(accounts) { print(line) }
}

// MARK: - Helpers

/// The first account, `main` when there is one, is offered first; scripts get it unasked.
func chooseAccount() throws -> Account {
    let accounts = store.accounts()
    guard let first = accounts.first else { throw CloverError(noAccounts) }
    guard accounts.count > 1, Terminal.isInteractive else { return first }
    guard let index = Picker.choose(rows(accounts), selected: 0) else { exit(130) }
    return accounts[index]
}

func rows(_ accounts: [Account]) -> [String] {
    let width = accounts.map(\.id.count).max() ?? 0
    return accounts.map { "\($0.id.padding(toLength: width, withPad: " ", startingAt: 0))   \(describe($0.config()))" }
}

func describe(_ config: ClaudeConfig) -> String {
    if let me = config.identity { return [me.email, me.plan].compactMap(\.self).joined(separator: " · ") }
    return config.usesAPIKey ? "API 计费" : "未登录"
}

let noAccounts = "还没有账号：登录 ~/.claude，或运行 cl add <名称>"

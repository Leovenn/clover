import Foundation

/// Finds the official `claude` executable.
public enum ClaudeBinary {
    /// CLOVER_CLAUDE, else the first `claude` on PATH.
    public static func find(env: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let path = env["CLOVER_CLAUDE"] { return executable(path) }
        return (env["PATH"] ?? "").split(separator: ":").lazy
            .compactMap { executable("\($0)/claude") }
            .first
    }

    /// For an app started outside a terminal, whose PATH lacks the user's: ask the login shell.
    public static func findThroughLoginShell() async -> URL? {
        let shell = URL(filePath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        guard let result = try? await Subprocess.run(shell, ["-ilc", "command -v claude"], env: ProcessInfo.processInfo.environment, timeout: .seconds(10)),
              let line = String(decoding: result.stdout, as: UTF8.self).split(separator: "\n").last else { return nil }
        return executable(line.trimmingCharacters(in: .whitespaces))
    }

    public static func require() throws(CloverError) -> URL {
        guard let url = find() else { throw CloverError("未找到 claude，请先安装 Claude Code，或设置 CLOVER_CLAUDE") }
        return url
    }

    private static func executable(_ path: String) -> URL? {
        FileManager.default.isExecutableFile(atPath: path) ? URL(filePath: path) : nil
    }
}

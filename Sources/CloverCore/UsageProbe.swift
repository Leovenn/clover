import Foundation

/// Asks Claude Code to refresh an account's quota reading. `claude -p /usage` is a local
/// command: no model turn, no tokens. Claude refreshes its own login, queries Anthropic and
/// caches the answer in .claude.json, where `ClaudeConfig` reads it.
public enum UsageProbe {
    /// No tools, MCP servers, settings or saved session: only Claude's own /usage answer.
    static let arguments = ["-p", "/usage", "--output-format", "json", "--tools", "",
                            "--strict-mcp-config", "--setting-sources", "", "--no-session-persistence"]

    public static func refresh(_ account: Account, claude: URL) async throws(CloverError) {
        var env = LaunchEnvironment.make(for: account)
        // With it set, /usage stays offline and caches nothing.
        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = nil
        env["CLAUDE_CODE_DISABLE_AUTO_MEMORY"] = "1"
        env["DISABLE_AUTOUPDATER"] = "1"

        let result = try await Subprocess.run(claude, arguments, env: env, timeout: .seconds(45))
        let answer = try? JSONDecoder().decode(Answer.self, from: result.stdout)
        if answer?.is_error == true || result.status != 0 {
            throw CloverError(answer?.result.map(summary) ?? "额度刷新失败")
        }
    }

    private struct Answer: Decodable {
        let is_error: Bool
        let result: String?
    }

    private static func summary(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > 60 ? line.prefix(60) + "…" : line
    }
}

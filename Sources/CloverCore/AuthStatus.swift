import Foundation

/// Asks Claude Code which plan an account is on, as its /status shows it. `claude auth status`
/// reads the login Claude Code keeps in the Keychain, which follows an upgrade; the profile
/// cached in .claude.json can be days old. Local: no model turn, no tokens.
public enum AuthStatus {
    public static func plan(_ account: Account, claude: URL) async throws(CloverError) -> String? {
        let result = try await Subprocess.run(claude, ["auth", "status"], env: LaunchEnvironment.make(for: account), timeout: .seconds(20))
        return plan(from: result.stdout)
    }

    /// "pro" → "Pro". Nil when Claude Code does not know the plan, which happens.
    static func plan(from json: Data) -> String? {
        guard let type = (try? JSONDecoder().decode(Answer.self, from: json))?.subscriptionType,
              !type.isEmpty else { return nil }
        return type.prefix(1).uppercased() + type.dropFirst()
    }

    private struct Answer: Decodable {
        let subscriptionType: String?
    }
}

import Foundation

/// One Claude Code account: a config directory Claude Code runs in.
/// `main` is ~/.claude, used in place; every other account is ~/.clover-accounts/<id>.
public struct Account: Identifiable, Hashable, Sendable {
    public static let mainID = "main"

    public let id: String
    public let dir: URL

    public var isMain: Bool { id == Self.mainID }

    /// Claude keeps .claude.json beside ~/.claude for the default profile, inside the directory otherwise.
    public var configFile: URL {
        (isMain ? dir.deletingLastPathComponent() : dir).appending(path: ".claude.json")
    }

    /// What Claude Code has recorded about this account: who is logged in and the last quota reading.
    public func config() -> ClaudeConfig { ClaudeConfig(contentsOf: configFile) }

    /// How many conversations Claude Code has saved here: one transcript per conversation
    /// in projects/<project>/.
    public var conversationCount: Int {
        let fm = FileManager.default
        let projects = (try? fm.contentsOfDirectory(at: dir.appending(path: "projects"), includingPropertiesForKeys: nil)) ?? []
        return projects.reduce(0) { count, project in
            count + ((try? fm.contentsOfDirectory(atPath: project.path)) ?? []).count { $0.hasSuffix(".jsonl") }
        }
    }

    /// Whether a Claude Code process is running on this account now, from the registry each
    /// process keeps in <dir>/sessions/<pid>.json.
    public var isRunning: Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir.appending(path: "sessions"), includingPropertiesForKeys: nil)) ?? []
        return files.contains { file in
            guard let data = try? Data(contentsOf: file),
                  let entry = try? JSONDecoder().decode(SessionEntry.self, from: data) else { return false }
            return kill(entry.pid, 0) == 0
        }
    }
}

private struct SessionEntry: Decodable { let pid: Int32 }

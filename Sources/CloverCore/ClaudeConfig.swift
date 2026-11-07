import Foundation

/// The parts of an account's .claude.json that Clover reads. Claude Code writes this file;
/// Clover never does. Secrets are not decoded: an API key only counts as present.
public struct ClaudeConfig: Sendable {
    public struct Identity: Hashable, Sendable {
        public let uuid: String
        public let email: String
        public let plan: String?
    }

    public struct Window: Hashable, Sendable {
        public let percent: Double
        public let resetsAt: Date?
    }

    public struct Quota: Hashable, Sendable {
        public let fiveHour: Window?
        public let sevenDay: Window?
        public let fetchedAt: Date
    }

    /// The Claude account logged in here; nil when nobody is.
    public let identity: Identity?
    /// Logged in through Anthropic Console: billed per token, no quota windows.
    public let usesAPIKey: Bool
    /// The last quota reading Claude Code cached, only when it belongs to the account logged in now.
    public let quota: Quota?

    public var isLoggedIn: Bool { identity != nil || usesAPIKey }

    public init(contentsOf url: URL) {
        let raw = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Raw.self, from: $0) }
        identity = raw?.oauthAccount.map {
            Identity(uuid: $0.accountUuid, email: $0.emailAddress ?? "", plan: $0.organizationType.map(Self.planName))
        }
        usesAPIKey = raw?.primaryApiKey != nil
        quota = raw?.cachedUsageUtilization.flatMap { cache in
            guard cache.accountUuid == raw?.oauthAccount?.accountUuid else { return nil }
            return Quota(fiveHour: cache.utilization.five_hour?.window,
                         sevenDay: cache.utilization.seven_day?.window,
                         fetchedAt: Date(timeIntervalSince1970: cache.fetchedAtMs / 1000))
        }
    }

    /// "claude_max" → "Max".
    static func planName(_ type: String) -> String {
        let name = type.hasPrefix("claude_") ? String(type.dropFirst("claude_".count)) : type
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

// MARK: - File format

private struct Raw: Decodable {
    struct OAuthAccount: Decodable {
        let accountUuid: String
        let emailAddress: String?
        let organizationType: String?
    }

    struct Cache: Decodable {
        let accountUuid: String
        let fetchedAtMs: Double
        let utilization: Utilization
    }

    struct Utilization: Decodable {
        let five_hour: RawWindow?
        let seven_day: RawWindow?
    }

    struct RawWindow: Decodable {
        let utilization: Double?
        let resets_at: String?

        var window: ClaudeConfig.Window? {
            utilization.map { percent in
                .init(percent: percent, resetsAt: resets_at.flatMap { try? Date($0, strategy: .iso8601WithFraction) })
            }
        }
    }

    let oauthAccount: OAuthAccount?
    let primaryApiKey: Presence?
    let cachedUsageUtilization: Cache?

    /// Each field on its own: a format change in one, say the quota cache, must not make the
    /// account look logged out.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        oauthAccount = try? c.decodeIfPresent(OAuthAccount.self, forKey: .oauthAccount)
        primaryApiKey = try? c.decodeIfPresent(Presence.self, forKey: .primaryApiKey)
        cachedUsageUtilization = try? c.decodeIfPresent(Cache.self, forKey: .cachedUsageUtilization)
    }

    private enum CodingKeys: CodingKey { case oauthAccount, primaryApiKey, cachedUsageUtilization }
}

/// Decodes any value without keeping it, so a secret only counts as present.
struct Presence: Decodable {
    init(from decoder: Decoder) throws {}
}

private extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    static var iso8601WithFraction: Date.ISO8601FormatStyle { .init(includingFractionalSeconds: true) }
}

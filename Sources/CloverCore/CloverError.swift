import Foundation

/// An error with a message meant for the user.
public struct CloverError: LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) { self.message = message }

    public var errorDescription: String? { message }
}

import CloverCore
import Darwin
import Foundation

/// Starts claude with the terminal it was given.
enum Spawn {
    /// Replaces this process with claude: no wrapper stays behind.
    static func exec(_ executable: URL, _ arguments: [String], env: [String: String]) throws(CloverError) -> Never {
        withCStrings(["claude"] + arguments, env.map { "\($0)=\($1)" }) { argv, envp in
            _ = execve(executable.path, argv, envp)
        }
        throw CloverError("无法启动 claude：\(String(cString: strerror(errno)))")
    }

    /// Runs claude as a child on this terminal and waits for it. Ctrl+C goes to claude only.
    static func run(_ executable: URL, _ arguments: [String], env: [String: String]) {
        var pid: pid_t = 0
        let spawned = withCStrings(["claude"] + arguments, env.map { "\($0)=\($1)" }) { argv, envp in
            posix_spawn(&pid, executable.path, nil, nil, argv, envp)
        }
        guard spawned == 0 else { return }

        signal(SIGINT, SIG_IGN)
        signal(SIGQUIT, SIG_IGN)
        defer {
            signal(SIGINT, SIG_DFL)
            signal(SIGQUIT, SIG_DFL)
        }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
    }

    private static func withCStrings<R>(_ argv: [String], _ envp: [String],
                                        _ body: ([UnsafeMutablePointer<CChar>?], [UnsafeMutablePointer<CChar>?]) -> R) -> R {
        let a = argv.map { strdup($0) } + [nil]
        let e = envp.map { strdup($0) } + [nil]
        defer { (a + e).forEach { free($0) } }
        return body(a, e)
    }
}

import Foundation
import Synchronization

/// Runs a non-interactive command to completion and returns its standard output.
enum Subprocess {
    struct Result {
        let status: Int32
        let stdout: Data
    }

    static func run(_ executable: URL, _ arguments: [String], env: [String: String],
                    in directory: URL = .homeDirectory, timeout: Duration) async throws(CloverError) -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = env
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        do { try process.run() } catch { throw CloverError("无法启动 \(executable.lastPathComponent)：\(error.localizedDescription)") }

        let running = Running(process)
        let deadline = Task {
            try await Task.sleep(for: timeout)
            running.timedOut.store(true, ordering: .relaxed)
            running.process.terminate()
        }
        defer { deadline.cancel() }

        let stdout = await withCheckedContinuation { done in
            DispatchQueue.global().async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                running.process.waitUntilExit()
                done.resume(returning: data)
            }
        }
        if running.timedOut.load(ordering: .relaxed) {
            throw CloverError("\(executable.lastPathComponent) 超时")
        }
        return Result(status: process.terminationStatus, stdout: stdout)
    }
}

/// Lets the deadline and the reader reach the process. Process is thread-safe for these calls.
private final class Running: @unchecked Sendable {
    let process: Process
    let timedOut = Atomic(false)
    init(_ process: Process) { self.process = process }
}

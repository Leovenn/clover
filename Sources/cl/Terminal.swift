import Darwin

/// Talking to the user on the terminal: messages go to stderr, so stdout stays claude's.
enum Terminal {
    static var isInteractive: Bool { isatty(STDIN_FILENO) == 1 && isatty(STDERR_FILENO) == 1 }

    static func warn(_ message: String) {
        fputs("⚠ \(message)\n", stderr)
    }

    static func fail(_ message: String) -> Never {
        fputs("cl: \(message)\n", stderr)
        exit(1)
    }

    /// y/N; false when there is nobody to ask.
    static func confirm(_ question: String) -> Bool {
        guard isInteractive else { return false }
        fputs("\(question) [y/N] ", stderr)
        return readLine()?.lowercased().hasPrefix("y") == true
    }
}

/// An inline list on the terminal: ↑↓ or j/k to move, a digit to jump, Enter to choose,
/// Esc, q or Ctrl+C to cancel.
enum Picker {
    static func choose(_ rows: [String], selected: Int) -> Int? {
        var selected = selected
        let raw = RawMode()
        defer { raw.restore() }

        write("请选择账号（↑↓ 选择，回车确认，Esc 取消）\n\u{1B}[?25l")
        draw(rows, selected)
        defer { write("\u{1B}[?25h") }

        while true {
            switch readKey() {
            case .up: selected = (selected + rows.count - 1) % rows.count
            case .down: selected = (selected + 1) % rows.count
            case .digit(let n) where n >= 1 && n <= rows.count: selected = n - 1
            case .enter:
                redraw(rows, selected, final: true)
                return selected
            case .cancel:
                redraw(rows, nil, final: true)
                return nil
            default: continue
            }
            redraw(rows, selected, final: false)
        }
    }

    private static func draw(_ rows: [String], _ selected: Int?) {
        for (i, row) in rows.enumerated() {
            let mark = i == selected ? "\u{1B}[1m❯ \(i + 1). \(row)\u{1B}[0m" : "  \(i + 1). \(row)"
            write("\u{1B}[2K\(mark)\n")
        }
    }

    /// Moves back over the list and draws it again; the final drawing leaves only the choice.
    private static func redraw(_ rows: [String], _ selected: Int?, final: Bool) {
        write("\u{1B}[\(rows.count + (final ? 1 : 0))A")
        if final {
            write("\u{1B}[J")
            if let selected { write("→ \(rows[selected])\n") }
        } else {
            draw(rows, selected)
        }
    }

    private enum Key { case up, down, enter, cancel, digit(Int), other }

    private static func readKey() -> Key {
        var buffer = [UInt8](repeating: 0, count: 8)
        let n = read(STDIN_FILENO, &buffer, buffer.count)
        guard n > 0 else { return .cancel }
        let bytes = Array(buffer[0..<n])
        switch bytes {
        case [27, 91, 65], [107]: return .up        // ↑ k
        case [27, 91, 66], [106]: return .down      // ↓ j
        case [13], [10]: return .enter
        case [27], [3], [113]: return .cancel       // Esc, Ctrl+C, q
        default:
            guard bytes.count == 1, (49...57).contains(bytes[0]) else { return .other }
            return .digit(Int(bytes[0]) - 48)       // 1–9
        }
    }

    private static func write(_ text: String) {
        fputs(text, stderr)
    }
}

/// Puts the terminal into raw mode until `restore`.
private struct RawMode {
    private var original = termios()

    init() {
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        cfmakeraw(&raw)
        raw.c_oflag = original.c_oflag  // keep \n → \r\n for output
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    func restore() {
        var original = original
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    }
}

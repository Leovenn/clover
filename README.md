# 🍀 Clover

**English** | [简体中文](README.zh-CN.md)

Use several Claude Code accounts on one Mac, side by side, without mixing them up. `cl` starts Claude Code as the account you pick, and a menu bar panel shows every account's usage.

- **Fully isolated.** Each account has its own login, conversations, settings, skills and MCP servers. Several accounts can run at the same time, even in the same folder.
- **Never touches your login.** Clover doesn't read, store or refresh tokens, and it sends no requests of its own. Logging in, renewing and checking usage are all done by the official `claude`.
- **Nothing in the way.** `cl` hands the terminal straight to `claude`, and every argument reaches it unchanged.

## Requirements

- **macOS 26 (Tahoe) or later**
- **Apple Silicon only** (M1 or newer). Intel Macs are not supported.
- [Claude Code](https://code.claude.com/docs/en/setup)

## Install

1. Download `Clover-<version>-macos-arm64.zip` from [Releases](https://github.com/Leovenn/clover/releases) and unzip it.
2. Move `Clover.app` to Applications.
3. Clover isn't notarized by Apple, so macOS blocks it the first time. Clear the download flag once, then open it:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Clover.app
   open /Applications/Clover.app
   ```

4. Put the `cl` command on your `PATH`:

   ```sh
   mkdir -p ~/.local/bin
   ln -sf /Applications/Clover.app/Contents/MacOS/cl ~/.local/bin/cl
   ```

   Any directory on your `PATH` works. The link follows the app when you update it.

To check the download, compare it with the `.sha256` file from the release: `shasum -a 256 -c Clover-<version>-macos-arm64.zip.sha256`.

To update, replace `Clover.app` in Applications with the new one.

## Usage

```sh
cl                    # pick an account, then start Claude Code
cl run work           # start Claude Code as the account "work"
cl run work -c        # anything after the name goes to claude unchanged
cl add work           # add an account, then log in inside Claude Code (/login)
cl rm work            # log out and move the account's folder to the Trash
cl ls                 # list accounts
cl uninstall          # remove Clover and every account except main
```

Your existing `~/.claude` is the account `main`. Running `claude` directly still uses it, exactly as before.

To resume a conversation, use the account that started it, for example `cl run work -r`.

## Menu bar

Click the clover to see each account's 5-hour and weekly usage, when each one resets, and whether the account is logged in. Readings refresh when you open the panel, at most once a minute, and cost no tokens. Nothing runs while the panel is closed.

## How it works

Claude Code reads everything from the directory in `CLAUDE_CONFIG_DIR`, and it names the account's Keychain item after that directory. Clover keeps one directory per account in `~/.clover-accounts/<name>`, sets the variable for the account you pick, and removes variables like `ANTHROPIC_API_KEY` that would override it.

Usage comes from `claude -p /usage`, a local command that doesn't call the model.

## Uninstall

Run `cl uninstall`. It logs every account except `main` out through Claude Code, moves their folders to the Trash, and removes the app. Dragging the app to the Trash instead leaves those logins in the Keychain.

## Note

Whether you may use several accounts depends on Anthropic's terms for each of them, and on your organization's policy. Clover doesn't raise or merge limits. It is not affiliated with Anthropic.

## License

[MIT](LICENSE)

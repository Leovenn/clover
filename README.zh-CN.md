# 🍀 Clover

[English](README.md) | **简体中文**

在一台 Mac 上同时使用多个 Claude Code 账号，互不干扰。`cl` 用你选择的账号启动 Claude Code，菜单栏面板显示所有账号的额度。

- **完全隔离**：每个账号的登录、对话、设置、skills 和 MCP 都是独立的。多个账号可以同时运行，甚至可以在同一个目录里。
- **不碰你的登录**：Clover 不读取、不保存、不刷新任何 token，也不自己发送请求。登录、续期和查询额度，都由官方 `claude` 完成。
- **不挡在中间**：`cl` 直接把终端交给 `claude`，所有参数原样传给它。

## 系统要求

- **macOS 26（Tahoe）或更高版本**
- **仅支持 Apple Silicon**（M1 及以后的芯片），不支持 Intel Mac
- [Claude Code](https://code.claude.com/docs/en/setup)

## 安装

1. 从 [Releases](https://github.com/Leovenn/clover/releases) 下载 `Clover-<版本>-macos-arm64.zip` 并解压。
2. 把 `Clover.app` 移到「应用程序」文件夹。
3. Clover 没有经过苹果公证，第一次打开时会被 macOS 拦下。先清除一次下载标记，再打开：

   ```sh
   xattr -dr com.apple.quarantine /Applications/Clover.app
   open /Applications/Clover.app
   ```

4. 把 `cl` 命令放到 `PATH` 上：

   ```sh
   mkdir -p ~/.local/bin
   ln -sf /Applications/Clover.app/Contents/MacOS/cl ~/.local/bin/cl
   ```

   `PATH` 里的任何目录都可以。之后更新 App 时，这个链接会自动指向新版本。

如果想校验下载的文件，可以和发布页里的 `.sha256` 文件比对：`shasum -a 256 -c Clover-<版本>-macos-arm64.zip.sha256`。

更新时，用新的 `Clover.app` 替换「应用程序」里的旧版即可。

## 使用

```sh
cl                    # 选择账号，然后启动 Claude Code
cl run work           # 用 work 账号启动 Claude Code
cl run work -c        # 账号名后面的参数原样交给 claude
cl add work           # 添加账号，然后在 Claude Code 里登录（/login）
cl rm work            # 退出该账号的登录，把它的文件夹移到废纸篓
cl ls                 # 列出所有账号
cl uninstall          # 卸载 Clover，并删除 main 以外的所有账号
```

你原来的 `~/.claude` 就是 `main` 账号，直接运行 `claude` 时用的还是它，和以前一样。

恢复对话时，要用开这个对话的账号，例如 `cl run work -r`。

## 菜单栏

点击四叶草，可以查看每个账号的 5 小时额度、本周额度、恢复时间和登录状态。额度在打开面板时刷新，同一个账号每分钟最多刷新一次，不消耗 token。面板关闭时，Clover 不在后台做任何事。

## 工作原理

Claude Code 的所有数据都从 `CLAUDE_CONFIG_DIR` 指定的目录读取，钥匙串里的登录条目也按这个目录命名。Clover 为每个账号准备一个目录 `~/.clover-accounts/<名称>`，启动时为所选账号设置这个变量，并移除 `ANTHROPIC_API_KEY` 这类会顶替账号的变量。

额度来自 `claude -p /usage`，这是一个本地命令，不调用模型。

## 卸载

请运行 `cl uninstall`。它会通过 Claude Code 退出 `main` 以外所有账号的登录，把这些账号的文件夹移到废纸篓，然后删除 App。如果直接把 App 拖进废纸篓，这些账号的登录会留在钥匙串里。

## 说明

能否同时使用多个账号，取决于 Anthropic 对每个账号的条款，以及你所在组织的规定。Clover 不会提高或合并任何额度，也与 Anthropic 没有关联。

## 许可证

[MIT](LICENSE)

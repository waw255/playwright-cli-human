# playwright-cli-human

面向 AI 编程工具和 Agent 的 Playwright CLI 浏览器技能。

它可以打开网页、读取内容、搜索、点击、填表、截图并检查页面状态。遇到 CAPTCHA、Cloudflare、登录或 SSO 时，会打开独立 Chrome 让用户手动处理；验证完成后，AI 工具继续读取页面并自动清理调试浏览器。

适用于 Claude Code、Codex、Hermes Agent、OpenClaw、OpenCode，以及其他支持 Agent Skills / `SKILL.md` 的工具。

> **上游来源与许可：** 本项目的 Playwright CLI 技能文档改写自 Microsoft 的 [`microsoft/playwright-cli`](https://github.com/microsoft/playwright-cli)，原项目及本项目均使用 Apache License 2.0。本项目包含显著修改，且不是 Microsoft 官方项目。详见 [`NOTICE`](NOTICE) 和 [`LICENSE`](LICENSE)。

## 安装前准备

这些环境要求对所有 AI 工具相同。已经安装的项目可以直接跳过。

### 1. 安装 Node.js

推荐安装 [Node.js 最新 LTS 版本](https://nodejs.org/en/download)。Node.js 会同时提供后面需要的 `npm` 和 `npx`。

Windows：

```powershell
winget install OpenJS.NodeJS.LTS
```

macOS：

```bash
brew install node
```

Ubuntu / Debian：

```bash
sudo apt update
sudo apt install -y nodejs npm
```

安装后重新打开终端，确认三个命令都有版本号输出：

```bash
node -v
npm -v
npx -v
```

建议使用当前 LTS；最低需要 Node.js 18。

### 2. 安装 Google Chrome

人机验证流程需要桌面版 Chrome。已经安装可以跳过。

Windows：

```powershell
winget install Google.Chrome
```

macOS：

```bash
brew install --cask google-chrome
```

Linux 可以使用 Google Chrome 或发行版提供的 Chromium。

### 3. 安装 Playwright CLI

```bash
npm install -g @playwright/cli@latest
playwright-cli --version
```

第二条命令能显示版本号，就说明浏览器控制环境已经准备好。

## 安装 Skill

### 方式一：交给安装器选择工具

这是最简单、也最通用的方式：

```bash
npx --yes skills add waw255/playwright-cli-human --global
```

安装器会检测本机已有的 AI 工具；需要选择时，勾选希望安装到的一个或多个工具。完成后重启对应工具或开启新会话。

### 方式二：直接指定工具

每个工具使用同一条安装命令，只是 `--agent` 后面的标识不同：

| AI 工具 | 安装命令 |
|---|---|
| Claude Code | `npx --yes skills add waw255/playwright-cli-human --global --agent claude-code --yes` |
| Codex | `npx --yes skills add waw255/playwright-cli-human --global --agent codex --yes` |
| Hermes Agent | `npx --yes skills add waw255/playwright-cli-human --global --agent hermes-agent --yes` |
| OpenClaw | `npx --yes skills add waw255/playwright-cli-human --global --agent openclaw --yes` |
| OpenCode | `npx --yes skills add waw255/playwright-cli-human --global --agent opencode --yes` |

需要一次安装到多个工具时，可以重复 `--agent`：

```bash
npx --yes skills add waw255/playwright-cli-human --global \
  --agent claude-code \
  --agent codex \
  --agent hermes-agent \
  --agent openclaw \
  --agent opencode \
  --yes
```

PowerShell 也可以直接写成一行。

`npx skills` 会自动选择共享目录或为目标工具创建链接，不需要手动移动 Skill 文件夹。

### 确认安装结果

查看全部全局 Skills：

```bash
npx --yes skills list --global
```

只查看某个工具时，在末尾加上对应标识：

```bash
npx --yes skills list --global --agent claude-code
```

列表中看到 `playwright-cli-human` 后，重启相应 AI 工具。

## 使用 cc-switch 导入和管理

cc-switch 用户可以用图形界面安装，不需要再运行 `npx`：

1. 打开 cc-switch，进入顶部的 **Skills** 页面。
2. 点击 **仓库管理** → **添加仓库**。
3. 填写下面的信息并保存：

| 字段 | 内容 |
|---|---|
| Owner | `waw255` |
| Name | `playwright-cli-human` |
| Branch | `main` |
| Subdirectory | `skill` |

4. 返回 Skills 页面并点击 **刷新**。
5. 找到 `playwright-cli-human`，点击 **安装**，再选择需要同步的应用。

cc-switch 会统一保存 Skill，并按设置通过软链接或复制同步到各应用目录。新版本出现时，可以在技能卡片上点击 **更新**；cc-switch v3.13.0 及以上还支持更新检测和全部更新。

按 cc-switch 当前官方说明，它的 Skills 面板支持 Claude Code、Codex、Gemini CLI、OpenCode 和 Hermes。OpenClaw 请使用上面的 `npx skills` 命令安装。

## 第一次使用

在任意已经加载该 Skill 的 AI 工具中输入：

```text
打开 https://example.com，告诉我页面标题并截一张图。
```

普通网页会自动操作。出现验证码或登录窗口时，请在弹出的独立 Chrome 中手动完成，然后回复“好了”；AI 工具会重新读取页面，不会自动点击验证控件。

## 更新与卸载

更新到最新版：

```bash
npx --yes skills update playwright-cli-human --global --yes
```

卸载：

```bash
npx --yes skills remove playwright-cli-human --global --yes
```

使用 cc-switch 安装的用户，直接在它的 Skills 页面更新或卸载。

## 常见问题

### 找不到 `node`、`npm` 或 `npx`

关闭并重新打开终端。如果仍然找不到，请重新安装 Node.js LTS，并确认安装程序已将 Node.js 加入 `PATH`。

### 找不到 `playwright-cli`

重新执行：

```bash
npm install -g @playwright/cli@latest
```

重新打开终端，再运行 `playwright-cli --version`。

### 已安装但 AI 工具没有加载 Skill

使用 `npx --yes skills list --global` 确认安装，然后完全重启对应工具。通过 cc-switch 管理时，同时确认该 Skill 已同步到目标应用。

### Chrome 没有启动

确认安装的是桌面版 Google Chrome。Windows 脚本会自动查找常见安装位置；便携版 Chrome 可以在调用启动脚本时提供 `-ChromePath`。

## 工作方式

| 场景 | 行为 |
|---|---|
| 普通网页、搜索、截图、表单 | AI 工具使用 Playwright CLI 自动完成 |
| CAPTCHA、Cloudflare、登录或 SSO | 用户在独立 Chrome 中处理，AI 工具之后只读页面 |

独立 Chrome 使用专用 profile，CDP 只监听本机 `127.0.0.1`。停止脚本必须同时确认专用 profile 和调试端口，无法确认归属时不会终止浏览器。

Windows 已提供完整生命周期脚本。Linux / macOS 的等价流程见 [`skill/references/human-antibot.md`](skill/references/human-antibot.md)。

## 安全提示

- 验证码和登录步骤由用户完成，AI 工具不尝试破解或绕过。
- 不要把密码、Cookie、令牌、storage state 或浏览器 profile 提交到仓库或公开 Issue。
- 付款、发布内容、删除数据等不可逆操作前，应再次确认。
- 技能创建的独立调试浏览器不会复用或关闭日常 Chrome。

## 开发

检查仓库结构、技能元数据、脚本语法、文档链接和敏感运行产物：

```powershell
pwsh -NoProfile -File ./tools/validate.ps1
```

检查仓库能否被 `npx skills` 识别：

```bash
npx --yes skills add . --list
```

贡献说明见 [`CONTRIBUTING.md`](CONTRIBUTING.md)，安全问题请通过 GitHub Security Advisory 私下报告。

## 上游来源与开源许可

- 原项目：[`microsoft/playwright-cli`](https://github.com/microsoft/playwright-cli)
- 原 npm 包：[`@playwright/cli`](https://www.npmjs.com/package/@playwright/cli)
- 原项目许可：Apache License 2.0
- 本项目许可：Apache License 2.0

`skill/SKILL.md` 和多数 `skill/references/` 文档由上游随包发布的 Playwright CLI Skill 改写而来。本项目对其进行了重命名、重组和安全边界调整，并加入人机协作 CDP 流程与配套脚本。每个修改过的上游文件都带有修改声明。

本项目独立维护，与 Microsoft Corporation 不存在隶属、赞助或官方背书关系。完整归属与变更说明见 [`NOTICE`](NOTICE)，许可证全文见 [`LICENSE`](LICENSE)。安装后的 Skill 目录也自带相同的 `NOTICE` 和 `LICENSE`。

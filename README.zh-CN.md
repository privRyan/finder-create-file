# Finder 右键新建文件

[English](README.md)

Finder Create File 会在 macOS 访达文件夹空白处的右键菜单中加入“新建文件”子菜单，可创建 TXT、Markdown、格式有效的空白 Word/Excel 文档，以及从内置白名单启用的开发和文本文件。

## 功能

- `.txt`、`.md`、`.docx`、`.xlsx` 四个菜单项连续显示，无多余分隔线
- 额外类型白名单包含 JSON、YAML（只保留 `.yaml`）、HTML、CSS、JavaScript、TypeScript、Python、Shell、XML、CSV；用户只能勾选或取消，不能自定义后缀或导入模板
- 菜单和文件名输入窗口均显示对应的文件类型图标
- 自动补充扩展名；同名时自动追加数字
- 使用排他方式创建文件，并发请求也绝不覆盖已有文件
- Word/Excel 模板内嵌在 App 资源中；扩展只保存带版本号的内置类型 ID 列表
- 同时支持 Apple 芯片和 Intel Mac 的 Universal 2 构建
- 不联网、无统计分析

## 系统要求与信任说明

- macOS 13 或更高版本
- Apple Command Line Tools（运行 `xcode-select --install` 安装）
- macOS 自带的 Bash、Swift 编译器和系统工具

本仓库**不分发**经过 Developer ID 签名和 Apple 公证的可执行文件，请审核源码后在自己的 Mac 上构建。当前源码安装默认放入 `~/Applications` 并使用临时签名；它不是成熟、已公证、可直接拖入 `/Applications` 的 DMG。

Finder Sync 扩展监听 `/`，只是为了让访达在所有位置提供右键菜单。主程序只接受已规范化且真实存在的用户目录或 `/Volumes` 内目录；创建前会显示最终目标路径；底层用排他创建保证不覆盖文件。

临时签名的沙盒扩展无法可靠使用 App Group：[本机最小实验](docs/APP-GROUP-PROBE.md)在沙盒初始化时失败，因为临时签名没有有效 Team ID/代码身份。本项目不需要跨进程共享设置：Finder 扩展在自己的标准沙盒偏好中保存内置类型选择，并自行把已启用项展开到菜单。扩展只向主程序传固定类型 ID 和目标路径，主程序会再次校验两者，再显示创建窗口。

## 构建、验证和安装

```sh
git clone https://github.com/privRyan/finder-create-file.git
cd finder-create-file
make test
make install
```

构建产物位于 `dist/FinderCreateFile.app`。安装时会先在目标旁的唯一暂存目录中完整复制并校验 App，再放入 `~/Applications`、注册并启用 Finder 扩展，然后重启访达。简单的原子锁会拒绝并发安装；可捕获信号只清理暂存目录和锁。若 App 已放置但注册失败，会保留完整 App；再次运行 `make install` 只重试注册，不重复复制。安装器不会猜测清理陈旧锁：确认没有安装进程后，请检查并手动移除准确的 `.FinderCreateFile.install.lock` 目录。如果菜单仍未出现，请到“系统设置 → 通用 → 登录项与扩展 → Finder”手动开启“Finder 新建文件菜单”。

项目明确不支持自动原地升级：安装器绝不移动、备份、删除或覆盖已有 App。若已有 App 的 bundle ID、签名和完整 bundle 指纹均与源码构建一致（包含所有架构及内嵌扩展），只重试注册；若属于不同构建，请先运行 `make uninstall`（旧 App 会移到废纸篓，可恢复），再运行 `make install`。

在访达已打开文件夹的空白处右键：

```text
新建文件
├── 文本文档 (.txt)
├── Markdown 文件 (.md)
├── Word 文档 (.docx)
├── Excel 工作簿 (.xlsx)
├── JSON 文件 (.json)      # 勾选后显示
├── XML 文件 (.xml)        # 勾选后显示
└── 管理文件类型…
```

额外类型按固定顺序显示。JSON 会生成 `{}`，HTML 会生成最小 HTML5 文档，Shell 会写入 `#!/bin/sh`，XML 会写入声明和 `<root/>`；本身允许为空的格式才创建空文件。YAML 只提供 `.yaml`，避免 `.yaml`/`.yml` 两个含义相同的选项造成歧义。

## 其他命令

```sh
make build       # 构建 App
make package     # 生成仅供本地使用的临时签名 ZIP，不应冒充已公证发布包
make uninstall   # 将 App 移到废纸篓，默认保留设置
./scripts/uninstall.sh --purge  # 同时把设置移到废纸篓
make clean       # 清理生成产物
```

需要时可覆盖构建参数：

```sh
VERSION=1.1.0 BUILD_NUMBER=2 BUNDLE_ID_PREFIX=io.github.example make build
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" make build
```

正式拖入 `/Applications` 的发行体验需要 Developer ID 签名和 Apple 公证。即使使用 Developer ID，公开分发二进制前仍须完成 Apple 公证。本项目不会把临时签名描述为 Gatekeeper 认可的正式发行签名。

## 模板来源

构建过程会从 `Resources/OfficeTemplates/` 中精简、可读的 OOXML 源文件可重复生成空白模板，并将 `blank.docx` 和 `blank.xlsx` 内嵌到 App 的 `Contents/Resources/Templates/`。项目不再分发 Microsoft 的图稿或模板文件。

App 图标由项目中的原创矢量路径在构建时绘制。运行时菜单和对话框图标使用 macOS 系统符号，不会将这些符号打包或再次分发。

## 安全与限制

详见 [SECURITY.md](SECURITY.md)。Finder 扩展把带版本号的选择保存在 `io.github.privRyan.FinderCreateFile.FinderSync` 标准偏好中，只记录固定类型 ID；未知、重复、损坏或版本不兼容的值都会被忽略，并始终按内置目录顺序显示。全部菜单项连续排列，四个默认项位于最前，“管理文件类型…”始终在最底部。沙盒扩展只根据编译期固定的 `FinderCreateFile.app/Contents/PlugIns/FinderCreateFileFinderSync.appex` 层级定位主程序，并拒绝非规范化路径或符号链接；它不会越过扩展沙盒读取父 App 文件来验证。Finder Sync 是 macOS 实现真正文件夹空白处右键菜单的扩展机制，因此系统可能要求用户手动启用。挂载在 `/Volumes` 以外的网络位置会被主动拒绝。目前界面文字为中文。

## 许可证

[MIT](LICENSE)

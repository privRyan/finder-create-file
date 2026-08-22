# Finder 右键新建文件

[English](README.md)

访达默认只能新建文件夹，没有内置的“新建空文件”命令。Finder Create File 解决的就是这个缺口：它会在文件夹空白处的右键菜单中加入“新建文件”，可创建 TXT、Markdown、格式有效的空白 Word/Excel/PowerPoint 文档，以及从白名单启用的开发和文本文件。

## 功能

- `.txt`、`.md`、`.docx`、`.xlsx`、`.pptx` 五个默认菜单项连续显示，无多余分隔线
- 额外类型白名单包含 JSON、YAML（只保留 `.yaml`）、HTML、CSS、JavaScript、TypeScript、Python、Shell、XML、CSV；用户只能勾选或取消，不能自定义后缀或导入模板
- 菜单和文件名输入窗口均显示对应的文件类型图标
- 自动补充扩展名；同名时自动追加数字
- 使用排他方式创建文件，并发请求也绝不覆盖已有文件
- Word/Excel/PowerPoint 模板内嵌在 App 资源中；扩展只保存带版本号的内置类型 ID 列表
- 设置窗口会立即置前，可缩放、滚动，并在打开期间通过 Command-Tab 切回
- 同时支持 Apple 芯片和 Intel Mac 的 Universal 2 构建
- 不联网、无统计分析

## 下载、安装与使用

1. 从 [Releases](https://github.com/privRyan/finder-create-file/releases) 下载 `FinderCreateFile-v1.1.0-macos-universal.zip`。
2. 解压后按住 Control 点击 **安装 FinderCreateFile.command**，选择“打开”。
3. 如有需要，到“系统设置 → 通用 → 登录项与扩展 → Finder”开启“Finder 新建文件菜单”。
4. 在访达文件夹空白处右键选择“新建文件”；通过“管理文件类型…”启用可选格式。

预编译包和源码构建均要求 macOS 13 或更高版本，主程序和扩展都是 Universal 2，同时包含 Apple 芯片（`arm64`）和 Intel（`x86_64`）代码。当前版本已在 Apple 芯片 Mac 的真实访达中测试；Intel 支持和 macOS 13 最低版本经过构建及静态门禁验证，但不声称已做对应实机测试。

安装、运行和创建文件不需要 Command Line Tools，也不需要 Microsoft Office；只有打开、编辑 `.docx`、`.xlsx`、`.pptx` 时才需要 Office 或其他兼容应用。本项目不添加登录项，访达会按需加载扩展。

下载包使用临时签名，不是 Developer ID 签名，也未经过 Apple 公证。首次运行时 macOS 可能要求“Control 点击 → 打开”或到“隐私与安全性”中允许。安装脚本不会移除 quarantine 属性，也不会关闭 Gatekeeper。

## 从源码构建

只有源码构建需要 Apple Command Line Tools（`xcode-select --install`，包含 Swift 和 Clang）；日常运行不需要。

Finder Sync 扩展监听 `/`，只是为了让访达在所有位置提供右键菜单。主程序只接受已规范化且真实存在的用户目录或 `/Volumes` 内目录；创建前会显示最终目标路径；底层用排他创建保证不覆盖文件。

临时签名的沙盒扩展无法可靠使用 App Group：[本机最小实验](docs/APP-GROUP-PROBE.md)在沙盒初始化时失败，因为临时签名没有有效 Team ID/代码身份。本项目不需要跨进程共享设置：Finder 扩展在自己的标准沙盒偏好中保存内置类型选择，并自行把已启用项展开到菜单。扩展只向主程序传固定类型 ID 和目标路径，主程序会再次校验两者，再显示创建窗口。

```sh
git clone https://github.com/privRyan/finder-create-file.git
cd finder-create-file
make test
make install
```

源码构建产物位于 `dist/FinderCreateFile.app`。安装时先在 `~/Applications` 旁暂存并校验 App，再注册、启用扩展并刷新访达。原子锁拒绝并发安装；可捕获信号会清理暂存目录和锁。注册失败后完整 App 会保留，再次安装只重试注册。安装器不会猜测清理陈旧锁；确认没有安装进程后，才应检查并手动移除准确的 `.FinderCreateFile.install.lock`。

项目明确不支持自动原地升级：安装器绝不移动、备份、删除或覆盖已有 App。若已有 App 的 bundle ID、签名和完整 bundle 指纹均与源码构建一致（包含所有架构及内嵌扩展），只重试注册；若属于不同构建，请先运行 `make uninstall`（旧 App 会移到废纸篓，可恢复），再运行 `make install`。

在访达已打开文件夹的空白处右键：

```text
新建文件
├── 文本文档 (.txt)
├── Markdown 文件 (.md)
├── Word 文档 (.docx)
├── Excel 工作簿 (.xlsx)
├── PowerPoint 演示文稿 (.pptx)
├── JSON 文件 (.json)      # 勾选后显示
├── XML 文件 (.xml)        # 勾选后显示
└── 管理文件类型…
```

额外类型按固定顺序显示。JSON 会生成 `{}`，HTML 会生成最小 HTML5 文档，Shell 会写入 `#!/bin/sh`，XML 会写入声明和 `<root/>`；本身允许为空的格式才创建空文件。YAML 只提供 `.yaml`，避免 `.yaml`/`.yml` 两个含义相同的选项造成歧义。

## 其他命令

```sh
make build       # 构建 App
make package     # 构建临时签名的 Universal 2 分发 ZIP
make uninstall   # 注销扩展并将 App 移到废纸篓，默认保留设置
./scripts/uninstall.sh --purge  # 同时把扩展设置容器移到废纸篓
make clean       # 清理生成产物
```

需要时可覆盖构建参数：

```sh
VERSION=1.1.0 BUILD_NUMBER=3 BUNDLE_ID_PREFIX=io.github.example make build
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" make build
```

正式拖入 `/Applications` 的发行体验需要 Developer ID 签名和 Apple 公证。即使使用 Developer ID，公开分发二进制前仍须完成 Apple 公证。本项目不会把临时签名描述为 Gatekeeper 认可的正式发行签名。

## 模板来源

构建过程会从 `Resources/OfficeTemplates/` 中可审计的 OOXML 源文件可重复生成 `blank.docx`、`blank.xlsx` 和一页 16:9、无可见对象的 `blank.pptx`，再内嵌到 App。项目不分发 Microsoft 图稿或模板文件。

App 图标由项目中的原创矢量路径在构建时绘制。运行时菜单和对话框图标使用 macOS 系统符号，不会将这些符号打包或再次分发。

## 安全与限制

详见 [SECURITY.md](SECURITY.md)。扩展只保存带版本号的固定类型 ID；未知、重复、损坏或版本不兼容的值都会被忽略。五个默认项位于最前，“管理文件类型…”始终在最底部。沙盒扩展会校验固定的父 App 层级；Finder Sync 可能需要用户手动启用。挂载在 `/Volumes` 以外的网络位置会被拒绝。目前界面文字为中文。

普通卸载会注销扩展、把 App 移到废纸篓并保留已选类型；`--purge` 还会尝试把官方设置容器移到废纸篓。系统管理的空容器元数据可能仍保留；来源不明的旧数据只会提示并保留，脚本不会猜测删除。

## 许可证

[MIT](LICENSE)

# Changelog / 更新日志

## 1.1.0 (build 3)

- Add PowerPoint (`.pptx`) as the fifth fixed default type, backed by a valid one-slide 16:9 OOXML template.
- Add a deterministic Universal 2 prebuilt ZIP with bilingual double-click install/uninstall commands and quick-start guides.
- Make extension/process cleanup independent of whether the app is still installed; clarify normal uninstall, purge, and preserved unknown data.
- Stop tests from creating real-user preference domains.
- 新增第五个固定默认类型 PowerPoint（`.pptx`），使用有效的一页 16:9 OOXML 空白模板。
- 新增确定性的 Universal 2 预编译 ZIP，包含可双击的中英安装/卸载命令和快速说明。
- 即使 App 已被手动删除，也会执行扩展与进程清理；明确普通卸载、彻底清理及未知数据保留策略。
- 测试不再创建真实用户偏好域。

## 1.0.1 (build 2)

- Bring the Finder extension's file-type settings window to the front and make it reachable from Command-Tab while open; restore background accessory behavior when it closes.
- Top-align the scrollable file-type list with a consistent inset.
- 访达扩展的文件类型设置窗口打开时会来到前台并可通过 Command-Tab 切回，关闭后恢复后台 accessory 行为。
- 可滚动的文件类型列表改为固定内边距的顶端对齐。

## 1.0.0 (build 1)

- Initial source-build release with four default types and ten optional allowlisted types.
- 首个源码构建版本，包含四种默认类型和十种可选白名单类型。

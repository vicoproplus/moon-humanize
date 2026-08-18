# 工具链 Windows 环境根因记录：moon test 崩溃 (0xC0000139)

> 创建：2026-08-18　状态：已定位，待系统级修复

## 现象

在 Windows 上执行 `moon test`（默认 `--target wasm`）时，`moonrun.exe` 启动即崩溃：

```
Error: Failed to run the test: ...\humanize.blackbox_test.wasm
The test executable exited with exit code: 0xc0000139
```

`0xc0000139` = `STATUS_ENTRYPOINT_NOT_FOUND`，即加载器在解析导入表时找不到某个 DLL 导出函数。

## 误判历史（请勿重蹈）

- **错误结论**：曾认为是 `C:\Windows\System32` 缺失 UCRT 转发 DLL（`api-ms-win-crt-*.dll`），
  需要 `scripts/fix-ucrt.ps1` 从 `downlevel` 复制到 `System32`。
- **对应产物已删除**：`scripts/fix-ucrt` 与 `scripts/fix-ucrt.ps1`，以及 `README.md` 中
  "Windows 环境：自动修复缺失的 UCRT DLL" 章节。
- **该结论错误**：VC++ Redist / UCRT 转发 DLL 均正常，`LoadLibrary` 全部可加载，复制它们无任何作用。

## 真实根因

用 `dumpbin /imports moonrun.exe` 与 `GetProcAddress` 实测确认：

- `moonrun.exe`（`moon 0.1.20260814`）**直接导入 `kernel32.dll` 的 `GetTempPath2W`**
  （ordinal 327）。
- `GetTempPath2W` 是 **Windows 10 21H1 / Build 19043** 才引入的 API。
- 当前系统**真实内核为 Windows 10 2004 / 19041**：
  - `BuildLabEx = 19041.1.amd64fre.vb_release.191206-1406`
  - `kernel32.dll` 文件版本 `10.0.19041.3155`
  - 注册表 `CurrentBuild=19045 / DisplayVersion=22H2` 为**版本伪装**，系统文件基线仍是 19041。
- 19041 的 `kernel32.dll` 中 `GetProcAddress(kernel32, "GetTempPath2W")` 返回 0（缺失），
  加载器解析 `moonrun.exe` 导入表失败 → 进程启动即 `0xC0000139`。

对照：`WaitOnAddress` / `WakeByAddress*` 等经 `api-ms-win-core-synch-l1-2-0` 转发到
`kernelbase.dll`，**均存在**；唯一缺失的就是 `GetTempPath2W`。

## 为什么 Windows Update 修不好

唯一可用更新 `KB5066791`（22H2 累积更新）反复安装失败，历史记录 `ResultCode = 4`
（WU 层拒绝）。原因是该包要求基线 ≥19042，而真实内核为 19041，被更新引擎判定为不适用。
`Get-HotFix -Id KB5066791` 查不到，确认从未成功安装。

## 修复方向（二选一）

### A. 升级系统内核到 19043+（治本，推荐）
让 `kernel32.dll` 获得 `GetTempPath2W`。需解除版本伪装并打通 19041→21H1/22H2 的
enablement（如 `KB5000736` / `KB5015684`），再装对应累积更新。涉及系统级变更与重启，需授权。

### B. 换环境跑测试（治标，低风险）
在 **真实 Windows 10 21H1+ / 11** 或 **Linux / macOS** 上执行：
```bash
cd moonbit && moon test
```
`moon build` 本身可成功（不依赖 `moonrun`），仅 `moon test` 受旧系统内核限制。

## 临时验证手段

代码逻辑已用 `moon test --target native` 在 native 后端验证通过（19/19），可绕过
`moonrun` 的 wasm 运行路径确认业务逻辑正确。

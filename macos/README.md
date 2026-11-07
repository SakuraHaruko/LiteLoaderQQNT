# macOS 注入器（QQ 7.x）

这个目录是 LiteLoaderQQNT 在 macOS QQ 7.x 上的加载器。它不修改 QQ 的
`package.json` / `application.asar` / `major.node`，因此不会触发
`Resources/app/application.json` 里的 RSA 完整性校验。

## 原理

QQ 启动时会尝试 `dlopen()` 这个可选文件：

```text
/Applications/QQ.app/Contents/Resources/app/app_launcher/launcher.node
```

`launcher.node` 只负责按 V8 主版本选择注入器：

- `ll-inject-v8-13.node`：Electron 34 / V8 13（QQ 6.9.x base）
- `ll-inject-v8-14.node`：Electron 40 / V8 14（QQ 7.x 热更新）

注入器在 QQ 主进程的 `dispatch_async(main_queue)` 里，用 V8 API 执行
`~/Library/Containers/com.tencent.qq/Data/Documents/ll-bootstrap.js`。
这个时机在 `app.ready` 之前，所以 LiteLoader 的
`protocol.registerSchemesAsPrivileged` 仍然有效。

`ll-bootstrap.js` 负责：

1. 加载 `Documents/LiteLoaderQQNT`；
2. 给每个 session 调用 `session.registerPreloadScript()` 注册 LL 的
   `api.js` / `module.js`；
3. 调用 LL 的 `protocolRegister()` 注册 `local://` 协议；
4. 监听 `browser-window-created`，手动触发
   `Runtime.triggerHooks("onBrowserWindowCreated")`。macOS 上 LL 是晚加载的，
   LL 自己的 `BrowserWindow` 代理不会生效，不补这一步的话依赖该生命周期的插件
   （如防撤回）会“加载了但没效果”。

## 构建

需要 macOS、Xcode Command Line Tools、`curl`、`tar`。

```bash
bash macos/build.sh
```

脚本会下载 Electron 34 / 40 的 headers，生成：

```text
macos/build/launcher.node
macos/build/ll-inject-v8-13.node
macos/build/ll-inject-v8-14.node
```

## 安装

```bash
bash macos/install.sh
```

脚本会把本仓库的 `src`、`package.json`、`LICENSE` 复制到
`~/Library/Containers/com.tencent.qq/Data/Documents/LiteLoaderQQNT`，
把注入器复制到 QQ 的 `app_launcher`。已有的 `plugins` 和 `data` 不会被删除。

安装后完全退出 QQ，再重新打开，设置中应出现 LiteLoaderQQNT。

卸载：

```bash
bash macos/uninstall.sh          # 只移除注入器，保留插件和数据
bash macos/uninstall.sh --purge  # 连 LiteLoaderQQNT 目录一起删除
```

## 适配新的 Electron / V8

在 `build.sh` 里加一行 `build_injector <electron 版本>`，例如：

```bash
build_injector 42.0.0
```

编译出来的文件名由头文件里的 `V8_MAJOR_VERSION` 决定；如果 V8 主版本不在
`launcher/dispatch.c` 的 `13..14` 范围内，需要同步扩大范围。

## 已验证

- macOS 27.0 (26A428), arm64
- QQ 7.0.3-54395
- Electron 40.0.0 / Node 24.11.1 / Chromium 144
- LiteLoaderQQNT 1.4.1

## 注意

这是非官方加载方式，会修改 QQ 进程；腾讯可能判定为外挂，存在账号风险。
QQ 更新/重装可能覆盖 `app_launcher`，届时重新执行 `install.sh` 即可。

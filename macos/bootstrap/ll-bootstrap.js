// LiteLoaderQQNT macOS bootstrap.
// Executed by ll-inject-v8-*.node before QQ's app.ready.
globalThis.__LITELOADER_PRELOAD__ = true;

const fs = process.mainModule.require('fs');
const path = process.mainModule.require('path');
const { app, session, BrowserWindow } = process.mainModule.require('electron');

function documentsDir() {
    try { return app.getPath('documents'); }
    catch (e) {
        return path.join(process.env.HOME || '', 'Library/Containers/com.tencent.qq/Data/Documents');
    }
}

const docs = documentsDir();
const root = path.join(docs, 'LiteLoaderQQNT');
const log = path.join(docs, 'll-bootstrap.log');

function writeLog(message) {
    try { fs.appendFileSync(log, `[${new Date().toISOString()}] ${message}\n`); } catch (e) {}
}

try {
    process.mainModule.require(root);
    writeLog('LiteLoader loaded');
} catch (e) {
    writeLog('LiteLoader failed: ' + (e && e.stack || e));
}

try {
    const { protocolRegister } = process.mainModule.require(path.join(root, 'src/main/api.js'));
    const { Runtime } = process.mainModule.require(path.join(root, 'src/main/runtime.js'));

    const preloads = [
        path.join(root, 'src/preload/api.js'),
        path.join(root, 'src/preload/module.js')
    ];
    const registered = new WeakSet();

    const registerSession = (ses) => {
        if (!ses || registered.has(ses)) return;
        registered.add(ses);

        if (typeof ses.registerPreloadScript === 'function') {
            for (const filePath of preloads) {
                try { ses.registerPreloadScript({ type: 'frame', filePath }); }
                catch (e) { writeLog('preload register failed: ' + e); }
            }
        }

        try { protocolRegister(ses.protocol); }
        catch (e) { writeLog('protocol register failed: ' + e); }
    };

    const triggerWindowHooks = (win) => {
        if (!win || !win.webContents) return;
        try { Runtime.triggerHooks('onBrowserWindowCreated', [win]); }
        catch (e) { writeLog('window hook failed: ' + (e && e.stack || e)); }
    };

    app.whenReady().then(() => {
        registerSession(session.defaultSession);
        for (const win of BrowserWindow.getAllWindows()) triggerWindowHooks(win);
    });

    app.on('session-created', registerSession);
    app.on('browser-window-created', (_event, win) => triggerWindowHooks(win));
} catch (e) {
    writeLog('bootstrap setup failed: ' + (e && e.stack || e));
}

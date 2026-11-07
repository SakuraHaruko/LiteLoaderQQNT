/*
 * LiteLoaderQQNT macOS V8 injector.
 *
 * This file is compiled once per V8 major version (see ../build.sh).  QQ
 * dlopen()s it from launcher.node; the constructor schedules work on the
 * main queue so it runs after Electron/Node have created the main isolate
 * but before app.ready.
 */
#include <v8.h>
#include <dispatch/dispatch.h>
#include <Foundation/Foundation.h>
#include <cstdio>
#include <string>

static std::string g_log;
static std::string g_bootstrap;

static std::string toStd(NSString *value) {
    return std::string(value.UTF8String ?: "");
}

static void resolvePaths() {
    @autoreleasepool {
        NSString *home = NSHomeDirectory();
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray<NSString *> *candidates = @[
            [home stringByAppendingPathComponent:@"Documents/ll-bootstrap.js"],
            [home stringByAppendingPathComponent:@"Library/Containers/com.tencent.qq/Data/Documents/ll-bootstrap.js"]
        ];

        NSString *bootstrap = candidates[0];
        for (NSString *candidate in candidates) {
            if ([fm fileExistsAtPath:candidate]) {
                bootstrap = candidate;
                break;
            }
        }

        g_bootstrap = toStd(bootstrap);
        g_log = toStd([[bootstrap stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"ll-inject.log"]);
    }
}

static void logLine(const char *message) {
    if (g_log.empty()) resolvePaths();
    FILE *file = fopen(g_log.c_str(), "a");
    if (!file) return;
    fputs(message, file);
    fputc('\n', file);
    fclose(file);
}

static std::string escapeForSingleQuotedJs(const std::string &value) {
    std::string out;
    out.reserve(value.size());
    for (char c : value) {
        if (c == '\\' || c == '\'') out.push_back('\\');
        out.push_back(c);
    }
    return out;
}

static void run() {
    if (g_bootstrap.empty()) resolvePaths();

    v8::Isolate *isolate = v8::Isolate::GetCurrent();
    if (!isolate) { logLine("inject: no isolate"); return; }

    v8::Locker locker(isolate);
    v8::Isolate::Scope isolateScope(isolate);
    v8::HandleScope handleScope(isolate);

    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) { logLine("inject: no context"); return; }
    v8::Context::Scope contextScope(context);

    const std::string logPath = escapeForSingleQuotedJs(g_log);
    const std::string bootstrapPath = escapeForSingleQuotedJs(g_bootstrap);
    const std::string source =
        "(function(){try{"
        "var fs=process.mainModule.require('fs');"
        "fs.appendFileSync('" + logPath + "','ready='+process.mainModule.require('electron').app.isReady());"
        "process.mainModule.require('" + bootstrapPath + "');"
        "return 'ok';"
        "}catch(e){try{process.mainModule.require('fs').appendFileSync('" + logPath + "',String(e&&e.stack||e));}catch(_){}}"
        "return 'fail';})()";

    v8::Local<v8::String> scriptSource = v8::String::NewFromUtf8(isolate, source.c_str()).ToLocalChecked();
    v8::Local<v8::Script> script;
    if (!v8::Script::Compile(context, scriptSource).ToLocal(&script)) {
        logLine("inject: compile failed");
        return;
    }

    v8::Local<v8::Value> result;
    if (!script->Run(context).ToLocal(&result)) {
        logLine("inject: run failed");
        return;
    }

    v8::String::Utf8Value text(isolate, result);
    logLine(*text ? *text : "inject: null");
}

__attribute__((constructor))
static void ll_inject(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        run();
    });
}

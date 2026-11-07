/*
 * LiteLoaderQQNT macOS launcher dispatcher.
 *
 * QQ's app_launcher dlopen()s this file (launcher.node) before it starts the
 * main process.  We only use its constructor to choose an injector that was
 * compiled against the V8 version of the running Electron framework, then
 * dlopen() that injector.
 *
 * V8 13 -> Electron 34 (QQ 6.9.x base)
 * V8 14 -> Electron 40 (QQ 7.x hot update)
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

__attribute__((constructor))
static void ll_dispatch(void) {
    typedef const char *(*get_version_fn)(void);

    get_version_fn get_version = (get_version_fn)dlsym(RTLD_DEFAULT, "_ZN2v82V810GetVersionEv");
    if (!get_version) return;

    const char *version = get_version();
    if (!version) return;

    int major = atoi(version);
    if (major < 13 || major > 14) return;

    Dl_info info;
    if (!dladdr((void *)ll_dispatch, &info) || !info.dli_fname) return;

    char dir[4096];
    snprintf(dir, sizeof(dir), "%s", info.dli_fname);
    char *slash = strrchr(dir, '/');
    if (slash) *slash = '\0';
    else snprintf(dir, sizeof(dir), ".");

    char path[4096];
    snprintf(path, sizeof(path), "%s/ll-inject-v8-%d.node", dir, major);
    dlopen(path, RTLD_NOW | RTLD_LOCAL);
}

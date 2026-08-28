// Purpose: Configures Chromium flags before Agent Chat creates its WebEngine process.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <limits.h>
#include <string>
#include <unistd.h>

extern "C" char** environ;

namespace {
using QGuiApplicationConstructor = void (*)(void*, int&, char**, int);
using WebEngineInitializer = void (*)();

bool isQuickshellProcess()
{
    char executable[PATH_MAX + 1] = {};
    const auto length = readlink("/proc/self/exe", executable, PATH_MAX);
    if (length <= 0) return false;
    executable[length] = '\0';
    const char* name = std::strrchr(executable, '/');
    name = name == nullptr ? executable : name + 1;
    return std::strcmp(name, "quickshell") == 0 || std::strcmp(name, "qs") == 0;
}

void rewriteInitialEnvironment(const char* name, const std::string& value)
{
    const std::string prefix = std::string(name) + "=";
    for (char** entry = environ; entry != nullptr && *entry != nullptr; entry++) {
        if (std::strncmp(*entry, prefix.c_str(), prefix.size()) != 0) continue;
        const auto capacity = std::strlen(*entry);
        const std::string replacement = prefix + value;
        if (replacement.size() <= capacity) {
            std::memcpy(*entry, replacement.c_str(), replacement.size() + 1);
        }
        return;
    }
}

void restorePreloadEnvironment()
{
    const char* requested = std::getenv("AGENT_CHAT_ORIGINAL_LD_PRELOAD");
    const std::string original = requested == nullptr ? "" : requested;
    rewriteInitialEnvironment("LD_PRELOAD", original);
    rewriteInitialEnvironment("AGENT_CHAT_ORIGINAL_LD_PRELOAD", "");
    if (!original.empty()) {
        setenv("LD_PRELOAD", original.c_str(), 1);
    } else {
        unsetenv("LD_PRELOAD");
    }
    setenv("AGENT_CHAT_ORIGINAL_LD_PRELOAD", "", 1);
}
}

__attribute__((constructor)) static void initializeWebEngineQuick()
{
    if (!isQuickshellProcess()) {
        restorePreloadEnvironment();
        return;
    }

    void* library = dlopen("libQt6WebEngineQuick.so.6", RTLD_NOW | RTLD_GLOBAL);
    auto initialize = library == nullptr ? nullptr : reinterpret_cast<WebEngineInitializer>(
        dlsym(library, "_ZN16QtWebEngineQuick10initializeEv"));
    if (initialize == nullptr) {
        std::fputs("Agent Chat could not initialize Qt WebEngine Quick\n", stderr);
        _exit(127);
    }
    initialize();
}

extern "C" void qGuiApplicationConstructor(void* self, int& argc, char** argv, int flags)
    __asm__("_ZN15QGuiApplicationC1ERiPPci");

extern "C" void qGuiApplicationConstructor(void* self, int& argc, char** argv, int flags)
{
    static auto original = reinterpret_cast<QGuiApplicationConstructor>(
        dlsym(RTLD_NEXT, "_ZN15QGuiApplicationC1ERiPPci"));
    static char applicationName[] = "quickshell";
    static char* fallbackArguments[] = {applicationName, nullptr};

    if (original == nullptr) {
        std::fputs("Agent Chat could not resolve the Qt GUI application constructor\n", stderr);
        _exit(127);
    }
    if (argc == 0) {
        argc = 1;
        argv = fallbackArguments;
    }
    original(self, argc, argv, flags);
}

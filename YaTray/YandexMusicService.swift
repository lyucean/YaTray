//
//  YandexMusicService.swift
//  YaTray
//
//  Запуск, показ/скрытие окна и проверка состояния приложения Яндекс Музыка.
//

import AppKit

/// Имена приложения в /Applications (пробел может быть обычным или неразрывным)
private let yandexMusicNames = ["Yandex Music.app", "Yandex\u{00A0}Music.app"]

enum YandexMusicService {

    static var appURL: URL? {
        let applications = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first ?? URL(fileURLWithPath: "/Applications")
        for name in yandexMusicNames {
            let url = applications.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Запущено ли приложение Яндекс Музыка
    static var isRunning: Bool {
        runningApplication != nil
    }

    /// Ссылка на запущенный процесс (если есть)
    static var runningApplication: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let bundleURL = app.bundleURL else { return false }
            let name = bundleURL.lastPathComponent
            return yandexMusicNames.contains(name) || name.contains("Yandex") && name.contains("Music")
        }
    }

    /// Минимальное безопасное окружение для запуска приложения (без переменных Xcode/Debug),
    /// чтобы не передавать __preview.dylib и не вызывать краш при запуске из Xcode.
    private static func cleanLaunchEnvironment() -> [String: String] {
        let current = ProcessInfo.processInfo.environment
        let safeKeys = ["HOME", "USER", "LOGNAME", "PATH", "SHELL", "TMPDIR", "LANG", "LC_ALL", "__CF_USER_TEXT_ENCODING"]
        var env: [String: String] = [:]
        for key in safeKeys {
            if let value = current[key], !value.contains("DerivedData"), !value.contains("__preview") {
                env[key] = value
            }
        }
        if env["PATH"] == nil { env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin" }
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        return env
    }

    /// Запустить приложение (если ещё не запущено).
    static func launch() {
        guard let url = appURL else { return }
        guard !isRunning else {
            showWindow()
            return
        }
        var config = NSWorkspace.OpenConfiguration()
        config.environment = cleanLaunchEnvironment()
        NSWorkspace.shared.open(url, configuration: config)
    }

    /// Показать окно приложения (активировать и вывести на передний план, в т.ч. развернуть из дока)
    static func showWindow() {
        guard let app = runningApplication else {
            launch()
            return
        }
        // Для уже запущенного приложения open(url) часто восстанавливает окно из дока (как клик по иконке в доке)
        if let url = appURL {
            NSWorkspace.shared.open(url)
        }
        app.activate(options: [.activateIgnoringOtherApps])
        runReopenAppleScript()
        unminimizeWindowViaAppleScript()
    }

    /// Команда reopen — то же, что при клике по иконке приложения в доке (часто восстанавливает окно у Electron-приложений)
    private static func runReopenAppleScript() {
        guard let url = appURL else { return }
        let pathEscaped = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "tell application (POSIX file \"\(pathEscaped)\") to reopen")?.executeAndReturnError(&error)
    }

    /// Снять минимизацию главного окна (работает, когда окно свёрнуто в док). Пробуем reopen уже выше; здесь — явно по окну.
    private static func unminimizeWindowViaAppleScript() {
        guard let url = appURL else { return }
        let pathEscaped = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        // 1) Стандартный способ: set miniaturized of window 1 to false
        var error: NSDictionary?
        NSAppleScript(source: "tell application (POSIX file \"\(pathEscaped)\") to set miniaturized of window 1 to false")?.executeAndReturnError(&error)
        if error == nil { return }
        // 2) Через System Events снимаем AXMinimized у первого окна (нужны права «Универсальный доступ»)
        let processName = runningApplication?.localizedName ?? "Yandex Music"
        let escapedName = processName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script2 = """
            tell application "System Events" to tell process "\(escapedName)"
                set frontmost to true
                if (count of windows) > 0 then
                    set value of attribute "AXMinimized" of window 1 to false
                end if
            end tell
            """
        error = nil
        NSAppleScript(source: script2)?.executeAndReturnError(&error)
    }

    /// Скрыть окно приложения (команда Hide)
    static func hideWindow() {
        guard runningApplication != nil, let url = appURL else { return }
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application (POSIX file \"\(path)\") to hide"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    /// Переключить видимость окна: если видно - скрыть, иначе показать
    static func toggleWindow() {
        guard let app = runningApplication else {
            launch()
            return
        }
        // Простая эвристика: активируем и смотрим, стало ли окно активным (уже было на переднем плане - считаем "видимым")
        let wasActive = app.isActive
        if wasActive {
            hideWindow()
        } else {
            showWindow()
        }
    }
}

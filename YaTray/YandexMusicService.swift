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

    /// Показать окно приложения (активировать и вывести на передний план)
    static func showWindow() {
        guard let app = runningApplication else {
            launch()
            return
        }
        app.activate(options: [])
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

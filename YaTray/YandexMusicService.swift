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

    /// Переменные окружения от Xcode/Debug, которые нельзя передавать запускаемому приложению
    private static let envKeysToStrip = [
        "DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH",
        "__XCODE_BUILT_PRODUCTS_DIR_PATHS", "XCODE_PRODUCT_BUILD_VERSION",
        "IDEPackageSupport", "XPC_SERVICE_NAME", "__CF_USER_TEXT_ENCODING"
    ]

    /// Запустить приложение (если ещё не запущено). Окружение очищается от переменных Xcode,
    /// чтобы не передавать в Яндекс Музыку __preview.dylib и не вызывать краш.
    static func launch() {
        guard let url = appURL else { return }
        guard !isRunning else {
            showWindow()
            return
        }
        var env = ProcessInfo.processInfo.environment
        for key in envKeysToStrip {
            env.removeValue(forKey: key)
        }
        // Убираем любые DYLD_* и пути в DerivedData
        env = env.filter { name, value in
            if name.hasPrefix("DYLD_") { return false }
            if value.contains("DerivedData") || value.contains("__preview") { return false }
            return true
        }
        var config = NSWorkspace.OpenConfiguration()
        config.environment = env
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

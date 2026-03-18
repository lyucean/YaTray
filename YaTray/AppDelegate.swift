//
//  AppDelegate.swift
//  YaTray
//
//  Инициализация меню-бара и перехватчика медиа-клавиш при старте приложения.
//  Разрешается только один экземпляр приложения.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    var mediaKeyMonitor: MediaKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Один экземпляр: если уже запущен другой - активируем его и выходим
        if !activateExistingInstanceIfNeeded() {
            return
        }

        statusBarController = StatusBarController()
        statusBarController?.setup()

        mediaKeyMonitor = MediaKeyMonitor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.mediaKeyMonitor?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyMonitor?.stop()
    }

    /// Возвращает false, если запущен другой экземпляр и мы завершаемся (активировав его).
    private func activateExistingInstanceIfNeeded() -> Bool {
        guard let myId = Bundle.main.bundleIdentifier else { return true }
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == myId && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        guard let existing = others.first else { return true }
        existing.activate(options: [])
        NSApplication.shared.terminate(nil)
        return false
    }
}

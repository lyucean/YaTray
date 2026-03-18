//
//  AppDelegate.swift
//  YaTray
//
//  Инициализация меню-бара и перехватчика медиа-клавиш при старте приложения.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    var mediaKeyMonitor: MediaKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
}

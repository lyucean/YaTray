//
//  YaTrayApp.swift
//  YaTray
//
//  Приложение только в меню-баре (без окна и без иконки в Dock).
//

import SwiftUI

@main
struct YaTrayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Окно не показываем - приложение живёт в трее
        Settings {
            EmptyView()
        }
    }
}

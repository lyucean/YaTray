//
//  StatusBarController.swift
//  YaTray
//
//  Иконка в меню-баре (жёлтый кружок), клик - показать/скрыть окно, меню - пункты управления.
//

import AppKit
import Combine
import ServiceManagement
import SwiftUI

final class StatusBarController: NSObject, ObservableObject {

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var autostartItem: NSMenuItem?
    private let statusBar = NSStatusBar.system

    /// Включён ли автозапуск (синхронизируется с SMAppService)
    @Published var isAutostartEnabled: Bool {
        didSet {
            setLoginItem(enabled: isAutostartEnabled)
            autostartItem?.state = isAutostartEnabled ? .on : .off
        }
    }

    override init() {
        self.isAutostartEnabled = Self.getLoginItemStatus()
        super.init()
    }

    func setup() {
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        // Жёлтый кружок как иконка
        button.image = makeYellowCircleImage()
        button.image?.isTemplate = false
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self

        buildMenu()
        // Меню показываем по правому клику; по левому - toggle
        statusItem?.menu = nil
    }

    private func buildMenu() {
        let m = NSMenu()

        let launchItem = NSMenuItem(
            title: "Запустить Яндекс Музыку",
            action: #selector(menuLaunchYandexMusic),
            keyEquivalent: ""
        )
        launchItem.target = self
        m.addItem(launchItem)

        let autostart = NSMenuItem(
            title: "Автозапуск",
            action: #selector(menuToggleAutostart),
            keyEquivalent: ""
        )
        autostart.target = self
        autostart.state = isAutostartEnabled ? .on : .off
        self.autostartItem = autostart
        m.addItem(autostart)

        m.addItem(NSMenuItem.separator())

        let projectPageItem = NSMenuItem(
            title: "Страница проекта",
            action: #selector(menuOpenProjectPage),
            keyEquivalent: ""
        )
        projectPageItem.target = self
        m.addItem(projectPageItem)

        m.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Выйти", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        self.menu = m
    }

    private func makeYellowCircleImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemYellow.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton?) {
        guard let event = NSApp.currentEvent else { return }
        let isRight = event.type == .rightMouseUp || event.buttonNumber == 2
        if isRight {
            showMenu()
        } else {
            YandexMusicService.toggleWindow()
        }
    }

    private func showMenu() {
        guard let menu = menu else { return }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func menuLaunchYandexMusic() {
        YandexMusicService.launch()
    }

    @objc private func menuToggleAutostart() {
        isAutostartEnabled.toggle()
    }

    @objc private func menuOpenProjectPage() {
        guard let url = URL(string: "https://github.com/lyucean/YaTray") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Login Item (автозапуск)

    private static func getLoginItemStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }
}

//
//  MediaKeyMonitor.swift
//  YaTray
//
//  Глобальный перехват медиа-клавиши Play: если Яндекс Музыка не запущена - запускаем её и подавляем событие.
//  Требуется разрешение «Управление компьютером» (Accessibility) в Системных настройках.
//

import AppKit
import Carbon.HIToolbox
import os.log

/// Код медиа-клавиши Play в системных событиях (NX_KEYTYPE_PLAY)
private let kPlayKeyCode: Int64 = 16

/// Raw value для NX_SYSDEFINED (медиа-клавиши приходят таким типом)
private let NX_SYSDEFINED: Int32 = 14

private let log = Logger(subsystem: "Lyucean.YaTray", category: "MediaKey")

final class MediaKeyMonitor {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    func start() {
        guard !isRunning else {
            log.debug("MediaKeyMonitor уже запущен")
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            log.error("Нет доступа Accessibility - перехват медиа-клавиш не будет работать")
            return
        }
        log.info("Accessibility: доступ есть, создаём event tap")

        let eventMask = CGEventMask(1 << NX_SYSDEFINED)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if monitor.handle(event) {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = tap else {
            log.error("CGEvent.tapCreate вернул nil - перехват недоступен")
            return
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        log.info("MediaKeyMonitor: tap создан и включён, ждём события типа NX_SYSDEFINED")
    }

    func stop() {
        guard isRunning, let tap = tap, let runLoopSource = runLoopSource else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.tap = nil
        self.runLoopSource = nil
        isRunning = false
    }

    private func handle(_ cgEvent: CGEvent) -> Bool {
        let type = cgEvent.type.rawValue
        guard type == NX_SYSDEFINED else { return false }

        // Код и флаги медиа-клавиш лежат в data1 NSEvent; из CGEvent их корректно даёт только NSEvent(cgEvent:).
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return false }
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let keyFlags = data1 & 0x0000_FFFF
        let keyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A

        guard keyCode == Int(kPlayKeyCode), keyDown else { return false }

        DispatchQueue.main.async {
            if YandexMusicService.isRunning {
                // Уже запущена — выводим на передний план, чтобы не отдавать Play в iTunes
                YandexMusicService.showWindow()
            } else {
                YandexMusicService.launch()
            }
        }
        return true
    }
}

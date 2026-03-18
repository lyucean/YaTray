//
//  MediaKeyMonitor.swift
//  YaTray
//
//  Глобальный перехват медиа-клавиши Play: если Яндекс Музыка не запущена - запускаем её и подавляем событие.
//  Требуется разрешение «Управление компьютером» (Accessibility) в Системных настройках.
//

import AppKit
import Carbon.HIToolbox

/// Код медиа-клавиши Play в системных событиях (NX_KEYTYPE_PLAY)
private let kPlayKeyCode: Int64 = 16

/// Raw value для NX_SYSDEFINED (медиа-клавиши приходят таким типом)
private let NX_SYSDEFINED: Int32 = 14

final class MediaKeyMonitor {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }

        let eventMask = CGEventMask(1 << NX_SYSDEFINED)
        guard let tap = CGEvent.tapCreate(
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
        ) else { return }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
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
        guard cgEvent.type.rawValue == NX_SYSDEFINED else { return false }

        // В системных событиях медиа-клавиш код в keyboardEventKeycode
        let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == kPlayKeyCode else { return false }
        guard !YandexMusicService.isRunning else { return false }

        DispatchQueue.main.async {
            YandexMusicService.launch()
        }
        return true
    }
}

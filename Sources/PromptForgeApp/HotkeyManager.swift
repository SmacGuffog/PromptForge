#if os(macOS)
import Foundation
import Carbon.HIToolbox
import PromptForgeCore

/// Registers a system-wide hotkey with Carbon and fires a callback when it is
/// pressed.
///
/// Carbon's `RegisterEventHotKey` works without Accessibility permission, which
/// keeps the summon-the-capture-window loop friction-free. The callback runs on
/// the main run loop.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onFire: () -> Void

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    deinit {
        unregister()
    }

    /// Register the given hotkey, replacing any previous registration. A key
    /// name that is not recognised is ignored (no hotkey registered).
    func register(_ hotkey: Hotkey) {
        unregister()
        guard let keyCode = Self.keyCode(for: hotkey.key) else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onFire()
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x50464B31), id: 1) // "PFK1"
        RegisterEventHotKey(
            UInt32(keyCode),
            Self.carbonModifiers(hotkey.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    /// Remove the current registration, if any.
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    // MARK: Mapping

    static func carbonModifiers(_ modifiers: [Hotkey.Modifier]) -> UInt32 {
        var flags: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command: flags |= UInt32(cmdKey)
            case .option: flags |= UInt32(optionKey)
            case .control: flags |= UInt32(controlKey)
            case .shift: flags |= UInt32(shiftKey)
            }
        }
        return flags
    }

    /// Map a logical key name to a virtual key code. Covers space and the
    /// letters, which is enough for v1 defaults.
    static func keyCode(for key: String) -> Int? {
        switch key.lowercased() {
        case "space": return kVK_Space
        case "return": return kVK_Return
        case "a": return kVK_ANSI_A
        case "b": return kVK_ANSI_B
        case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D
        case "e": return kVK_ANSI_E
        case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G
        case "h": return kVK_ANSI_H
        case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J
        case "k": return kVK_ANSI_K
        case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M
        case "n": return kVK_ANSI_N
        case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P
        case "q": return kVK_ANSI_Q
        case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S
        case "t": return kVK_ANSI_T
        case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V
        case "w": return kVK_ANSI_W
        case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y
        case "z": return kVK_ANSI_Z
        default: return nil
        }
    }
}
#endif

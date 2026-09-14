public struct KeyModifiers: OptionSet, Sendable, Equatable, Codable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)

    public var label: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    public static func from(control: Bool, option: Bool, shift: Bool, command: Bool) -> KeyModifiers {
        var mods: KeyModifiers = []
        if control { mods.insert(.control) }
        if option { mods.insert(.option) }
        if shift { mods.insert(.shift) }
        if command { mods.insert(.command) }
        return mods
    }
}

public struct Hotkey: Equatable, Sendable, Codable {
    public var keyCode: UInt16?
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16? = nil, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let standard = Hotkey(keyCode: nil, modifiers: [.control, .option])
    public static let rightCommand = Hotkey(keyCode: 54, modifiers: [])

    public var isModifierOnly: Bool { keyCode == nil }

    public var label: String {
        if keyCode == 54 { return "Right ⌘" }
        let mods = modifiers.label
        guard let keyCode else { return mods.isEmpty ? "Hotkey" : mods }
        return mods + Hotkey.keyName(keyCode)
    }

    public static func isModifierKey(_ code: UInt16) -> Bool {
        switch code {
        case 54, 55, 56, 58, 59, 60, 61, 62:
            return true
        default:
            return false
        }
    }

    public static func keyName(_ code: UInt16) -> String {
        switch code {
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "Esc"
        default:
            let letters: [UInt16: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
                8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
                16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
                38: "J", 40: "K", 45: "N", 46: "M",
            ]
            return letters[code] ?? "Key"
        }
    }
}

public struct HotkeyTapper: Sendable {
    public var hotkey: Hotkey
    private var pending = false
    private var chorded = false

    public init(hotkey: Hotkey = .standard) {
        self.hotkey = hotkey
    }

    public mutating func handle(_ event: KeyEvent, modifiers: KeyModifiers? = nil) -> Bool {
        if case .down(let code, let isRepeat) = event {
            if isRepeat { return false }
            if let modifiers, hotkey.keyCode == code, code != 54, modifiers != hotkey.modifiers { return false }
        }
        if hotkey.isModifierOnly {
            if case .down(let code, _) = event, pending, !Hotkey.isModifierKey(code) {
                chorded = true
            }
            return false
        }
        guard let target = hotkey.keyCode else { return false }
        switch event {
        case .down(let code, _):
            if code == target {
                pending = true
                chorded = false
                return false
            }
            if pending { chorded = true }
            return false
        case .up(let code):
            let fired = code == target && pending && !chorded
            pending = false
            chorded = false
            return fired
        }
    }

    public mutating func handleFlags(code: UInt16, modifiers: KeyModifiers) -> Bool {
        if hotkey.isModifierOnly {
            if modifiers == hotkey.modifiers {
                if pending { return false }
                pending = true
                chorded = false
                return true
            }
            pending = false
            chorded = false
            return false
        }
        if let target = hotkey.keyCode, code == target {
            if target == 54 {
                return handle(modifiers.contains(.command) ? .down(code: target, isRepeat: false) : .up(code: target))
            }
            let down = modifiers.isSuperset(of: hotkey.modifiers)
            return handle(down ? .down(code: target, isRepeat: false) : .up(code: target))
        }
        return false
    }

    public func shouldConsume(code: UInt16, modifiers: KeyModifiers) -> Bool {
        if hotkey.isModifierOnly {
            return pending || modifiers == hotkey.modifiers
        }
        return code == hotkey.keyCode
    }
}

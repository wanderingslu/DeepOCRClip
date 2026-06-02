import Carbon
import Foundation

enum HotKeyAction: UInt32 {
    case capture = 1
    case showLastResult = 2
}

struct HotKeySetting: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyName: String

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyName.uppercased())
        return parts.joined()
    }

    var hasValidModifier: Bool {
        modifiers & UInt32(cmdKey | controlKey | optionKey | shiftKey) != 0
    }

    static let defaultCapture = HotKeySetting(
        keyCode: KeyCode.lookup["C"] ?? 8,
        modifiers: UInt32(optionKey | shiftKey),
        keyName: "C"
    )

    static let defaultShowLastResult = HotKeySetting(
        keyCode: KeyCode.lookup["L"] ?? 37,
        modifiers: UInt32(optionKey | shiftKey),
        keyName: "L"
    )
}

enum KeyCode {
    static let names = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
    ]

    static let lookup: [String: UInt32] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
        "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
        "Y": 16, "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "0": 29, "O": 31, "U": 32, "I": 34, "P": 35, "L": 37,
        "J": 38, "K": 40, "N": 45, "M": 46, "7": 26, "8": 28, "9": 25
    ]
}

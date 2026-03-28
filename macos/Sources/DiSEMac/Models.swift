import Foundation

enum DiSEProtocol {
    static let vendorID = 1155
    static let productID = 22334
    static let usagePage = 0xFFA0
    static let usage = 1
    static let macOSUsagePages = [usagePage, Int(UInt16(usagePage).byteSwapped)]
    static let reportSize = 64
    static let keyCount = 49
    static let jogModeCount = 6
    static let jogRateCount = 3
    static let keyLabelLength = 24
}

enum HIDMessage: Int {
    case setKey = 0x01
    case getKey = 0x02
    case saveSettings = 0x03
    case setJogData = 0x04
    case getJogData = 0x05
    case setJogType = 0x06
    case getJogType = 0x07
    case factoryDefault = 0x08
    case getVersion = 0x09
    case setKeyLabel = 0x0A
    case getKeyLabel = 0x0B

    case keyData = 0x41
    case keyActions = 0x42
    case saveResult = 0x43
    case jogData = 0x44
    case jogType = 0x45
    case version = 0x46
    case keyLabel = 0x47
}

enum AlternateType: Int, CaseIterable, Identifiable {
    case none = 0
    case toggle = 1
    case longPress = 2
    case keyUp = 3
    case doubleClick = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .toggle:
            return "Toggle"
        case .longPress:
            return "Long Press"
        case .keyUp:
            return "On Key Up"
        case .doubleClick:
            return "Double Click"
        }
    }
}

enum JogDirection: Int, CaseIterable, Identifiable {
    case right = 0
    case left = 1

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .right:
            return "R"
        case .left:
            return "L"
        }
    }

    var title: String {
        switch self {
        case .right:
            return "Right"
        case .left:
            return "Left"
        }
    }
}

enum JogSelectionKind: Int, CaseIterable, Identifiable {
    case none = 0
    case select = 1
    case temporary = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .select:
            return "Jog Select"
        case .temporary:
            return "Jog Temp Select"
        }
    }
}

enum InspectorSelection: Hashable {
    case key(Int)
    case jog(mode: Int, rate: Int, direction: JogDirection)

    var title: String {
        switch self {
        case .key(let keyID):
            return "Key \(keyID)"
        case .jog(let mode, let rate, let direction):
            return "\(direction.title) Jog J\(mode + 1) L\(rate + 1)"
        }
    }
}

struct KeyAssignment: Identifiable, Equatable {
    var keyID: Int
    var code: Int
    var modifiers: Int
    var group: Int
    var alternateType: Int
    var alternateCode: Int
    var alternateModifiers: Int
    var jogSelection: Int
    var displayLabel: String = ""

    var id: Int { keyID }

    var customDisplayLabel: String? {
        let trimmed = displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func empty(keyID: Int) -> KeyAssignment {
        KeyAssignment(
            keyID: keyID,
            code: 0,
            modifiers: 0,
            group: 0,
            alternateType: 0,
            alternateCode: 0,
            alternateModifiers: 0,
            jogSelection: 0,
            displayLabel: ""
        )
    }
}

struct JogAssignment: Identifiable, Equatable {
    var mode: Int
    var rateSelect: Int
    var direction: JogDirection
    var code: Int
    var modifiers: Int
    var rate1: Int
    var rate2: Int

    var id: String {
        "\(mode)-\(rateSelect)-\(direction.rawValue)"
    }

    static func empty(mode: Int, rateSelect: Int, direction: JogDirection) -> JogAssignment {
        JogAssignment(
            mode: mode,
            rateSelect: rateSelect,
            direction: direction,
            code: 0,
            modifiers: 0,
            rate1: 0,
            rate2: 0
        )
    }
}

struct DeviceConfiguration: Equatable {
    var keys: [KeyAssignment]
    var jogs: [JogAssignment]
    var jogTypes: [Bool]

    static let empty: DeviceConfiguration = {
        let keys = (1...DiSEProtocol.keyCount).map { KeyAssignment.empty(keyID: $0) }
        var jogs: [JogAssignment] = []
        for mode in 0..<DiSEProtocol.jogModeCount {
            for rateSelect in 0..<DiSEProtocol.jogRateCount {
                jogs.append(.empty(mode: mode, rateSelect: rateSelect, direction: .right))
                jogs.append(.empty(mode: mode, rateSelect: rateSelect, direction: .left))
            }
        }
        return DeviceConfiguration(keys: keys, jogs: jogs, jogTypes: Array(repeating: false, count: DiSEProtocol.jogModeCount))
    }()

    func key(for keyID: Int) -> KeyAssignment {
        keys[keyID - 1]
    }

    func jog(mode: Int, rateSelect: Int, direction: JogDirection) -> JogAssignment {
        jogs[jogIndex(mode: mode, rateSelect: rateSelect, direction: direction)]
    }

    mutating func update(_ assignment: KeyAssignment) {
        guard assignment.keyID >= 1 && assignment.keyID <= keys.count else { return }
        keys[assignment.keyID - 1] = assignment
    }

    mutating func update(_ assignment: JogAssignment) {
        jogs[jogIndex(mode: assignment.mode, rateSelect: assignment.rateSelect, direction: assignment.direction)] = assignment
    }

    mutating func setJogType(mode: Int, isShuttle: Bool) {
        guard mode >= 0 && mode < jogTypes.count else { return }
        jogTypes[mode] = isShuttle
    }
}

func jogIndex(mode: Int, rateSelect: Int, direction: JogDirection) -> Int {
    (mode * DiSEProtocol.jogRateCount + rateSelect) * 2 + direction.rawValue
}

struct KeyCatalogEntry: Hashable, Identifiable {
    let name: String
    let hidCode: Int

    var id: Int { hidCode }
}

enum KeyCatalog {
    static let modifierNames = [
        "L-Ctrl",
        "L-Shift",
        "L-Alt",
        "L-Gui",
        "R-Ctrl",
        "R-Shift",
        "R-Alt",
        "R-Gui",
    ]

    static let entries: [KeyCatalogEntry] = keyMapText
        .split(whereSeparator: \.isNewline)
        .compactMap { line in
            let parts = line.split(separator: ",")
            guard parts.count >= 2, let hidCode = Int(parts[1]) else {
                return nil
            }
            return KeyCatalogEntry(name: String(parts[0]), hidCode: hidCode)
        }

    static let byName: [String: KeyCatalogEntry] = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
    static let byCode: [Int: KeyCatalogEntry] = Dictionary(uniqueKeysWithValues: entries.map { ($0.hidCode, $0) })

    static func name(for code: Int) -> String {
        byCode[code]?.name ?? (code == 0 ? "None" : "\(code)")
    }

    static func codeNameC(_ code: Int) -> String {
        guard code != 0 else {
            return "0"
        }
        guard let entry = byCode[code] else {
            return "\(code)"
        }
        if entry.name.hasPrefix("KP-") {
            return "KP_" + entry.name.dropFirst(3)
        }
        return "KEY_" + entry.name
    }

    static func parseCodeNameC(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved: String
        if trimmed.hasPrefix("KP_") {
            resolved = "KP-" + trimmed.dropFirst(3)
        } else if trimmed.hasPrefix("KEY_") {
            resolved = String(trimmed.dropFirst(4))
        } else {
            resolved = trimmed
        }
        if let entry = byName[resolved] {
            return entry.hidCode
        }
        return Int(resolved)
    }
}

func keyCombinationDescription(code: Int, modifiers: Int) -> String {
    var pieces: [String] = []
    for index in 0..<KeyCatalog.modifierNames.count where (modifiers & (1 << index)) != 0 {
        pieces.append(KeyCatalog.modifierNames[index])
    }
    if code != 0 {
        pieces.append(KeyCatalog.name(for: code))
    }
    return pieces.joined(separator: " + ")
}

func jogSelectionDescription(_ jogSelection: Int) -> String {
    guard jogSelection != 0 else {
        return "None"
    }
    let isTemporary = (jogSelection & 0x10) != 0
    let mode = jogSelection & 0x0F
    let prefix = isTemporary ? "Jog Temp" : "Jog"
    return "\(prefix) J\(mode)"
}

func keyAssignmentSummary(_ assignment: KeyAssignment) -> String {
    var parts: [String] = []
    let primary = keyCombinationDescription(code: assignment.code, modifiers: assignment.modifiers)
    if !primary.isEmpty {
        parts.append(primary)
    }
    if assignment.alternateType != 0 && assignment.alternateCode != 0 {
        let alternate = keyCombinationDescription(code: assignment.alternateCode, modifiers: assignment.alternateModifiers)
        if !alternate.isEmpty {
            let altName = AlternateType(rawValue: assignment.alternateType)?.title ?? "Alt"
            parts.append("\(altName): \(alternate)")
        }
    }
    if assignment.jogSelection != 0 {
        parts.append(jogSelectionDescription(assignment.jogSelection))
    }
    return parts.isEmpty ? "Unassigned" : parts.joined(separator: " / ")
}

func jogAssignmentSummary(_ assignment: JogAssignment, isShuttle: Bool) -> String {
    let keyPart = keyCombinationDescription(code: assignment.code, modifiers: assignment.modifiers)
    guard !keyPart.isEmpty else {
        return "Unassigned"
    }
    if isShuttle {
        return "\(keyPart) / \(assignment.rate1)-\(assignment.rate2) cps"
    }
    return "\(keyPart) / T\(assignment.rate1) A\(assignment.rate2)"
}

private let keyMapText = """
None,0,0
A,4,44
B,5,45
C,6,46
D,7,47
E,8,48
F,9,49
G,10,50
H,11,51
I,12,52
J,13,53
K,14,54
L,15,55
M,16,56
N,17,57
O,18,58
P,19,59
Q,20,60
R,21,61
S,22,62
T,23,63
U,24,64
V,25,65
W,26,66
X,27,67
Y,28,68
Z,29,69
1,30,35
2,31,36
3,32,37
4,33,38
5,34,39
6,35,40
7,36,41
8,37,42
9,38,43
0,39,34
Escape,41,13
Backspace,42,2
Tab,43,3
Space,44,18
Minus,45,143
Equals,46,141
LeftBracket,47,149
RightBracket,48,151
Backslash,49,150
Semicolon,51,140
Quote,52,152
Grave,53,146
Comma,54,142
Period,55,144
Slash,56,145
CapsLock,57,8
F1,58,90
F2,59,91
F3,60,92
F4,61,93
F5,62,94
F6,63,95
F7,64,96
F8,65,97
F9,66,98
F10,67,99
F11,68,100
F12,69,101
PrintScreen,70,0
ScrollLock,71,115
Pause,72,7
Insert,73,31
Home,74,22
PageUp,75,19
Delete,76,32
End,77,21
PageDown,78,20
Right,79,25
Left,80,23
Down,81,26
Up,82,24
KP-NumLock,83,114
KP-Divide,84,89
KP-Multiply,85,84
KP-Subtract,86,87
KP-Add,87,85
KP-Enter,88,0
KP-1,89,75
KP-2,90,76
KP-3,91,77
KP-4,92,78
KP-5,93,79
KP-6,94,80
KP-7,95,81
KP-8,96,82
KP-9,97,83
KP-0,98,74
KP-Point,99,88
NonUSBackslash,100,154
KP-Equals,103,0
F13,104,102
F14,105,103
F15,106,104
F16,107,105
F17,108,106
F18,109,107
F19,110,108
F20,111,109
F21,112,110
F22,113,111
F23,114,112
F24,115,113
Help,117,0
Menu,118,0
Mute,127,0
SysReq,154,0
Return,158,6
KP-Clear,216,0
KP-Decimal,220,0
LeftControl,224,118
LeftShift,225,116
LeftAlt,226,120
LeftGUI,227,70
RightControl,228,119
RightShift,229,117
RightAlt,230,121
RightGUI,231,72
"""

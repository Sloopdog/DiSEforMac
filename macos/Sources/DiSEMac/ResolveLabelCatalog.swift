import Foundation

struct KeyActionSignature: Hashable {
    let code: Int
    let modifiers: Int
    let alternateType: Int
    let alternateCode: Int
    let alternateModifiers: Int
    let jogSelection: Int

    init(_ assignment: KeyAssignment) {
        code = assignment.code
        modifiers = assignment.modifiers
        alternateType = assignment.alternateType
        alternateCode = assignment.alternateCode
        alternateModifiers = assignment.alternateModifiers
        jogSelection = assignment.jogSelection
    }

    init(code: Int, modifiers: Int, alternateType: Int = 0, alternateCode: Int = 0, alternateModifiers: Int = 0, jogSelection: Int = 0) {
        self.code = code
        self.modifiers = modifiers
        self.alternateType = alternateType
        self.alternateCode = alternateCode
        self.alternateModifiers = alternateModifiers
        self.jogSelection = jogSelection
    }

    var isEmpty: Bool {
        code == 0 && alternateCode == 0 && jogSelection == 0
    }
}

struct JogActionSignature: Hashable {
    let code: Int
    let modifiers: Int
    let rate1: Int
    let rate2: Int
    let isShuttle: Bool

    init(_ assignment: JogAssignment, isShuttle: Bool) {
        code = assignment.code
        modifiers = assignment.modifiers
        rate1 = assignment.rate1
        rate2 = assignment.rate2
        self.isShuttle = isShuttle
    }
}

enum ResolveLabelCatalog {
    private static let surfaceKeyLabels: [Int: String] = [
        1: "Smart Insert",
        2: "Close Up",
        3: "In",
        4: "Trim In",
        5: "Slip Src",
        6: "Cut",
        8: "Append",
        9: "Place On Top",
        11: "Trim Out",
        12: "Slip Dst",
        13: "Dissolve",
        15: "Ripple O/W",
        16: "Source O/W",
        17: "Out",
        18: "Roll",
        19: "Trans Dur",
        20: "Smooth Cut",
        22: "Esc",
        23: "Trans",
        24: "Cam 7",
        25: "Cam 4",
        26: "Cam 1",
        27: "Stop/Play",
        29: "Sync Bin",
        30: "Split",
        31: "Cam 8",
        32: "Cam 5",
        33: "Cam 2",
        34: "Source",
        35: "Shuttle",
        36: "Audio Level",
        37: "Snap",
        38: "Cam 9",
        39: "Cam 6",
        40: "Cam 3",
        41: "Timeline",
        42: "Jog",
        43: "Full View",
        44: "Ripple Del",
        45: "Live O/W",
        46: "Audio Only",
        47: "Video Only",
        48: "Custom",
        49: "Scroll",
    ]

    private static let knownKeyLabelsBySignature: [KeyActionSignature: String] = {
        var labels: [KeyActionSignature: String] = [:]

        let original = BuiltInProfiles.originalConfiguration()
        for (keyID, label) in surfaceKeyLabels {
            let signature = KeyActionSignature(original.key(for: keyID))
            if !signature.isEmpty {
                labels[signature] = label
            }
        }

        let wishlist = BuiltInProfiles.powerUserWishlistConfiguration()
        let wishlistLabels: [Int: String] = [
            6: "Undo",
            19: "Marker",
            20: "Blade",
            22: "Copy",
            23: "Paste",
            43: "Cut",
            45: "Delete",
            48: "Select All",
        ]

        for (keyID, label) in wishlistLabels {
            labels[KeyActionSignature(wishlist.key(for: keyID))] = label
        }

        return labels
    }()

    private static let commonShortcutLabelsBySignature: [KeyActionSignature: String] = [
        .init(code: 44, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Stop/Play",
        .init(code: 42, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Ripple Del",
        .init(code: 41, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Esc",
        .init(code: 22, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Save",
        .init(code: 29, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Undo",
        .init(code: 29, modifiers: 10, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Redo",
        .init(code: 6, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Copy",
        .init(code: 25, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Paste",
        .init(code: 27, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Cut",
        .init(code: 4, modifiers: 8, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Select All",
        .init(code: 5, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Blade",
        .init(code: 16, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Marker",
        .init(code: 17, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Snapping",
        .init(code: 76, modifiers: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0): "Delete",
    ]

    private static let knownJogLabelsBySignature: [JogActionSignature: String] = {
        let configuration = BuiltInProfiles.powerUserWishlistConfiguration()
        return [
            JogActionSignature(configuration.jog(mode: 2, rateSelect: 0, direction: .right), isShuttle: false): "Zoom In",
            JogActionSignature(configuration.jog(mode: 2, rateSelect: 0, direction: .left), isShuttle: false): "Zoom Out",
            JogActionSignature(configuration.jog(mode: 2, rateSelect: 1, direction: .right), isShuttle: false): "Zoom In",
            JogActionSignature(configuration.jog(mode: 2, rateSelect: 1, direction: .left), isShuttle: false): "Zoom Out",
            JogActionSignature(configuration.jog(mode: 3, rateSelect: 0, direction: .right), isShuttle: false): "Nudge Right",
            JogActionSignature(configuration.jog(mode: 3, rateSelect: 0, direction: .left), isShuttle: false): "Nudge Left",
            JogActionSignature(configuration.jog(mode: 3, rateSelect: 1, direction: .right), isShuttle: false): "Nudge Right",
            JogActionSignature(configuration.jog(mode: 3, rateSelect: 1, direction: .left), isShuttle: false): "Nudge Left",
        ]
    }()

    static func keyLabel(for keyID: Int, assignment: KeyAssignment) -> String? {
        let signature = KeyActionSignature(assignment)
        _ = keyID

        if let label = knownKeyLabelsBySignature[signature] {
            return label
        }

        if let label = commonShortcutLabelsBySignature[signature] {
            return label
        }

        return nil
    }

    static func jogLabel(for assignment: JogAssignment, isShuttle: Bool) -> String? {
        knownJogLabelsBySignature[JogActionSignature(assignment, isShuttle: isShuttle)]
    }
}

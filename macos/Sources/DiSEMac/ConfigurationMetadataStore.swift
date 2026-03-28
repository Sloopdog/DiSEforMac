import CryptoKit
import Foundation

struct StoredConfigurationMetadata: Codable {
    var summary: String
    var programmedAt: Date?
    var keyLabels: [Int: String]?
}

enum ConfigurationMetadataStore {
    private static let defaultsKey = "com.shaise.dise.configurationMetadata"

    static func metadata(for configuration: DeviceConfiguration) -> StoredConfigurationMetadata? {
        loadStore()[fingerprint(for: configuration)]
    }

    static func summary(for configuration: DeviceConfiguration) -> String {
        autoSummary(for: configuration)
    }

    static func lastProgrammedText(for configuration: DeviceConfiguration) -> String {
        guard let programmedAt = metadata(for: configuration)?.programmedAt else {
            return "Never"
        }
        return dateFormatter.string(from: programmedAt)
    }

    @discardableResult
    static func recordProgrammed(_ configuration: DeviceConfiguration, programmedAt: Date = Date()) -> StoredConfigurationMetadata {
        let metadata = StoredConfigurationMetadata(
            summary: autoSummary(for: configuration),
            programmedAt: programmedAt,
            keyLabels: storedKeyLabels(from: configuration)
        )
        var store = loadStore()
        store[fingerprint(for: configuration)] = metadata
        saveStore(store)
        return metadata
    }

    static func syncLocalLabels(for configuration: DeviceConfiguration) {
        let fingerprint = fingerprint(for: configuration)
        let keyLabels = storedKeyLabels(from: configuration)
        let summary = autoSummary(for: configuration)
        var store = loadStore()

        if let existing = store[fingerprint] {
            store[fingerprint] = StoredConfigurationMetadata(
                summary: summary,
                programmedAt: existing.programmedAt,
                keyLabels: keyLabels.isEmpty ? existing.keyLabels : keyLabels
            )
            saveStore(store)
            return
        }

        guard !keyLabels.isEmpty else {
            return
        }

        store[fingerprint] = StoredConfigurationMetadata(
            summary: summary,
            programmedAt: nil,
            keyLabels: keyLabels
        )
        saveStore(store)
    }

    static func restoringLabels(in configuration: DeviceConfiguration) -> DeviceConfiguration {
        guard let storedLabels = metadata(for: configuration)?.keyLabels, !storedLabels.isEmpty else {
            return configuration
        }

        var hydrated = configuration
        hydrated.keys = hydrated.keys.map { assignment in
            guard assignment.customDisplayLabel == nil, let storedLabel = storedLabels[assignment.keyID] else {
                return assignment
            }

            var updated = assignment
            updated.displayLabel = storedLabel
            return updated
        }
        return hydrated
    }

    private static func loadStore() -> [String: StoredConfigurationMetadata] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: StoredConfigurationMetadata].self, from: data)) ?? [:]
    }

    private static func saveStore(_ store: [String: StoredConfigurationMetadata]) {
        guard let data = try? JSONEncoder().encode(store) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func fingerprint(for configuration: DeviceConfiguration) -> String {
        var components: [String] = []

        for assignment in configuration.keys {
            components.append([
                "K",
                "\(assignment.keyID)",
                "\(assignment.code)",
                "\(assignment.modifiers)",
                "\(assignment.group)",
                "\(assignment.alternateType)",
                "\(assignment.alternateCode)",
                "\(assignment.alternateModifiers)",
                "\(assignment.jogSelection)",
            ].joined(separator: ":"))
        }

        for assignment in configuration.jogs {
            components.append([
                "J",
                "\(assignment.mode)",
                "\(assignment.rateSelect)",
                "\(assignment.direction.rawValue)",
                "\(assignment.code)",
                "\(assignment.modifiers)",
                "\(assignment.rate1)",
                "\(assignment.rate2)",
            ].joined(separator: ":"))
        }

        for (mode, isShuttle) in configuration.jogTypes.enumerated() {
            components.append("T:\(mode):\(isShuttle ? 1 : 0)")
        }

        let digest = SHA256.hash(data: Data(components.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func autoSummary(for configuration: DeviceConfiguration) -> String {
        let labels = configuration.keys.compactMap { assignmentDisplayLabel($0) }
        let uniqueLabels = orderedUnique(labels)

        guard !uniqueLabels.isEmpty else {
            return "Blank Layout"
        }

        let topLabels = Array(uniqueLabels.prefix(3))
        var summary = topLabels.joined(separator: " / ")
        if uniqueLabels.count > topLabels.count {
            summary += " +\(uniqueLabels.count - topLabels.count)"
        }

        if summary.count > 54 {
            summary = String(summary.prefix(51)) + "..."
        }
        return summary
    }

    private static func storedKeyLabels(from configuration: DeviceConfiguration) -> [Int: String] {
        var labels: [Int: String] = [:]
        for assignment in configuration.keys {
            guard let label = assignment.customDisplayLabel else {
                continue
            }
            labels[assignment.keyID] = label
        }
        return labels
    }

    private static func assignmentDisplayLabel(_ assignment: KeyAssignment) -> String? {
        if let customLabel = assignment.customDisplayLabel {
            return customLabel
        }
        if let resolveLabel = ResolveLabelCatalog.keyLabel(for: assignment.keyID, assignment: assignment) {
            return resolveLabel
        }
        let fallback = compactAssignmentLabel(for: assignment)
        return fallback == "Unassigned" ? nil : fallback
    }

    private static func compactAssignmentLabel(for assignment: KeyAssignment) -> String {
        if assignment.code != 0 {
            return compactShortcutLabel(code: assignment.code, modifiers: assignment.modifiers)
        }
        if assignment.alternateType != AlternateType.none.rawValue, assignment.alternateCode != 0 {
            return "Alt " + compactShortcutLabel(code: assignment.alternateCode, modifiers: assignment.alternateModifiers)
        }
        if assignment.jogSelection != 0 {
            return jogSelectionDescription(assignment.jogSelection)
        }
        return "Unassigned"
    }

    private static func compactShortcutLabel(code: Int, modifiers: Int) -> String {
        guard code != 0 else {
            return "Unassigned"
        }

        var pieces: [String] = []
        for index in 0..<KeyCatalog.modifierNames.count where (modifiers & (1 << index)) != 0 {
            switch KeyCatalog.modifierNames[index] {
            case "L-Ctrl", "R-Ctrl":
                pieces.append("Ctrl")
            case "L-Shift", "R-Shift":
                pieces.append("Shift")
            case "L-Alt", "R-Alt":
                pieces.append("Alt")
            case "L-Gui", "R-Gui":
                pieces.append("Cmd")
            default:
                pieces.append(KeyCatalog.modifierNames[index])
            }
        }
        pieces.append(compactKeyName(for: code))
        return pieces.joined(separator: "+")
    }

    private static func compactKeyName(for code: Int) -> String {
        switch KeyCatalog.name(for: code) {
        case "Backslash":
            return "\\"
        case "ForwardSlash":
            return "/"
        case "LeftBracket":
            return "["
        case "RightBracket":
            return "]"
        case "Minus":
            return "-"
        case "Equals":
            return "="
        case "Quote":
            return "'"
        default:
            return KeyCatalog.name(for: code)
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                continue
            }
            result.append(value)
        }

        return result
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

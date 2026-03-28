import Foundation

struct ConfigurationProfile: Identifiable {
    enum Source {
        case builtIn
        case saved(URL)
    }

    let id: String
    let name: String
    let summary: String
    let source: Source
    let configuration: DeviceConfiguration

    var isBuiltIn: Bool {
        if case .builtIn = source {
            return true
        }
        return false
    }

    var fileURL: URL? {
        if case .saved(let url) = source {
            return url
        }
        return nil
    }
}

enum ProfileLibraryError: LocalizedError {
    case invalidName
    case cannotDeleteBuiltIn

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a profile name before saving."
        case .cannotDeleteBuiltIn:
            return "Built-in profiles cannot be deleted."
        }
    }
}

@MainActor
final class ProfileLibrary: ObservableObject {
    @Published private(set) var builtInProfiles: [ConfigurationProfile] = BuiltInProfiles.all
    @Published private(set) var savedProfiles: [ConfigurationProfile] = []

    init() {
        reload()
    }

    var allProfiles: [ConfigurationProfile] {
        builtInProfiles + savedProfiles
    }

    func profile(id: String) -> ConfigurationProfile? {
        allProfiles.first(where: { $0.id == id })
    }

    func savedProfile(named name: String) -> ConfigurationProfile? {
        savedProfiles.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func reload() {
        let fileManager = FileManager.default
        let directory = profilesDirectory

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            savedProfiles = urls
                .filter { $0.pathExtension.caseInsensitiveCompare("DiSE") == .orderedSame }
                .compactMap(loadSavedProfile(from:))
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            savedProfiles = []
            print("Failed to load saved profiles: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func saveProfile(named rawName: String, configuration: DeviceConfiguration) throws -> ConfigurationProfile {
        let name = sanitizedProfileName(rawName)
        guard !name.isEmpty else {
            throw ProfileLibraryError.invalidName
        }

        let destination = profilesDirectory
            .appendingPathComponent(name, isDirectory: false)
            .appendingPathExtension("DiSE")
        let contents = SettingsFile.serialize(configuration)

        try FileManager.default.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        try contents.write(to: destination, atomically: true, encoding: .utf8)
        reload()

        return savedProfiles.first(where: {
            $0.fileURL?.standardizedFileURL == destination.standardizedFileURL
        }) ?? ConfigurationProfile(
            id: "saved:\(destination.path)",
            name: name,
            summary: "Saved profile",
            source: .saved(destination),
            configuration: configuration
        )
    }

    func deleteProfile(_ profile: ConfigurationProfile) throws {
        guard case .saved(let url) = profile.source else {
            throw ProfileLibraryError.cannotDeleteBuiltIn
        }

        try FileManager.default.removeItem(at: url)
        reload()
    }

    private func loadSavedProfile(from url: URL) -> ConfigurationProfile? {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let configuration = try SettingsFile.parse(contents: contents)
            let name = url.deletingPathExtension().lastPathComponent

            return ConfigurationProfile(
                id: "saved:\(url.path)",
                name: name,
                summary: "Saved from this Mac",
                source: .saved(url),
                configuration: configuration
            )
        } catch {
            print("Skipping saved profile \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private var profilesDirectory: URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseDirectory
            .appendingPathComponent("DiSE Programmer", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
    }

    private func sanitizedProfileName(_ rawName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\")
            .union(.newlines)
            .union(.controlCharacters)

        let cleanedScalars = rawName.unicodeScalars.map { scalar -> Character in
            invalidCharacters.contains(scalar) ? "-" : Character(scalar)
        }

        let cleaned = String(cleanedScalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "" : cleaned
    }
}

enum BuiltInProfiles {
    private static let command = 1 << 3
    private static let shift = 1 << 1
    private static let option = 1 << 2
    private static let commandShift = command | shift
    private static let optionShift = option | shift

    struct KeySeed {
        let code: Int
        let modifiers: Int
        let group: Int
        let alternateType: Int
        let alternateCode: Int
        let alternateModifiers: Int
        let jogSelection: Int
    }

    struct JogSeed {
        let code: Int
        let modifiers: Int
        let rate1: Int
        let rate2: Int
    }

    static let all: [ConfigurationProfile] = [
        ConfigurationProfile(
            id: "builtin:original",
            name: "Original Speed Editor",
            summary: "Exact DiSE factory layout, matching the firmware defaults as closely as possible.",
            source: .builtIn,
            configuration: originalConfiguration()
        ),
        ConfigurationProfile(
            id: "builtin:wishlist",
            name: "Power User Wishlist",
            summary: "Keeps the stock layout but fills spare keys with undo, redo, save, markers, clipboard tools, blade, snapping, and Mac-friendly zoom/nudge jog modes.",
            source: .builtIn,
            configuration: powerUserWishlistConfiguration()
        ),
    ]

    static func originalConfiguration() -> DeviceConfiguration {
        configuration(
            keys: [
                .init(code: 66, modifiers: 0, group: 51, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 52, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 12, modifiers: 0, group: 0, alternateType: 4, alternateCode: 12, alternateModifiers: 4, jogSelection: 0),
                .init(code: 28, modifiers: 2, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 20),
                .init(code: 10, modifiers: 1, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 20),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 33, modifiers: 1, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 69, modifiers: 2, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 69, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 24, modifiers: 2, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 20),
                .init(code: 11, modifiers: 1, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 20),
                .init(code: 10, modifiers: 2, group: 0, alternateType: 3, alternateCode: 23, alternateModifiers: 1, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 67, modifiers: 2, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 67, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 18, modifiers: 0, group: 0, alternateType: 4, alternateCode: 18, alternateModifiers: 4, jogSelection: 0),
                .init(code: 10, modifiers: 2, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 20),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 41, modifiers: 0, group: 0, alternateType: 4, alternateCode: 29, alternateModifiers: 1, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 36, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 33, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 30, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 44, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 22, modifiers: 6, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 49, modifiers: 1, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 37, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 34, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 31, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 32, modifiers: 1, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 50, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 1),
                .init(code: 25, modifiers: 2, group: 0, alternateType: 3, alternateCode: 4, alternateModifiers: 3, jogSelection: 21),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 22),
                .init(code: 38, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 35, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 32, modifiers: 0, group: 2, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 33, modifiers: 1, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 50, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 2),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 42, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 49, modifiers: 6, group: 3, alternateType: 1, alternateCode: 47, alternateModifiers: 6, jogSelection: 0),
                .init(code: 48, modifiers: 6, group: 3, alternateType: 1, alternateCode: 47, alternateModifiers: 6, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 0, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 0),
                .init(code: 0, modifiers: 0, group: 50, alternateType: 0, alternateCode: 0, alternateModifiers: 0, jogSelection: 3),
            ],
            jogs: [
                .init(code: 79, modifiers: 0, rate1: 5, rate2: 50),
                .init(code: 80, modifiers: 0, rate1: 5, rate2: 50),
                .init(code: 79, modifiers: 2, rate1: 2, rate2: 20),
                .init(code: 80, modifiers: 2, rate1: 2, rate2: 20),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 79, modifiers: 0, rate1: 20, rate2: 5),
                .init(code: 80, modifiers: 0, rate1: 20, rate2: 5),
                .init(code: 79, modifiers: 2, rate1: 255, rate2: 25),
                .init(code: 80, modifiers: 2, rate1: 255, rate2: 25),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 46, modifiers: 1, rate1: 255, rate2: 25),
                .init(code: 45, modifiers: 1, rate1: 255, rate2: 25),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 55, modifiers: 0, rate1: 20, rate2: 5),
                .init(code: 54, modifiers: 0, rate1: 20, rate2: 5),
                .init(code: 55, modifiers: 2, rate1: 255, rate2: 25),
                .init(code: 54, modifiers: 2, rate1: 255, rate2: 25),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 46, modifiers: 5, rate1: 20, rate2: 5),
                .init(code: 45, modifiers: 5, rate1: 20, rate2: 5),
                .init(code: 46, modifiers: 6, rate1: 255, rate2: 25),
                .init(code: 45, modifiers: 6, rate1: 255, rate2: 25),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 81, modifiers: 0, rate1: 255, rate2: 20),
                .init(code: 82, modifiers: 0, rate1: 255, rate2: 20),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
                .init(code: 0, modifiers: 0, rate1: 0, rate2: 0),
            ],
            jogTypes: [true, false, false, false, false, false]
        )
    }

    static func powerUserWishlistConfiguration() -> DeviceConfiguration {
        var configuration = originalConfiguration()

        applySimpleKey(to: &configuration, keyID: 6, name: "Z", modifiers: command)
        applySimpleKey(to: &configuration, keyID: 10, name: "Z", modifiers: commandShift)
        applySimpleKey(to: &configuration, keyID: 14, name: "S", modifiers: command)
        applySimpleKey(to: &configuration, keyID: 19, name: "M")
        applySimpleKey(to: &configuration, keyID: 20, name: "B")
        applySimpleKey(to: &configuration, keyID: 22, name: "C", modifiers: command)
        applySimpleKey(to: &configuration, keyID: 23, name: "V", modifiers: command)
        applySimpleKey(to: &configuration, keyID: 28, name: "N")
        applySimpleKey(to: &configuration, keyID: 43, name: "X", modifiers: command)
        applySimpleKey(to: &configuration, keyID: 45, name: "Delete")
        applySimpleKey(to: &configuration, keyID: 48, name: "A", modifiers: command)

        applyJog(to: &configuration, mode: 2, rate: 0, direction: .right, name: "Equals", modifiers: command, rate1: 16, rate2: 4)
        applyJog(to: &configuration, mode: 2, rate: 0, direction: .left, name: "Minus", modifiers: command, rate1: 16, rate2: 4)
        applyJog(to: &configuration, mode: 2, rate: 1, direction: .right, name: "Equals", modifiers: commandShift, rate1: 64, rate2: 8)
        applyJog(to: &configuration, mode: 2, rate: 1, direction: .left, name: "Minus", modifiers: commandShift, rate1: 64, rate2: 8)

        applyJog(to: &configuration, mode: 3, rate: 0, direction: .right, name: "Right", modifiers: option, rate1: 18, rate2: 5)
        applyJog(to: &configuration, mode: 3, rate: 0, direction: .left, name: "Left", modifiers: option, rate1: 18, rate2: 5)
        applyJog(to: &configuration, mode: 3, rate: 1, direction: .right, name: "Right", modifiers: optionShift, rate1: 72, rate2: 12)
        applyJog(to: &configuration, mode: 3, rate: 1, direction: .left, name: "Left", modifiers: optionShift, rate1: 72, rate2: 12)

        configuration.setJogType(mode: 2, isShuttle: false)
        configuration.setJogType(mode: 3, isShuttle: false)
        return configuration
    }

    private static func configuration(keys: [KeySeed], jogs: [JogSeed], jogTypes: [Bool]) -> DeviceConfiguration {
        var configuration = DeviceConfiguration.empty

        for (index, seed) in keys.enumerated() {
            configuration.update(
                KeyAssignment(
                    keyID: index + 1,
                    code: seed.code,
                    modifiers: seed.modifiers,
                    group: seed.group,
                    alternateType: seed.alternateType,
                    alternateCode: seed.alternateCode,
                    alternateModifiers: seed.alternateModifiers,
                    jogSelection: seed.jogSelection
                )
            )
        }

        for (index, seed) in jogs.enumerated() {
            let mode = index / (DiSEProtocol.jogRateCount * 2)
            let rate = (index / 2) % DiSEProtocol.jogRateCount
            let direction: JogDirection = index.isMultiple(of: 2) ? .right : .left

            configuration.update(
                JogAssignment(
                    mode: mode,
                    rateSelect: rate,
                    direction: direction,
                    code: seed.code,
                    modifiers: seed.modifiers,
                    rate1: seed.rate1,
                    rate2: seed.rate2
                )
            )
        }

        for mode in 0..<DiSEProtocol.jogModeCount {
            let isShuttle = mode < jogTypes.count ? jogTypes[mode] : false
            configuration.setJogType(mode: mode, isShuttle: isShuttle)
        }

        return configuration
    }

    private static func applySimpleKey(
        to configuration: inout DeviceConfiguration,
        keyID: Int,
        name: String,
        modifiers: Int = 0
    ) {
        var assignment = configuration.key(for: keyID)
        assignment.code = hidCode(name)
        assignment.modifiers = modifiers
        assignment.alternateType = 0
        assignment.alternateCode = 0
        assignment.alternateModifiers = 0
        assignment.jogSelection = 0
        configuration.update(assignment)
    }

    private static func applyJog(
        to configuration: inout DeviceConfiguration,
        mode: Int,
        rate: Int,
        direction: JogDirection,
        name: String,
        modifiers: Int = 0,
        rate1: Int,
        rate2: Int
    ) {
        var assignment = configuration.jog(mode: mode, rateSelect: rate, direction: direction)
        assignment.code = hidCode(name)
        assignment.modifiers = modifiers
        assignment.rate1 = rate1
        assignment.rate2 = rate2
        configuration.update(assignment)
    }

    private static func hidCode(_ name: String) -> Int {
        KeyCatalog.byName[name]?.hidCode ?? 0
    }
}

import Foundation

enum SettingsFileError: LocalizedError {
    case malformedLine(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .malformedLine(let line):
            return "Malformed settings line: \(line)"
        case .invalidValue(let line):
            return "Invalid settings value in line: \(line)"
        }
    }
}

enum SettingsFile {
    static func parse(contents: String) throws -> DeviceConfiguration {
        var configuration = DeviceConfiguration.empty

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let tokens = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard tokens.count == 2 else {
                throw SettingsFileError.malformedLine(line)
            }

            let name = tokens[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let values = tokens[1].split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            switch name {
            case "Key":
                guard values.count == 8 else {
                    throw SettingsFileError.malformedLine(line)
                }
                guard
                    let keyID = Int(values[0]),
                    let code = KeyCatalog.parseCodeNameC(values[1]),
                    let modifiers = Int(values[2]),
                    let group = Int(values[3]),
                    let altType = Int(values[4]),
                    let altCode = KeyCatalog.parseCodeNameC(values[5]),
                    let altModifiers = Int(values[6]),
                    let jogSelection = Int(values[7])
                else {
                    throw SettingsFileError.invalidValue(line)
                }
                configuration.update(
                    KeyAssignment(
                        keyID: keyID,
                        code: code,
                        modifiers: modifiers,
                        group: group,
                        alternateType: altType,
                        alternateCode: altCode,
                        alternateModifiers: altModifiers,
                        jogSelection: jogSelection
                    )
                )

            case "KeyLabel":
                let labelParts = tokens[1].split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard
                    labelParts.count == 2,
                    let keyID = Int(labelParts[0]),
                    (1...DiSEProtocol.keyCount).contains(keyID)
                else {
                    throw SettingsFileError.malformedLine(line)
                }
                var assignment = configuration.key(for: keyID)
                assignment.displayLabel = labelParts[1]
                configuration.update(assignment)

            case "JogData":
                guard values.count == 7 else {
                    throw SettingsFileError.malformedLine(line)
                }
                guard
                    let mode = Int(values[0]),
                    let rateSelect = Int(values[1]),
                    let directionRaw = Int(values[2]),
                    let direction = JogDirection(rawValue: directionRaw),
                    let code = KeyCatalog.parseCodeNameC(values[3]),
                    let modifiers = Int(values[4]),
                    let rate1 = Int(values[5]),
                    let rate2 = Int(values[6])
                else {
                    throw SettingsFileError.invalidValue(line)
                }
                configuration.update(
                    JogAssignment(
                        mode: mode,
                        rateSelect: rateSelect,
                        direction: direction,
                        code: code,
                        modifiers: modifiers,
                        rate1: rate1,
                        rate2: rate2
                    )
                )

            case "JogType":
                guard values.count == 2 else {
                    throw SettingsFileError.malformedLine(line)
                }
                guard
                    let mode = Int(values[0]),
                    let isShuttle = Int(values[1])
                else {
                    throw SettingsFileError.invalidValue(line)
                }
                configuration.setJogType(mode: mode, isShuttle: isShuttle != 0)

            default:
                throw SettingsFileError.malformedLine(line)
            }
        }

        return configuration
    }

    static func serialize(_ configuration: DeviceConfiguration) -> String {
        var lines: [String] = []

        lines.append("# key programming settings: Key=keyid, key_code, modifiers, group, alt_type, alt_key_code, alt_modifiers, jog_sel")
        for assignment in configuration.keys {
            lines.append(
                "Key=\(assignment.keyID),\(KeyCatalog.codeNameC(assignment.code)),\(assignment.modifiers),\(assignment.group),\(assignment.alternateType),\(KeyCatalog.codeNameC(assignment.alternateCode)),\(assignment.alternateModifiers),\(assignment.jogSelection)"
            )
        }

        let labeledKeys = configuration.keys.compactMap { assignment -> String? in
            guard let label = assignment.customDisplayLabel else {
                return nil
            }
            let sanitized = label.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            return "KeyLabel=\(assignment.keyID),\(sanitized)"
        }
        if !labeledKeys.isEmpty {
            lines.append("")
            lines.append("# optional UI labels: KeyLabel=keyid, display_label")
            lines.append(contentsOf: labeledKeys)
        }

        lines.append("")
        lines.append("# jog dial programming settings: JogData=mode_select, rate_select, dir, key_code, modifiers, rate1, rate2")
        for assignment in configuration.jogs {
            lines.append(
                "JogData=\(assignment.mode),\(assignment.rateSelect),\(assignment.direction.rawValue),\(KeyCatalog.codeNameC(assignment.code)),\(assignment.modifiers),\(assignment.rate1),\(assignment.rate2)"
            )
        }

        lines.append("")
        lines.append("# shuttle mode settings: JogType=mode_select, is_shuttle")
        for mode in 0..<configuration.jogTypes.count {
            lines.append("JogType=\(mode),\(configuration.jogTypes[mode] ? 1 : 0)")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}

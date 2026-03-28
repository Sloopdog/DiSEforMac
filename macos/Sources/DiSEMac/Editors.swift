import SwiftUI

struct KeyEditorView: View {
    let displayName: String
    @Binding var assignment: KeyAssignment
    let isBusy: Bool
    let onRead: () -> Void
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(displayName)
                .font(.largeTitle.weight(.semibold))
            Text("Key \(assignment.keyID)")
                .font(.title3.weight(.medium))
            .foregroundStyle(.secondary)
            Text(keyAssignmentSummary(assignment))
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Board Label") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Use automatic Resolve label", text: $assignment.displayLabel)
                        .textFieldStyle(.roundedBorder)

                    Text("Optional custom label for this key on the board preview. Leave it blank to keep the automatic shortcut-based label. Firmware 1.01+ stores up to 23 characters on the device.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            GroupBox("Primary Action") {
                VStack(alignment: .leading, spacing: 14) {
                    KeyCodePicker(title: "Primary Key", code: $assignment.code)
                    ModifierEditor(modifiers: $assignment.modifiers)
                    Stepper("LED Group: \(assignment.group)", value: $assignment.group, in: 0...50)
                }
                .padding(12)
            }

            GroupBox("Alternate Action") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Alternate Type", selection: alternateTypeBinding) {
                        ForEach(AlternateType.allCases) { alternateType in
                            Text(alternateType.title).tag(alternateType.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if assignment.alternateType != AlternateType.none.rawValue {
                        KeyCodePicker(title: "Alternate Key", code: $assignment.alternateCode)
                        ModifierEditor(modifiers: $assignment.alternateModifiers)
                    } else {
                        Text("No alternate action is active for this key.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }

            GroupBox("Jog Select") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Jog Selection", selection: jogSelectionKindBinding) {
                        ForEach(JogSelectionKind.allCases) { kind in
                            Text(kind.title).tag(kind.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if assignment.jogSelection != 0 {
                        Picker("Jog Mode", selection: jogModeBinding) {
                            ForEach(1...DiSEProtocol.jogModeCount, id: \.self) { mode in
                                Text("J\(mode)").tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("This key does not change the jog mode.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }

            HStack(spacing: 12) {
                Button("Read Selected From Device", action: onRead)
                    .disabled(isBusy)
                Button("Write Selected To Device", action: onWrite)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
            }
        }
    }

    private var alternateTypeBinding: Binding<Int> {
        Binding {
            assignment.alternateType
        } set: { newValue in
            assignment.alternateType = newValue
            if newValue == AlternateType.none.rawValue {
                assignment.alternateCode = 0
                assignment.alternateModifiers = 0
            }
        }
    }

    private var jogSelectionKindBinding: Binding<Int> {
        Binding {
            if assignment.jogSelection == 0 {
                return JogSelectionKind.none.rawValue
            }
            return (assignment.jogSelection & 0x10) != 0 ? JogSelectionKind.temporary.rawValue : JogSelectionKind.select.rawValue
        } set: { newValue in
            switch JogSelectionKind(rawValue: newValue) ?? .none {
            case .none:
                assignment.jogSelection = 0
            case .select:
                let mode = max(1, assignment.jogSelection & 0x0F)
                assignment.jogSelection = mode
            case .temporary:
                let mode = max(1, assignment.jogSelection & 0x0F)
                assignment.jogSelection = 0x10 | mode
            }
        }
    }

    private var jogModeBinding: Binding<Int> {
        Binding {
            max(1, assignment.jogSelection & 0x0F)
        } set: { newValue in
            let clampedMode = max(1, min(DiSEProtocol.jogModeCount, newValue))
            let tempBit = assignment.jogSelection & 0x10
            assignment.jogSelection = tempBit | clampedMode
        }
    }
}

struct JogEditorView: View {
    let displayName: String
    @Binding var assignment: JogAssignment
    @Binding var isShuttle: Bool
    let isBusy: Bool
    let onRead: () -> Void
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(displayName)
                .font(.largeTitle.weight(.semibold))
            Text("\(assignment.direction.title) Jog J\(assignment.mode + 1) Level \(assignment.rateSelect + 1)")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(jogAssignmentSummary(assignment, isShuttle: isShuttle))
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Action") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Shuttle Mode for J\(assignment.mode + 1)", isOn: $isShuttle)
                    KeyCodePicker(title: "Jog Key", code: $assignment.code)
                    ModifierEditor(modifiers: $assignment.modifiers)
                }
                .padding(12)
            }

            GroupBox(isShuttle ? "Shuttle Rates" : "Jog Rates") {
                VStack(alignment: .leading, spacing: 14) {
                    Stepper("\(isShuttle ? "Min Speed" : "Speed Threshold"): \(assignment.rate1)", value: $assignment.rate1, in: 0...255)
                    Stepper("\(isShuttle ? "Max Speed" : "Angle"): \(assignment.rate2)", value: $assignment.rate2, in: 0...255)
                }
                .padding(12)
            }

            HStack(spacing: 12) {
                Button("Read Selected From Device", action: onRead)
                    .disabled(isBusy)
                Button("Write Selected To Device", action: onWrite)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
            }
        }
    }
}

struct KeyCodePicker: View {
    let title: String
    @Binding var code: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Picker(title, selection: $code) {
                ForEach(KeyCatalog.entries) { entry in
                    Text("\(entry.name) (\(entry.hidCode))").tag(entry.hidCode)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

struct ModifierEditor: View {
    @Binding var modifiers: Int

    private let columns = [
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifiers")
                .font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(0..<KeyCatalog.modifierNames.count, id: \.self) { index in
                    Toggle(KeyCatalog.modifierNames[index], isOn: binding(for: index))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<Bool> {
        Binding {
            (modifiers & (1 << index)) != 0
        } set: { enabled in
            if enabled {
                modifiers |= (1 << index)
            } else {
                modifiers &= ~(1 << index)
            }
        }
    }
}

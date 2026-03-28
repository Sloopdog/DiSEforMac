import SwiftUI
import UniformTypeIdentifiers

private enum KeyboardCell: Hashable {
    case key(Int, CGFloat)
    case spacer(CGFloat)

    var baseWidth: CGFloat {
        switch self {
        case .key(_, let width):
            return width
        case .spacer(let width):
            return width
        }
    }
}

private let keyboardRows: [[KeyboardCell]] = [
    [.key(1, 56), .key(8, 56), .key(15, 56), .spacer(24), .key(22, 56), .key(29, 56), .key(36, 56), .key(43, 56), .spacer(24), .key(34, 84), .key(41, 84)],
    [.key(2, 56), .key(9, 56), .key(16, 56), .spacer(24), .key(23, 56), .key(30, 56), .key(37, 56), .key(44, 56), .spacer(24), .key(35, 56), .key(42, 56), .key(49, 56)],
    [.key(3, 84), .key(17, 84), .spacer(24), .key(24, 56), .key(31, 56), .key(38, 56), .key(45, 56)],
    [.key(4, 56), .key(11, 56), .key(18, 56), .spacer(24), .key(25, 56), .key(32, 56), .key(39, 56), .key(46, 56)],
    [.key(5, 56), .key(12, 56), .key(19, 56), .spacer(24), .key(26, 56), .key(33, 56), .key(40, 56), .key(47, 56)],
    [.key(6, 56), .key(13, 56), .key(20, 56), .spacer(24), .key(27, 164), .key(48, 72)],
]

private struct BoardKeyCell: Hashable, Identifiable {
    let keyID: Int
    let units: CGFloat

    var id: Int { keyID }
}

private let boardScaleVariants: [CGFloat] = [1.0, 0.92, 0.84, 0.76, 0.68, 0.60]
private let boardSectionSpacing: CGFloat = 14
private let boardKeySpacing: CGFloat = 8
private let boardUnitWidth: CGFloat = 72
private let boardKeyHeight: CGFloat = 68

private let topLeftBoardRows: [[BoardKeyCell]] = [
    [.init(keyID: 1, units: 1), .init(keyID: 8, units: 1), .init(keyID: 15, units: 1)],
    [.init(keyID: 2, units: 1), .init(keyID: 9, units: 1), .init(keyID: 16, units: 1)],
]

private let topCenterBoardRows: [[BoardKeyCell]] = [
    [.init(keyID: 22, units: 1), .init(keyID: 29, units: 1), .init(keyID: 36, units: 1), .init(keyID: 43, units: 1)],
    [.init(keyID: 23, units: 1), .init(keyID: 30, units: 1), .init(keyID: 37, units: 1), .init(keyID: 44, units: 1)],
]

private let topRightPrimaryRows: [[BoardKeyCell]] = [
    [.init(keyID: 34, units: 1.45), .init(keyID: 41, units: 1.45)],
]

private let topRightModeRows: [[BoardKeyCell]] = [
    [.init(keyID: 35, units: 1), .init(keyID: 42, units: 1), .init(keyID: 49, units: 1)],
]

private let lowerLeftBoardRows: [[BoardKeyCell]] = [
    [.init(keyID: 3, units: 1.5), .init(keyID: 17, units: 1.5)],
    [.init(keyID: 4, units: 1), .init(keyID: 11, units: 1), .init(keyID: 18, units: 1)],
    [.init(keyID: 5, units: 1), .init(keyID: 12, units: 1), .init(keyID: 19, units: 1)],
    [.init(keyID: 6, units: 1), .init(keyID: 13, units: 1), .init(keyID: 20, units: 1)],
]

private let lowerCenterBoardRows: [[BoardKeyCell]] = [
    [.init(keyID: 24, units: 1), .init(keyID: 31, units: 1), .init(keyID: 38, units: 1), .init(keyID: 45, units: 1)],
    [.init(keyID: 25, units: 1), .init(keyID: 32, units: 1), .init(keyID: 39, units: 1), .init(keyID: 46, units: 1)],
    [.init(keyID: 26, units: 1), .init(keyID: 33, units: 1), .init(keyID: 40, units: 1), .init(keyID: 47, units: 1)],
    [.init(keyID: 27, units: 3.15), .init(keyID: 48, units: 0.85)],
]

struct ContentView: View {
    private static let customProfileID = "__custom_speed_editor__"

    @EnvironmentObject private var controller: HIDController
    @StateObject private var profileLibrary = ProfileLibrary()
    @State private var selection: InspectorSelection = .key(1)
    @State private var selectedJogMode = 0
    @State private var selectedProfileID = ""
    @State private var isShowingSaveProfileSheet = false
    @State private var draftProfileName = "My Profile"
    @FocusState private var isProfileNameFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 18) {
                header
                contentArea(for: geometry.size)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            controller.start()
            if selectedProfileID.isEmpty {
                selectedProfileID = profileLibrary.allProfiles.first?.id ?? ""
            }
            syncSelectedProfileIDToCurrentConfiguration()
        }
        .onChange(of: controller.configuration) { _ in
            syncSelectedProfileIDToCurrentConfiguration()
        }
        .alert(item: $controller.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
        .sheet(isPresented: $isShowingSaveProfileSheet) {
            saveProfileSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    titleBlock
                    Spacer(minLength: 16)
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    actionButtons
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                statusBlock(title: "Device", value: controller.deviceName)
                statusBlock(title: "Firmware", value: controller.firmwareDisplayLabel)
                statusBlock(title: "Current Setup", value: controller.configurationSummary)
                statusBlock(title: "Last Flash", value: controller.lastProgrammedLabel)
                statusBlock(title: "Jog RPM", value: "\(controller.jogRPM)")
                statusBlock(title: "Jog Angle", value: "\(controller.jogAngle)°")
                statusBlock(title: "App Version", value: AppVersion.dashboardValue)
            }

            Text(controller.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DiSE Programmer")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(AppVersion.dashboardValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            connectionBadge

            Text(AppVersion.badgeLabel)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.16))
                .foregroundStyle(Color.orange)
                .clipShape(Capsule())
        }
    }

    private var connectionBadge: some View {
        Text(controller.isConnected ? "Connected" : "Disconnected")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(controller.isConnected ? Color.green.opacity(0.16) : Color.gray.opacity(0.18))
            .foregroundStyle(controller.isConnected ? Color.green : Color.secondary)
            .clipShape(Capsule())
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                openButton
                saveButton
                readButton
                writeButton
                programButton
                factoryDefaultButton
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    openButton
                    saveButton
                    readButton
                }
                HStack(spacing: 10) {
                    writeButton
                    programButton
                    factoryDefaultButton
                }
            }
        }
    }

    private var openButton: some View {
        Button("Open .DiSE") {
            openSettingsFile()
        }
    }

    private var saveButton: some View {
        Button("Save .DiSE") {
            saveSettingsFile()
        }
    }

    private var readButton: some View {
        Button("Read Device") {
            Task {
                await controller.readConfigurationFromDevice()
            }
        }
        .disabled(!controller.isConnected || controller.isBusy)
    }

    private var writeButton: some View {
        Button("Write Model") {
            Task {
                await controller.writeConfigurationToDevice()
            }
        }
        .disabled(!controller.isConnected || controller.isBusy)
    }

    private var programButton: some View {
        Button("Program Flash") {
            Task {
                await controller.programFlash()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!controller.isConnected || controller.isBusy)
    }

    private var factoryDefaultButton: some View {
        Button("Factory Default") {
            Task {
                await controller.resetToFactoryDefaults()
            }
        }
        .disabled(!controller.isConnected || controller.isBusy)
    }

    private func statusBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func contentArea(for size: CGSize) -> some View {
        let compactLayout = size.width < 1180
        let splitWidth = min(size.width, 1480)

        if compactLayout {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    leftPane
                    Divider()
                    inspectorContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            HStack(alignment: .top, spacing: 0) {
                HSplitView {
                    ScrollView {
                        leftPane
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                    }
                    .frame(minWidth: 740, idealWidth: 940, maxWidth: 1040, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)

                    inspectorPane
                        .frame(minWidth: 320, idealWidth: 400, maxWidth: 500, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: splitWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            profilesPane

            GroupBox("Board Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        ForEach(boardScaleVariants, id: \.self) { scale in
                            speedEditorBoard(scale: scale)
                        }
                    }

                    Text("Click any keycap to edit it. The board now uses the largest scale that fully fits in the panel, so the whole surface stays visible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            GroupBox("Jog Wheel") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Select a jog action to edit its mapping and rates.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Picker("Jog Mode", selection: $selectedJogMode) {
                        ForEach(0..<DiSEProtocol.jogModeCount, id: \.self) { mode in
                            Text("J\(mode + 1)").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedJogMode) { newMode in
                        if case .jog(_, let rate, let direction) = selection {
                            selection = .jog(mode: newMode, rate: rate, direction: direction)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(spacing: 10) {
                            jogButton(mode: selectedJogMode, rate: 2, direction: .left)
                            jogButton(mode: selectedJogMode, rate: 1, direction: .left)
                            jogButton(mode: selectedJogMode, rate: 0, direction: .left)
                        }

                        Circle()
                            .fill(.quaternary)
                            .frame(width: 170, height: 170)
                            .overlay {
                                VStack(spacing: 8) {
                                    Text("JOG")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text("\(controller.jogAngle)°")
                                        .font(.title3.monospacedDigit())
                                    Text("\(controller.jogRPM) rpm")
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }

                        VStack(spacing: 10) {
                            jogButton(mode: selectedJogMode, rate: 0, direction: .right)
                            jogButton(mode: selectedJogMode, rate: 1, direction: .right)
                            jogButton(mode: selectedJogMode, rate: 2, direction: .right)
                        }
                    }

                    Text("Live key highlights come from the device's raw custom HID reports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
    }

    private var profilesPane: some View {
        GroupBox("Profiles") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        profileSelectionRow

                        Text(currentProfileSummaryText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 320, idealWidth: 420, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        profileActionButtons

                        Text("Applying a profile updates the model in the app. Use Write Model, then Program Flash, if you want it pushed to the hardware.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 320, idealWidth: 360, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 14) {
                    profileSelectionRow

                    Text(currentProfileSummaryText)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    profileActionButtons

                    Text("Applying a profile updates the model in the app. Use Write Model, then Program Flash, if you want it pushed to the hardware.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }

    private var profileSelectionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                Text("Choose Profile")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                profilePicker

                profileKindBadge
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Choose Profile")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    profileKindBadge
                }

                profilePicker
            }
        }
    }

    private var profilePicker: some View {
        Picker("Choose Profile", selection: profileSelectionBinding) {
            if matchedCurrentProfile == nil {
                Section("Current") {
                    Text("Custom Speed Editor").tag(Self.customProfileID)
                }
            }

            Section("Built-in") {
                ForEach(profileLibrary.builtInProfiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }

            if !profileLibrary.savedProfiles.isEmpty {
                Section("Saved") {
                    ForEach(profileLibrary.savedProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var profileKindBadge: some View {
        Text(currentProfileKindLabel)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(currentProfileKindColor.opacity(0.12), in: Capsule())
            .foregroundStyle(currentProfileKindColor)
    }

    private var profileActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                applyProfileButton
                saveProfileButton
                deleteProfileButton
            }

            VStack(alignment: .leading, spacing: 10) {
                applyProfileButton
                saveProfileButton
                deleteProfileButton
            }
        }
    }

    private var applyProfileButton: some View {
        Button("Apply Profile") {
            applySelectedProfile()
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedProfile == nil || controller.isBusy)
    }

    private var saveProfileButton: some View {
        Button("Save Current as Profile") {
            saveCurrentAsProfile()
        }
    }

    private var deleteProfileButton: some View {
        Button("Delete Saved Profile") {
            deleteSelectedProfile()
        }
        .disabled(selectedProfile?.isBuiltIn ?? true)
    }

    private var saveProfileSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Current Configuration")
                .font(.title2.weight(.semibold))

            Text("Store the current mapping as a reusable local profile.")
                .foregroundStyle(.secondary)

            TextField("Profile Name", text: $draftProfileName)
                .textFieldStyle(.roundedBorder)
                .focused($isProfileNameFocused)
                .onSubmit {
                    confirmSaveCurrentProfile()
                }

            HStack {
                Spacer()

                Button("Cancel") {
                    isShowingSaveProfileSheet = false
                }

                Button("Save") {
                    confirmSaveCurrentProfile()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .onAppear {
            DispatchQueue.main.async {
                isProfileNameFocused = true
            }
        }
    }

    private func speedEditorBoard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20 * scale) {
            Text("DAVINCI RESOLVE SPEED EDITOR")
                .font(.system(size: max(12, 22 * scale), weight: .medium, design: .rounded))
                .tracking(1.6 * scale)
                .foregroundStyle(Color.white.opacity(0.92))

            HStack(alignment: .top, spacing: boardSectionSpacing * scale) {
                VStack(alignment: .leading, spacing: boardSectionSpacing * scale) {
                    HStack(alignment: .top, spacing: boardSectionSpacing * scale) {
                        boardSection(rows: topLeftBoardRows, scale: scale)
                        boardSection(rows: topCenterBoardRows, scale: scale)
                    }

                    HStack(alignment: .top, spacing: boardSectionSpacing * scale) {
                        boardSection(rows: lowerLeftBoardRows, scale: scale)
                        boardSection(rows: lowerCenterBoardRows, scale: scale)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: boardSectionSpacing * scale) {
                    boardSection(rows: topRightPrimaryRows, scale: scale)
                    boardSection(rows: topRightModeRows, scale: scale)
                    Color.clear
                        .frame(height: 22 * scale)
                    jogWheelPreview(scale: scale)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(14 * scale)
        .background(
            RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.77, green: 0.79, blue: 0.80), Color(red: 0.55, green: 0.57, blue: 0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: max(1, 1.5 * scale))
                )
        )
        .overlay(alignment: .topTrailing) {
            Text(currentProfileDisplayName.uppercased())
                .font(.system(size: max(7, 10 * scale), weight: .bold, design: .rounded))
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 6 * scale)
                .background(Color.black.opacity(0.22), in: Capsule())
                .foregroundStyle(Color.white.opacity(0.86))
                .padding(14 * scale)
        }
        .shadow(color: .black.opacity(0.18), radius: 18 * scale, y: 8 * scale)
    }

    private func boardSection(rows: [[BoardKeyCell]], scale: CGFloat) -> some View {
        VStack(spacing: boardKeySpacing * scale) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: boardKeySpacing * scale) {
                    ForEach(row) { cell in
                        keyButton(keyID: cell.keyID, width: boardUnitWidth * cell.units * scale, scale: scale)
                    }
                }
            }
        }
        .padding(12 * scale)
        .background(
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: max(1, scale))
                )
        )
    }

    private func jogWheelPreview(scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.15, green: 0.16, blue: 0.18), Color(red: 0.06, green: 0.07, blue: 0.08)],
                            center: .center,
                            startRadius: 12 * scale,
                            endRadius: 130 * scale
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: max(1, 1.4 * scale))
                    )

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 66 * scale, height: 66 * scale)
                    .offset(x: -34 * scale, y: -34 * scale)

                VStack(spacing: 6 * scale) {
                    Text("J\(selectedJogMode + 1)")
                        .font(.system(size: max(10, 18 * scale), weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(controller.jogAngle)°")
                        .font(.system(size: max(9, 14 * scale), weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("\(controller.jogRPM) rpm")
                        .font(.system(size: max(8, 11 * scale), weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 220 * scale, height: 220 * scale)

            Text(displayJogLabel(mode: selectedJogMode, assignment: controller.configuration.jog(mode: selectedJogMode, rateSelect: 0, direction: .right)))
                .font(.system(size: max(9, 12 * scale), weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(maxWidth: .infinity)
        }
        .frame(width: 210 * scale)
    }

    private func keyButton(keyID: Int, width: CGFloat, scale: CGFloat) -> some View {
        let assignment = controller.configuration.key(for: keyID)
        let isSelected = selection == .key(keyID)
        let isPressed = controller.pressedKeys.contains(keyID)
        let keyHeight = boardKeyHeight * scale
        let capStyle = boardKeyStyle(for: keyID)
        let mainLabel = displayKeyLabel(for: keyID, assignment: assignment).uppercased()
        let subtitle = keyFaceSubtitle(for: keyID, assignment: assignment)?.uppercased()
        let baseFill = keyFillColor(for: capStyle, isPressed: isPressed)
        let textColor = keyTextColor(for: capStyle)

        return Button {
            selection = .key(keyID)
        } label: {
            VStack(spacing: 6 * scale) {
                Spacer(minLength: 0)

                Text(mainLabel)
                    .font(.system(size: max(7.5, 11.8 * scale), weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.58)
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: max(6.5, 8.6 * scale), weight: .semibold, design: .rounded))
                        .tracking(0.8 * scale)
                        .foregroundStyle(textColor.opacity(0.74))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 8 * scale)
            .padding(.vertical, 10 * scale)
            .frame(width: width, height: keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                            .stroke(isSelected ? Color.cyan.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isSelected ? max(2, 2.5 * scale) : max(1, scale))
                    )
                    .shadow(color: .black.opacity(0.28), radius: 7 * scale, y: 4 * scale)
            )
        }
        .frame(width: width)
        .buttonStyle(.plain)
        .help(keyHelpText(for: keyID, assignment: assignment))
    }

    private func boardKeyStyle(for keyID: Int) -> BoardKeyStyle {
        switch keyID {
        case 3, 17, 35, 42, 49:
            return .light
        case 43:
            return .accent
        case 45, 46, 47:
            return .muted
        default:
            return .dark
        }
    }

    private func keyFaceSubtitle(for keyID: Int, assignment: KeyAssignment) -> String? {
        let activeLabel = displayKeyLabel(for: keyID, assignment: assignment)

        let shortcut = compactKeyAssignmentLabel(assignment)
        if shortcut == "Unassigned" || activeLabel.caseInsensitiveCompare(shortcut) == .orderedSame {
            return nil
        }
        return shortcut
    }

    private func keyHelpText(for keyID: Int, assignment: KeyAssignment) -> String {
        let assignedName = displayKeyLabel(for: keyID, assignment: assignment)
        return "Key \(keyID): \(assignedName)\n\(keyAssignmentSummary(assignment))"
    }

    private func keyFillColor(for style: BoardKeyStyle, isPressed: Bool) -> LinearGradient {
        let colors: [Color]
        switch style {
        case .dark:
            colors = isPressed
                ? [Color.orange.opacity(0.95), Color(red: 0.57, green: 0.29, blue: 0.10)]
                : [Color(red: 0.24, green: 0.27, blue: 0.30), Color(red: 0.13, green: 0.15, blue: 0.17)]
        case .light:
            colors = isPressed
                ? [Color(red: 1.0, green: 0.93, blue: 0.74), Color(red: 0.89, green: 0.79, blue: 0.56)]
                : [Color(red: 0.96, green: 0.97, blue: 0.95), Color(red: 0.84, green: 0.88, blue: 0.88)]
        case .muted:
            colors = isPressed
                ? [Color(red: 0.82, green: 0.90, blue: 0.98), Color(red: 0.44, green: 0.58, blue: 0.67)]
                : [Color(red: 0.43, green: 0.49, blue: 0.54), Color(red: 0.26, green: 0.29, blue: 0.33)]
        case .accent:
            colors = isPressed
                ? [Color(red: 1.0, green: 0.58, blue: 0.35), Color(red: 0.83, green: 0.24, blue: 0.14)]
                : [Color(red: 0.93, green: 0.35, blue: 0.41), Color(red: 0.70, green: 0.18, blue: 0.25)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func keyTextColor(for style: BoardKeyStyle) -> Color {
        switch style {
        case .light:
            return Color.black.opacity(0.72)
        default:
            return Color.white.opacity(0.95)
        }
    }

    private enum BoardKeyStyle {
        case dark
        case light
        case muted
        case accent
    }

    private func displayKeyLabel(for keyID: Int, assignment: KeyAssignment) -> String {
        if let customLabel = assignment.customDisplayLabel {
            return customLabel
        }
        return ResolveLabelCatalog.keyLabel(for: keyID, assignment: assignment) ?? compactKeyAssignmentLabel(assignment)
    }

    private func compactKeyAssignmentLabel(_ assignment: KeyAssignment) -> String {
        if assignment.code != 0 {
            return compactShortcutLabel(code: assignment.code, modifiers: assignment.modifiers)
        }
        if assignment.jogSelection != 0 {
            return jogSelectionDescription(assignment.jogSelection)
        }
        if assignment.alternateType != 0 && assignment.alternateCode != 0 {
            return "Alt \(compactShortcutLabel(code: assignment.alternateCode, modifiers: assignment.alternateModifiers))"
        }
        return "Unassigned"
    }

    private func jogButton(mode: Int, rate: Int, direction: JogDirection) -> some View {
        let assignment = controller.configuration.jog(mode: mode, rateSelect: rate, direction: direction)
        let isSelected = selection == .jog(mode: mode, rate: rate, direction: direction)
        let actionLabel = displayJogLabel(mode: mode, assignment: assignment)

        return VStack(spacing: 4) {
            Text(actionLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
                .frame(width: 84, height: 22, alignment: .bottom)

            Button {
                selection = .jog(mode: mode, rate: rate, direction: direction)
            } label: {
                Text("\(direction.shortTitle)\(rate + 1)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: 84, height: 46)
                    .background(isSelected ? Color.accentColor : Color.gray.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .help(jogAssignmentSummary(assignment, isShuttle: controller.configuration.jogTypes[mode]))
    }

    private func displayJogLabel(mode: Int, assignment: JogAssignment) -> String {
        let isShuttle = controller.configuration.jogTypes[mode]
        return ResolveLabelCatalog.jogLabel(for: assignment, isShuttle: isShuttle)
            ?? compactShortcutLabel(code: assignment.code, modifiers: assignment.modifiers)
    }

    private func compactShortcutLabel(code: Int, modifiers: Int) -> String {
        guard code != 0 else {
            return "None"
        }

        let modifierNames = ["Ctrl", "Shift", "Alt", "Cmd", "RCtrl", "RShift", "RAlt", "RCmd"]
        var pieces: [String] = []

        for index in 0..<modifierNames.count where (modifiers & (1 << index)) != 0 {
            pieces.append(modifierNames[index])
        }

        pieces.append(compactKeyName(for: code))
        return pieces.joined(separator: "+")
    }

    private func compactKeyName(for code: Int) -> String {
        switch KeyCatalog.name(for: code) {
        case "Backspace":
            return "Bksp"
        case "Backslash":
            return "\\"
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

    private var inspectorPane: some View {
        ScrollView {
            inspectorContent
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch selection {
        case .key(let keyID):
            KeyEditorView(
                displayName: displayKeyLabel(for: keyID, assignment: controller.configuration.key(for: keyID)),
                assignment: keyBinding(keyID),
                isBusy: controller.isBusy,
                onRead: {
                    Task {
                        await controller.refreshKeyFromDevice(keyID: keyID)
                    }
                },
                onWrite: {
                    Task {
                        await controller.writeKeyToDevice(keyID: keyID)
                    }
                }
            )

        case .jog(let mode, let rate, let direction):
            JogEditorView(
                displayName: displayJogLabel(mode: mode, assignment: controller.configuration.jog(mode: mode, rateSelect: rate, direction: direction)),
                assignment: jogBinding(mode: mode, rate: rate, direction: direction),
                isShuttle: shuttleBinding(mode: mode),
                isBusy: controller.isBusy,
                onRead: {
                    Task {
                        await controller.refreshJogFromDevice(mode: mode, rateSelect: rate, direction: direction)
                    }
                },
                onWrite: {
                    Task {
                        await controller.writeJogToDevice(mode: mode, rateSelect: rate, direction: direction)
                    }
                }
            )
        }
    }

    private func keyBinding(_ keyID: Int) -> Binding<KeyAssignment> {
        Binding {
            controller.configuration.key(for: keyID)
        } set: { updated in
            controller.updateKey(updated)
        }
    }

    private func jogBinding(mode: Int, rate: Int, direction: JogDirection) -> Binding<JogAssignment> {
        Binding {
            controller.configuration.jog(mode: mode, rateSelect: rate, direction: direction)
        } set: { updated in
            controller.updateJog(updated)
        }
    }

    private func shuttleBinding(mode: Int) -> Binding<Bool> {
        Binding {
            controller.configuration.jogTypes[mode]
        } set: { isShuttle in
            controller.updateJogType(mode: mode, isShuttle: isShuttle)
        }
    }

    private func openSettingsFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "DiSE") ?? .plainText]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Open a DiSE settings file"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let parsed = try SettingsFile.parse(contents: contents)
            controller.replaceConfiguration(parsed, sourceDescription: "Loaded \(url.lastPathComponent)")
        } catch {
            controller.alert = AppAlert(title: "Open Failed", message: error.localizedDescription)
        }
    }

    private func saveSettingsFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "DiSE") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "DiSE-Settings.DiSE"
        panel.message = "Save the current model as a DiSE settings file"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let serialized = SettingsFile.serialize(controller.configuration)
            try serialized.write(to: url, atomically: true, encoding: .utf8)
            controller.statusMessage = "Saved \(url.lastPathComponent)"
        } catch {
            controller.alert = AppAlert(title: "Save Failed", message: error.localizedDescription)
        }
    }

    private var selectedProfile: ConfigurationProfile? {
        profileLibrary.profile(id: selectedProfileID)
    }

    private var matchedCurrentProfile: ConfigurationProfile? {
        profileLibrary.allProfiles.first { $0.configuration == controller.configuration }
    }

    private var currentProfileDisplayName: String {
        matchedCurrentProfile?.name ?? "Custom Speed Editor"
    }

    private var currentProfileSummaryText: String {
        matchedCurrentProfile?.summary ?? "Current model includes edits that no longer match a saved or built-in profile."
    }

    private var currentProfileKindLabel: String {
        guard let matchedCurrentProfile else {
            return "Custom"
        }
        return matchedCurrentProfile.isBuiltIn ? "Built-in" : "Saved"
    }

    private var currentProfileKindColor: Color {
        guard let matchedCurrentProfile else {
            return .orange
        }
        return matchedCurrentProfile.isBuiltIn ? .accentColor : .green
    }

    private var profileSelectionBinding: Binding<String> {
        Binding {
            if selectedProfileID == Self.customProfileID {
                return Self.customProfileID
            }
            if profileLibrary.profile(id: selectedProfileID) != nil {
                return selectedProfileID
            }
            return matchedCurrentProfile?.id ?? Self.customProfileID
        } set: { newValue in
            selectedProfileID = newValue
        }
    }

    private func syncSelectedProfileIDToCurrentConfiguration() {
        let currentID = matchedCurrentProfile?.id ?? Self.customProfileID
        if selectedProfileID != currentID {
            selectedProfileID = currentID
        }
    }

    private func applySelectedProfile() {
        guard let profile = selectedProfile else {
            return
        }
        guard confirmApplyProfileIfNeeded(profile) else {
            return
        }

        controller.replaceConfiguration(
            profile.configuration,
            sourceDescription: "Applied profile \(profile.name). Write Model and Program Flash to send it to the device.",
            markDirty: true
        )
    }

    private func saveCurrentAsProfile() {
        draftProfileName = selectedProfile?.isBuiltIn == false ? (selectedProfile?.name ?? "") : "My Profile"
        isShowingSaveProfileSheet = true
    }

    private func confirmSaveCurrentProfile() {
        let profileName = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileName.isEmpty else {
            controller.alert = AppAlert(title: "Missing Name", message: "Enter a profile name before saving.")
            return
        }

        if profileLibrary.savedProfile(named: profileName) != nil,
           !confirmOverwriteProfile(named: profileName) {
            return
        }

        do {
            let savedProfile = try profileLibrary.saveProfile(named: profileName, configuration: controller.configuration)
            selectedProfileID = savedProfile.id
            controller.statusMessage = "Saved profile \(savedProfile.name)"
            isShowingSaveProfileSheet = false
        } catch {
            controller.alert = AppAlert(title: "Save Failed", message: error.localizedDescription)
        }
    }

    private func deleteSelectedProfile() {
        guard let profile = selectedProfile,
              !profile.isBuiltIn else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete Profile?"
        alert.informativeText = "This removes the saved profile \(profile.name) from this Mac."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try profileLibrary.deleteProfile(profile)
            selectedProfileID = profileLibrary.allProfiles.first?.id ?? ""
            controller.statusMessage = "Deleted profile \(profile.name)"
        } catch {
            controller.alert = AppAlert(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    private func confirmApplyProfileIfNeeded(_ profile: ConfigurationProfile) -> Bool {
        guard controller.dirty else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Replace Current Model?"
        alert.informativeText = "Applying \(profile.name) will replace the edits currently loaded in the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmOverwriteProfile(named name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Overwrite Existing Profile?"
        alert.informativeText = "A saved profile named \(name) already exists."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

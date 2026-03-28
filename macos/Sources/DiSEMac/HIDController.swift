import AppKit
import Foundation
import IOKit.hid

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum HIDError: LocalizedError {
    case deviceNotConnected
    case deviceOpenFailed(IOReturn)
    case reportWriteFailed(IOReturn)
    case timeout
    case badResponse
    case deviceDisconnected
    case saveFailed(Int)

    var errorDescription: String? {
        switch self {
        case .deviceNotConnected:
            return "DiSE custom HID device is not connected."
        case .deviceOpenFailed(let code):
            return "Unable to open DiSE device. IOKit error \(code)."
        case .reportWriteFailed(let code):
            return "Unable to write report to device. IOKit error \(code)."
        case .timeout:
            return "Timed out waiting for a device response."
        case .badResponse:
            return "Received an unexpected response from the device."
        case .deviceDisconnected:
            return "The device disconnected while the operation was running."
        case .saveFailed(let code):
            return "The device reported save error \(code)."
        }
    }
}

@MainActor
final class HIDController: ObservableObject {
    @Published var configuration: DeviceConfiguration = .empty {
        didSet {
            refreshConfigurationMetadata()
        }
    }
    @Published var isConnected = false
    @Published var deviceName = "Disconnected"
    @Published var firmwareVersion: String?
    @Published var configurationSummary = "Blank Layout"
    @Published var lastProgrammedLabel = "Never"
    @Published var statusMessage = "Waiting for DiSE device"
    @Published var isBusy = false
    @Published var pressedKeys: Set<Int> = []
    @Published var jogAngle = 0
    @Published var jogRPM = 0
    @Published var dirty = false
    @Published var alert: AppAlert?

    var firmwareDisplayLabel: String {
        if let firmwareVersion, !firmwareVersion.isEmpty {
            return "v\(firmwareVersion)"
        }

        return isConnected ? "Custom Build" : "Waiting for Device"
    }

    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    nonisolated(unsafe) private let inputBuffer: UnsafeMutablePointer<UInt8>
    private var managerStarted = false
    private var autoLoadedConfiguration = false

    private struct PendingReport {
        let matcher: ([UInt8]) -> Bool
        let continuation: CheckedContinuation<[UInt8], Error>
    }

    private var pendingReports: [UUID: PendingReport] = [:]

    private var supportsOnDeviceKeyLabels: Bool {
        guard let firmwareVersion else {
            return false
        }

        let components = firmwareVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard
            let major = components.first.flatMap({ Int($0) }),
            let minor = components.dropFirst().first.flatMap({ Int($0) })
        else {
            return false
        }

        return major > 1 || (major == 1 && minor >= 1)
    }

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: DiSEProtocol.reportSize)
        inputBuffer.initialize(repeating: 0, count: DiSEProtocol.reportSize)
        refreshConfigurationMetadata()
    }

    deinit {
        inputBuffer.deinitialize(count: DiSEProtocol.reportSize)
        inputBuffer.deallocate()
    }

    func start() {
        guard !managerStarted else {
            return
        }
        managerStarted = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerSetDeviceMatchingMultiple(manager, customInterfaceMatches as CFArray)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, hidDeviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, hidDeviceRemoved, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            let message: String
            if openResult == kIOReturnNotPermitted {
                message = """
                macOS blocked access to the DiSE HID interface.

                This device firmware exposes both a keyboard HID interface and a vendor-specific control HID interface. The app is now matching only the vendor-specific interface, but macOS may still require a fresh privacy grant for the exact app build you launched.

                If you are launching the built app bundle, remove and re-add that exact app in System Settings > Privacy & Security > Input Monitoring, then quit and reopen it.

                If you are launching from Terminal or Xcode, re-open Terminal or Xcode after granting Input Monitoring there and run the app again.
                """
            } else {
                message = "Unable to initialize the macOS HID manager. IOKit error \(openResult)."
            }
            alert = AppAlert(
                title: "HID Manager Error",
                message: message
            )
            statusMessage = "Unable to access the DiSE HID interface."
            return
        }

        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
           let existingDevice = devices
            .sorted(by: { hidMatchScore(for: $0) > hidMatchScore(for: $1) })
            .first(where: { hidMatchScore(for: $0) > 0 }) {
            handleDeviceMatched(existingDevice)
        }
    }

    private var customInterfaceMatches: [[String: Any]] {
        DiSEProtocol.macOSUsagePages.map { usagePage in
            [
                kIOHIDVendorIDKey as String: DiSEProtocol.vendorID,
                kIOHIDProductIDKey as String: DiSEProtocol.productID,
                kIOHIDPrimaryUsagePageKey as String: usagePage,
                kIOHIDPrimaryUsageKey as String: DiSEProtocol.usage,
            ]
        }
    }

    func replaceConfiguration(_ newConfiguration: DeviceConfiguration, sourceDescription: String, markDirty: Bool = false) {
        configuration = ConfigurationMetadataStore.restoringLabels(in: newConfiguration)
        dirty = markDirty
        statusMessage = sourceDescription
    }

    func updateKey(_ assignment: KeyAssignment) {
        var newConfiguration = configuration
        newConfiguration.update(sanitized(assignment))
        configuration = newConfiguration
        dirty = true
    }

    func updateJog(_ assignment: JogAssignment) {
        var newConfiguration = configuration
        newConfiguration.update(sanitized(assignment))
        configuration = newConfiguration
        dirty = true
    }

    func updateJogType(mode: Int, isShuttle: Bool) {
        var newConfiguration = configuration
        newConfiguration.setJogType(mode: mode, isShuttle: isShuttle)
        configuration = newConfiguration
        dirty = true
    }

    func readConfigurationFromDevice() async {
        guard !isBusy else {
            return
        }
        guard device != nil else {
            showError(HIDError.deviceNotConnected)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            if let version = try? await readFirmwareVersion() {
                firmwareVersion = version
            }
            statusMessage = "Reading keys from device"
            var newConfiguration = DeviceConfiguration.empty

            for keyID in 1...DiSEProtocol.keyCount {
                var assignment = try await readKey(keyID: keyID)
                if supportsOnDeviceKeyLabels, let label = try? await readKeyLabel(keyID: keyID) {
                    assignment.displayLabel = label
                } else {
                    assignment.displayLabel = configuration.key(for: keyID).displayLabel
                }
                newConfiguration.update(assignment)
                statusMessage = "Reading keys \(keyID)/\(DiSEProtocol.keyCount)"
            }

            for mode in 0..<DiSEProtocol.jogModeCount {
                for rateSelect in 0..<DiSEProtocol.jogRateCount {
                    for direction in JogDirection.allCases {
                        let assignment = try await readJogData(mode: mode, rateSelect: rateSelect, direction: direction)
                        newConfiguration.update(assignment)
                    }
                }
                let isShuttle = try await readJogType(mode: mode)
                newConfiguration.setJogType(mode: mode, isShuttle: isShuttle)
                statusMessage = "Reading jog mode \(mode + 1)/\(DiSEProtocol.jogModeCount)"
            }
            configuration = supportsOnDeviceKeyLabels
                ? newConfiguration
                : ConfigurationMetadataStore.restoringLabels(in: newConfiguration)
            dirty = false
            statusMessage = "Loaded configuration from device"
        } catch {
            showError(error)
        }
    }

    func writeConfigurationToDevice() async {
        guard !isBusy else {
            return
        }
        guard device != nil else {
            showError(HIDError.deviceNotConnected)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            if firmwareVersion == nil {
                firmwareVersion = try? await readFirmwareVersion()
            }
            for (index, assignment) in configuration.keys.enumerated() {
                try writeKey(assignment)
                if supportsOnDeviceKeyLabels {
                    try writeKeyLabel(assignment)
                }
                statusMessage = "Writing keys \(index + 1)/\(configuration.keys.count)"
            }

            for assignment in configuration.jogs {
                try writeJogData(assignment)
            }

            for mode in 0..<configuration.jogTypes.count {
                try writeJogType(mode: mode, isShuttle: configuration.jogTypes[mode])
            }

            dirty = false
            statusMessage = "Model written to device RAM. Use Program Flash to persist it."
        } catch {
            showError(error)
        }
    }

    func programFlash() async {
        guard !isBusy else {
            return
        }
        guard device != nil else {
            showError(HIDError.deviceNotConnected)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            statusMessage = "Saving settings to device flash"
            let result = try await sendAndWait(report: makeSimpleCommand(.saveSettings)) {
                $0.first == UInt8(HIDMessage.saveResult.rawValue)
            }
            let saveCode = Int(result[safe: 2] ?? 0)
            guard saveCode == 0 else {
                throw HIDError.saveFailed(saveCode)
            }
            let metadata = ConfigurationMetadataStore.recordProgrammed(configuration)
            configurationSummary = metadata.summary
            lastProgrammedLabel = ConfigurationMetadataStore.lastProgrammedText(for: configuration)
            dirty = false
            statusMessage = "Settings saved to device flash: \(metadata.summary)"
        } catch {
            showError(error)
        }
    }

    func resetToFactoryDefaults() async {
        guard !isBusy else {
            return
        }
        guard device != nil else {
            showError(HIDError.deviceNotConnected)
            return
        }

        let confirmation = NSAlert()
        confirmation.messageText = "Reset Device?"
        confirmation.informativeText = "This replaces the device configuration with the firmware defaults."
        confirmation.alertStyle = .warning
        confirmation.addButton(withTitle: "Reset")
        confirmation.addButton(withTitle: "Cancel")
        guard confirmation.runModal() == .alertFirstButtonReturn else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            statusMessage = "Resetting device to factory defaults"
            let result = try await sendAndWait(report: makeSimpleCommand(.factoryDefault)) {
                $0.first == UInt8(HIDMessage.saveResult.rawValue)
            }
            let saveCode = Int(result[safe: 2] ?? 0)
            guard saveCode == 0 else {
                throw HIDError.saveFailed(saveCode)
            }
            statusMessage = "Factory defaults restored. Reloading configuration."
            autoLoadedConfiguration = true
            await readConfigurationFromDevice()
        } catch {
            showError(error)
        }
    }

    func refreshKeyFromDevice(keyID: Int) async {
        guard !isBusy else {
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            var assignment = try await readKey(keyID: keyID)
            if supportsOnDeviceKeyLabels, let label = try? await readKeyLabel(keyID: keyID) {
                assignment.displayLabel = label
            } else {
                assignment.displayLabel = configuration.key(for: keyID).displayLabel
            }
            var newConfiguration = configuration
            newConfiguration.update(assignment)
            configuration = newConfiguration
            statusMessage = "Refreshed key \(keyID) from device"
        } catch {
            showError(error)
        }
    }

    func refreshJogFromDevice(mode: Int, rateSelect: Int, direction: JogDirection) async {
        guard !isBusy else {
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let assignment = try await readJogData(mode: mode, rateSelect: rateSelect, direction: direction)
            let isShuttle = try await readJogType(mode: mode)
            var newConfiguration = configuration
            newConfiguration.update(assignment)
            newConfiguration.setJogType(mode: mode, isShuttle: isShuttle)
            configuration = newConfiguration
            statusMessage = "Refreshed jog J\(mode + 1) \(direction.title.lowercased()) L\(rateSelect + 1)"
        } catch {
            showError(error)
        }
    }

    func writeKeyToDevice(keyID: Int) async {
        guard !isBusy else {
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            if firmwareVersion == nil {
                firmwareVersion = try? await readFirmwareVersion()
            }
            try writeKey(configuration.key(for: keyID))
            if supportsOnDeviceKeyLabels {
                try writeKeyLabel(configuration.key(for: keyID))
            }
            statusMessage = "Wrote key \(keyID) to device RAM"
        } catch {
            showError(error)
        }
    }

    func writeJogToDevice(mode: Int, rateSelect: Int, direction: JogDirection) async {
        guard !isBusy else {
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            try writeJogData(configuration.jog(mode: mode, rateSelect: rateSelect, direction: direction))
            try writeJogType(mode: mode, isShuttle: configuration.jogTypes[mode])
            statusMessage = "Wrote jog J\(mode + 1) \(direction.title.lowercased()) L\(rateSelect + 1) to device RAM"
        } catch {
            showError(error)
        }
    }

    fileprivate func handleDeviceMatched(_ matchedDevice: IOHIDDevice) {
        guard device == nil else {
            return
        }
        guard hidMatchScore(for: matchedDevice) > 0 else {
            return
        }

        let openResult = IOHIDDeviceOpen(matchedDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            showError(HIDError.deviceOpenFailed(openResult))
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            matchedDevice,
            inputBuffer,
            DiSEProtocol.reportSize,
            hidInputReportReceived,
            context
        )

        device = matchedDevice
        isConnected = true
        deviceName = (IOHIDDeviceGetProperty(matchedDevice, kIOHIDProductKey as CFString) as? String) ?? "DiSE"
        statusMessage = "Connected to \(deviceName)"

        Task {
            firmwareVersion = try? await readFirmwareVersion()
            if !autoLoadedConfiguration {
                autoLoadedConfiguration = true
                await readConfigurationFromDevice()
            }
        }
    }

    fileprivate func handleDeviceRemoved(_ removedDevice: IOHIDDevice) {
        guard let currentDevice = device, CFEqual(currentDevice, removedDevice) else {
            return
        }

        device = nil
        isConnected = false
        deviceName = "Disconnected"
        firmwareVersion = nil
        statusMessage = "DiSE device disconnected"
        pressedKeys.removeAll()
        jogRPM = 0
        jogAngle = 0

        let continuations = pendingReports.values
        pendingReports.removeAll()
        for pending in continuations {
            pending.continuation.resume(throwing: HIDError.deviceDisconnected)
        }
    }

    fileprivate func handleInputReport(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else {
            return
        }

        if bytes[0] == UInt8(HIDMessage.keyActions.rawValue) {
            applyLiveKeyActions(bytes)
            return
        }

        if let pendingID = pendingReports.first(where: { $0.value.matcher(bytes) })?.key,
           let pending = pendingReports.removeValue(forKey: pendingID) {
            pending.continuation.resume(returning: bytes)
            return
        }

        if bytes[0] == UInt8(HIDMessage.version.rawValue),
           bytes.count >= 4 {
            firmwareVersion = "\(bytes[2]).\(String(format: "%02d", bytes[3]))"
        }
    }

    private func applyLiveKeyActions(_ bytes: [UInt8]) {
        let pressedRange = 2..<10
        let releasedRange = 10..<18

        for index in pressedRange where index < bytes.count {
            let key = Int(bytes[index])
            guard key != 0 else { break }
            pressedKeys.insert(key)
        }

        for index in releasedRange where index < bytes.count {
            let key = Int(bytes[index])
            guard key != 0 else { break }
            pressedKeys.remove(key)
        }

        if bytes.count > 21 {
            jogAngle = Int(bytes[18]) | (Int(bytes[19]) << 8)
            jogRPM = Int(bytes[20]) | (Int(bytes[21]) << 8)
        }
    }

    private func sendReport(_ report: [UInt8]) throws {
        guard let device else {
            throw HIDError.deviceNotConnected
        }
        let result = report.withUnsafeBytes { rawBuffer -> IOReturn in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnError
            }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                0,
                baseAddress,
                report.count
            )
        }
        guard result == kIOReturnSuccess else {
            throw HIDError.reportWriteFailed(result)
        }
    }

    private func sendAndWait(
        report: [UInt8],
        timeout: Duration = .seconds(1),
        matching: @escaping ([UInt8]) -> Bool
    ) async throws -> [UInt8] {
        let requestID = UUID()

        return try await withCheckedThrowingContinuation { continuation in
            pendingReports[requestID] = PendingReport(matcher: matching, continuation: continuation)

            do {
                try sendReport(report)
            } catch {
                pendingReports.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
                return
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self, let pending = self.pendingReports.removeValue(forKey: requestID) else {
                    return
                }
                pending.continuation.resume(throwing: HIDError.timeout)
            }
        }
    }

    private func readKey(keyID: Int) async throws -> KeyAssignment {
        let report = try await sendAndWait(report: makeGetKeyReport(keyID: keyID)) {
            $0.first == UInt8(HIDMessage.keyData.rawValue) && Int($0[safe: 2] ?? 0) == keyID
        }
        guard report.count >= 10 else {
            throw HIDError.badResponse
        }
        return KeyAssignment(
            keyID: Int(report[2]),
            code: Int(report[3]),
            modifiers: Int(report[4]),
            group: Int(report[5]),
            alternateType: Int(report[6]),
            alternateCode: Int(report[7]),
            alternateModifiers: Int(report[8]),
            jogSelection: Int(report[9])
        )
    }

    private func readKeyLabel(keyID: Int) async throws -> String {
        let report = try await sendAndWait(report: makeGetKeyLabelReport(keyID: keyID)) {
            $0.first == UInt8(HIDMessage.keyLabel.rawValue) && Int($0[safe: 2] ?? 0) == keyID
        }
        guard report.count >= 3 + DiSEProtocol.keyLabelLength else {
            throw HIDError.badResponse
        }

        let labelBytes = Array(report[3..<(3 + DiSEProtocol.keyLabelLength)])
        let endIndex = labelBytes.firstIndex(of: 0) ?? labelBytes.count
        return String(decoding: labelBytes.prefix(endIndex), as: UTF8.self)
    }

    private func readJogData(mode: Int, rateSelect: Int, direction: JogDirection) async throws -> JogAssignment {
        let report = try await sendAndWait(report: makeGetJogDataReport(mode: mode, rateSelect: rateSelect, direction: direction)) {
            $0.first == UInt8(HIDMessage.jogData.rawValue)
                && Int($0[safe: 2] ?? 255) == mode
                && Int($0[safe: 3] ?? 255) == rateSelect
                && Int($0[safe: 4] ?? 255) == direction.rawValue
        }
        guard report.count >= 9 else {
            throw HIDError.badResponse
        }
        return JogAssignment(
            mode: Int(report[2]),
            rateSelect: Int(report[3]),
            direction: JogDirection(rawValue: Int(report[4])) ?? direction,
            code: Int(report[5]),
            modifiers: Int(report[6]),
            rate1: Int(report[7]),
            rate2: Int(report[8])
        )
    }

    private func readJogType(mode: Int) async throws -> Bool {
        let report = try await sendAndWait(report: makeGetJogTypeReport(mode: mode)) {
            $0.first == UInt8(HIDMessage.jogType.rawValue) && Int($0[safe: 2] ?? 255) == mode
        }
        guard report.count >= 4 else {
            throw HIDError.badResponse
        }
        return report[3] != 0
    }

    private func readFirmwareVersion() async throws -> String {
        let report = try await sendAndWait(report: makeSimpleCommand(.getVersion)) {
            $0.first == UInt8(HIDMessage.version.rawValue)
        }
        guard report.count >= 4 else {
            throw HIDError.badResponse
        }
        return "\(report[2]).\(String(format: "%02d", report[3]))"
    }

    private func writeKey(_ assignment: KeyAssignment) throws {
        try sendReport(makeSetKeyReport(assignment: sanitized(assignment)))
    }

    private func writeKeyLabel(_ assignment: KeyAssignment) throws {
        try sendReport(makeSetKeyLabelReport(assignment: assignment))
    }

    private func writeJogData(_ assignment: JogAssignment) throws {
        try sendReport(makeSetJogDataReport(assignment: sanitized(assignment)))
    }

    private func writeJogType(mode: Int, isShuttle: Bool) throws {
        try sendReport(makeSetJogTypeReport(mode: mode, isShuttle: isShuttle))
    }

    private func showError(_ error: Error) {
        alert = AppAlert(title: "DiSE Error", message: error.localizedDescription)
        statusMessage = error.localizedDescription
    }

    private func refreshConfigurationMetadata() {
        ConfigurationMetadataStore.syncLocalLabels(for: configuration)
        configurationSummary = ConfigurationMetadataStore.summary(for: configuration)
        lastProgrammedLabel = ConfigurationMetadataStore.lastProgrammedText(for: configuration)
    }

    private func sanitized(_ assignment: KeyAssignment) -> KeyAssignment {
        var cleaned = assignment
        cleaned.keyID = max(1, min(DiSEProtocol.keyCount, cleaned.keyID))
        cleaned.code = clamp(cleaned.code)
        cleaned.modifiers = clamp(cleaned.modifiers)
        cleaned.group = max(0, min(50, cleaned.group))
        cleaned.alternateType = max(0, min(4, cleaned.alternateType))
        if cleaned.alternateType == AlternateType.none.rawValue {
            cleaned.alternateCode = 0
            cleaned.alternateModifiers = 0
        } else {
            cleaned.alternateCode = clamp(cleaned.alternateCode)
            cleaned.alternateModifiers = clamp(cleaned.alternateModifiers)
        }
        if cleaned.jogSelection == 0 {
            return cleaned
        }
        let mode = max(1, min(DiSEProtocol.jogModeCount, cleaned.jogSelection & 0x0F))
        let temporaryFlag = cleaned.jogSelection & 0x10
        cleaned.jogSelection = mode | temporaryFlag
        return cleaned
    }

    private func sanitized(_ assignment: JogAssignment) -> JogAssignment {
        var cleaned = assignment
        cleaned.mode = max(0, min(DiSEProtocol.jogModeCount - 1, cleaned.mode))
        cleaned.rateSelect = max(0, min(DiSEProtocol.jogRateCount - 1, cleaned.rateSelect))
        cleaned.code = clamp(cleaned.code)
        cleaned.modifiers = clamp(cleaned.modifiers)
        cleaned.rate1 = clamp(cleaned.rate1)
        cleaned.rate2 = clamp(cleaned.rate2)
        return cleaned
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(255, value))
    }

    private func hidMatchScore(for candidate: IOHIDDevice) -> Int {
        let usagePage = intProperty(kIOHIDPrimaryUsagePageKey, on: candidate)
        let usage = intProperty(kIOHIDPrimaryUsageKey, on: candidate)
        let maxInputReportSize = intProperty(kIOHIDMaxInputReportSizeKey, on: candidate) ?? 0
        let maxOutputReportSize = intProperty(kIOHIDMaxOutputReportSizeKey, on: candidate) ?? 0

        var score = 0

        if let usagePage,
           let usage,
           DiSEProtocol.macOSUsagePages.contains(usagePage),
           usage == DiSEProtocol.usage {
            score += 100
        }

        if maxInputReportSize >= DiSEProtocol.reportSize {
            score += 10
        }

        if maxOutputReportSize >= DiSEProtocol.reportSize {
            score += 10
        }

        return score
    }

    private func intProperty(_ key: String, on candidate: IOHIDDevice) -> Int? {
        guard let value = IOHIDDeviceGetProperty(candidate, key as CFString) else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func makeSimpleCommand(_ command: HIDMessage) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(command.rawValue)
        report[1] = 0
        return report
    }

    private func makeGetKeyReport(keyID: Int) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.getKey.rawValue)
        report[1] = 1
        report[2] = UInt8(keyID)
        return report
    }

    private func makeGetKeyLabelReport(keyID: Int) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.getKeyLabel.rawValue)
        report[1] = 1
        report[2] = UInt8(keyID)
        return report
    }

    private func makeSetKeyReport(assignment: KeyAssignment) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.setKey.rawValue)
        report[1] = 8
        report[2] = UInt8(assignment.keyID)
        report[3] = UInt8(assignment.code)
        report[4] = UInt8(assignment.modifiers)
        report[5] = UInt8(assignment.group)
        report[6] = UInt8(assignment.alternateType)
        report[7] = UInt8(assignment.alternateCode)
        report[8] = UInt8(assignment.alternateModifiers)
        report[9] = UInt8(assignment.jogSelection)
        return report
    }

    private func makeSetKeyLabelReport(assignment: KeyAssignment) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.setKeyLabel.rawValue)
        report[1] = UInt8(1 + DiSEProtocol.keyLabelLength)
        report[2] = UInt8(assignment.keyID)

        let labelBytes = normalizedDeviceLabelBytes(for: assignment)
        for (offset, byte) in labelBytes.enumerated() {
            report[3 + offset] = byte
        }
        return report
    }

    private func makeGetJogDataReport(mode: Int, rateSelect: Int, direction: JogDirection) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.getJogData.rawValue)
        report[1] = 3
        report[2] = UInt8(mode)
        report[3] = UInt8(rateSelect)
        report[4] = UInt8(direction.rawValue)
        return report
    }

    private func makeSetJogDataReport(assignment: JogAssignment) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.setJogData.rawValue)
        report[1] = 7
        report[2] = UInt8(assignment.mode)
        report[3] = UInt8(assignment.rateSelect)
        report[4] = UInt8(assignment.direction.rawValue)
        report[5] = UInt8(assignment.code)
        report[6] = UInt8(assignment.modifiers)
        report[7] = UInt8(assignment.rate1)
        report[8] = UInt8(assignment.rate2)
        return report
    }

    private func makeGetJogTypeReport(mode: Int) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.getJogType.rawValue)
        report[1] = 1
        report[2] = UInt8(mode)
        return report
    }

    private func makeSetJogTypeReport(mode: Int, isShuttle: Bool) -> [UInt8] {
        var report = zeroedReport()
        report[0] = UInt8(HIDMessage.setJogType.rawValue)
        report[1] = 2
        report[2] = UInt8(mode)
        report[3] = isShuttle ? 1 : 0
        return report
    }

    private func normalizedDeviceLabelBytes(for assignment: KeyAssignment) -> [UInt8] {
        let source = assignment.customDisplayLabel ?? ""
        let cleaned = source
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let utf8 = Array(cleaned.utf8.prefix(DiSEProtocol.keyLabelLength - 1))
        return utf8 + Array(repeating: 0, count: DiSEProtocol.keyLabelLength - utf8.count)
    }

    private func zeroedReport() -> [UInt8] {
        Array(repeating: 0, count: DiSEProtocol.reportSize)
    }
}

private func hidDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else {
        return
    }
    let controller = Unmanaged<HIDController>.fromOpaque(context).takeUnretainedValue()
    let deviceAddress = UInt(bitPattern: Unmanaged.passRetained(device).toOpaque())
    MainActor.assumeIsolated {
        let retainedDevice = Unmanaged<IOHIDDevice>.fromOpaque(UnsafeMutableRawPointer(bitPattern: deviceAddress)!).takeRetainedValue()
        controller.handleDeviceMatched(retainedDevice)
    }
}

private func hidDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else {
        return
    }
    let controller = Unmanaged<HIDController>.fromOpaque(context).takeUnretainedValue()
    let deviceAddress = UInt(bitPattern: Unmanaged.passRetained(device).toOpaque())
    MainActor.assumeIsolated {
        let retainedDevice = Unmanaged<IOHIDDevice>.fromOpaque(UnsafeMutableRawPointer(bitPattern: deviceAddress)!).takeRetainedValue()
        controller.handleDeviceRemoved(retainedDevice)
    }
}

private func hidInputReportReceived(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    reportType: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, reportLength > 0 else {
        return
    }
    let controller = Unmanaged<HIDController>.fromOpaque(context).takeUnretainedValue()
    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
    MainActor.assumeIsolated {
        controller.handleInputReport(bytes)
    }
}

private extension Array where Element == UInt8 {
    subscript(safe index: Int) -> UInt8? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}

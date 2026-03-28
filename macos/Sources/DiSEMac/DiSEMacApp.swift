import SwiftUI

@main
struct DiSEMacApp: App {
    @StateObject private var controller = HIDController()

    var body: some Scene {
        WindowGroup("DiSE Programmer") {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 1180, minHeight: 780)
        }
    }
}

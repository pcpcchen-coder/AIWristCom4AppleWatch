import SwiftUI

@main
struct AIWristCompanionApp: App {
    @StateObject private var watchSession = WatchSessionManager.shared
    @StateObject private var settings = CompanionSettings.shared

    var body: some Scene {
        WindowGroup {
            CompanionHomeView()
                .environmentObject(watchSession)
                .environmentObject(settings)
        }
    }
}

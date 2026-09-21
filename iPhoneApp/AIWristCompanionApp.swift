import SwiftUI
import UIKit

@MainActor
final class CompanionAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Background WC delivery must not depend on the home view becoming visible.
        _ = WatchSessionManager.shared
        return true
    }
}

@main
struct AIWristCompanionApp: App {
    @UIApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate
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

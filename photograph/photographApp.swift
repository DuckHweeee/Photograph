import FirebaseCore
import SwiftUI

@main
struct PhotographApp: App {
    @StateObject private var model = SpikeModel()

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        // Without GoogleService-Info.plist the UI shows a hint instead of crashing.
        let hasFirebaseConfig = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        if hasFirebaseConfig && !isRunningTests {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeView(model: model)
        }
    }
}

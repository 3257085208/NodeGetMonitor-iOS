import SwiftUI

@main
struct NodeGetMonitorApp: App {
    @StateObject private var serverStore = ServerProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverStore)
        }
    }
}

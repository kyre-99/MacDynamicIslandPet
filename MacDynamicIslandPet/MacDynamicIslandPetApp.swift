import SwiftUI

@main
struct MacDynamicIslandPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 空 Scene，所有逻辑由 AppDelegate 处理
        Settings {
            EmptyView()
        }
    }
}
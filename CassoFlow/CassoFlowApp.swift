import SwiftUI
import MusicKit

@main
struct CassoFlowApp: App {
    @StateObject private var storeManager = StoreManager()
    
    var body: some Scene {
        WindowGroup {
            PlayerView()
                // 注入音乐服务
                .environmentObject(MusicService.shared)
                .environmentObject(storeManager)
        }
    }
}

import SwiftUI
import MusicKit

@main
struct CassoFlowApp: App {
    // 添加音乐服务
    let musicService = MusicService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 注入音乐服务
                .environmentObject(musicService)
        }
    }
}

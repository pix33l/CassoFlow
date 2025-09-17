import SwiftUI
import MusicKit
import UIKit

@main
struct CassoFlowApp: App {
    @StateObject private var storeManager = StoreManager()
    
    var body: some Scene {
        WindowGroup {
            PlayerView()
                // 注入音乐服务
                .environmentObject(MusicService.shared)
                .environmentObject(storeManager)
                // 处理widget的URL Scheme调用
                .onOpenURL { url in
                    handleWidgetURL(url)
                }
        }
    }
    
    // MARK: - Widget URL处理
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "cassoflow" else { return }
        
        // 处理widget控制请求
        if let host = url.host, host == "widget-control" {
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                if let action = queryItems.first(where: { $0.name == "action" })?.value {
                    handleWidgetAction(action)
                }
            }
        }
    }
    
    private func handleWidgetAction(_ action: String) {
        Task {
            switch action {
            case "playPause":
                if MusicService.shared.isPlaying {
                    await MusicService.shared.pause()
                } else {
                    try? await MusicService.shared.play()
                }
            case "nextTrack":
                try? await MusicService.shared.skipToNext()
            case "previousTrack":
                try? await MusicService.shared.skipToPrevious()
            default:
                break
            }
            
            // 立即更新widget显示
            await MainActor.run {
                MusicService.shared.updateWidgetData()
            }
        }
    }
}

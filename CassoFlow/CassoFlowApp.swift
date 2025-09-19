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
//                // 处理widget的URL Scheme调用
//                .onOpenURL { url in
//                    handleWidgetURL(url)
                }
        }
    }
    
//    // MARK: - Widget URL处理
//    private func handleWidgetURL(_ url: URL) {
//        guard url.scheme == "cassoflow" else { return }
//        
//        // 处理widget控制请求
//        if let host = url.host, host == "widget-control" {
//            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
//                if let action = queryItems.first(where: { $0.name == "action" })?.value {
//                    // 立即处理Widget控制操作
//                    handleWidgetAction(action)
////                    
////                    // 即使应用在后台，也确保音乐控制操作能够执行
////                    DispatchQueue.global(qos: .userInitiated).async {
////                        Task {
////                            // 延迟一下确保共享存储已经更新
////                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
////                            await MainActor.run {
////                                // 再次检查是否有Widget控制操作需要处理
////                                MusicService.shared.checkWidgetControlActions()
////                            }
////                        }
////                    }
//                }
//            }
//        }
//    }
//    
//    private func handleWidgetAction(_ action: String) {
//        Task {
//            switch action {
//            case "playPause":
//                if MusicService.shared.isPlaying {
//                    await MusicService.shared.pause()
//                } else {
//                    try? await MusicService.shared.play()
//                }
//            case "nextTrack":
//                try? await MusicService.shared.skipToNext()
//            case "previousTrack":
//                try? await MusicService.shared.skipToPrevious()
//            default:
//                break
//            }
//            
//            // 立即更新widget显示
//            await MainActor.run {
//                MusicService.shared.updateWidgetData()
//            }
//        }
//    }
//}

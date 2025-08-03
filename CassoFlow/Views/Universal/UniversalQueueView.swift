import SwiftUI

/// 统一播放队列视图路由器 - 根据当前数据源自动切换到对应的视图
struct UniversalQueueView: View {
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        Group {
            switch musicService.currentDataSource {
            case .musicKit:
                // 使用Apple Music队列视图
                QueueView()
            case .subsonic:
                // 使用Subsonic队列视图
                SubsonicQueueView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: musicService.currentDataSource)
    }
}

// MARK: - 预览

struct UniversalQueueView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Apple Music数据源预览
            UniversalQueueView()
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .musicKit
                    return service
                }())
                .previewDisplayName("Apple Music 队列")
            
            // Subsonic数据源预览
            UniversalQueueView()
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .subsonic
                    return service
                }())
                .previewDisplayName("Subsonic 队列")
        }
    }
}
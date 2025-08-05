import SwiftUI

/// 统一音乐库视图路由器 - 根据当前数据源自动切换到对应的视图
struct UniversalLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        Group {
            switch musicService.currentDataSource {
            case .musicKit:
                // 使用Apple Music音乐库视图
                LibraryView()
            case .subsonic:
                // 使用Subsonic音乐库视图
                SubsonicLibraryView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: musicService.currentDataSource)
    }
}

// MARK: - 预览

struct UniversalLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Apple Music数据源预览
            UniversalLibraryView()
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .musicKit
                    return service
                }())
                .previewDisplayName("Apple Music")
            
            // Subsonic数据源预览
            UniversalLibraryView()
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .subsonic
                    return service
                }())
                .previewDisplayName("Subsonic")
        }
    }
}

import AppIntents
import Foundation

/// Widget配置意图
struct CassFlowWidgetConfiguration: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "CassFlow Widget配置"
    static var description = IntentDescription("配置CassFlow音乐播放器widget")
    
    // 可以添加配置参数，比如显示样式等
    @Parameter(title: "显示控制按钮", default: true)
    var showControls: Bool
    
    init() {}
    
    init(showControls: Bool) {
        self.showControls = showControls
    }
}

/// 音乐控制意图
struct PlayPauseMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "播放/暂停音乐"
    static var description = IntentDescription("控制音乐播放或暂停")
    
    func perform() async throws -> some IntentResult {
        // 保存控制操作到共享存储
        UserDefaults.saveMusicControlAction(.playPause)
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "下一首"
    static var description = IntentDescription("播放下一首歌曲")
    
    func perform() async throws -> some IntentResult {
        UserDefaults.saveMusicControlAction(.nextTrack)
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "上一首"
    static var description = IntentDescription("播放上一首歌曲")
    
    func perform() async throws -> some IntentResult {
        UserDefaults.saveMusicControlAction(.previousTrack)
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

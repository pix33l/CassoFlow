//
//  WidgetUpdateManager.swift
//  CassFlowWidget
//
//  Created by Zhang Shensen on 2025/9/18.
//

import Foundation
import WidgetKit

/// Widget更新管理器，负责处理Widget的自动更新
class WidgetUpdateManager {
    
    static let shared = WidgetUpdateManager()
    
    private init() {}
    
    /// 主动刷新所有Widget
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetUpdateManager: 已刷新所有Widget")
    }
    
    /// 刷新特定类型的Widget
    func reloadWidget(ofKind kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("WidgetUpdateManager: 已刷新类型为 \(kind) 的Widget")
    }
    
    /// 当音乐播放状态变化时调用
    func musicPlaybackStateChanged(isPlaying: Bool) {
        // 如果音乐开始播放，更频繁地更新Widget
        if isPlaying {
            // 立即刷新一次
            reloadAllWidgets()
            
            // 设置一个定时器，在播放期间定期更新Widget
            schedulePeriodicUpdates()
        } else {
            // 音乐暂停时，停止定期更新
            cancelPeriodicUpdates()
            
            // 暂停时也刷新一次，确保显示正确的暂停状态
            reloadAllWidgets()
        }
    }
    
    /// 当歌曲信息变化时调用
    func musicInfoChanged() {
        // 歌曲信息变化时立即刷新Widget
        reloadAllWidgets()
    }
    
    /// 当播放进度变化时调用
    func playbackProgressChanged() {
        // 播放进度变化时刷新Widget
        reloadAllWidgets()
    }
    
    // MARK: - 定期更新管理
    
    private var periodicUpdateTimer: Timer?
    
    /// 设置定期更新
    private func schedulePeriodicUpdates() {
        // 取消之前的定时器
        cancelPeriodicUpdates()
        
        // 在播放期间每3秒更新一次Widget
        periodicUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.reloadAllWidgets()
        }
    }
    
    /// 取消定期更新
    private func cancelPeriodicUpdates() {
        periodicUpdateTimer?.invalidate()
        periodicUpdateTimer = nil
    }
}
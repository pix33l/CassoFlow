import Foundation
import AVFoundation
import MediaPlayer

/// 统一音频会话管理器 - 基于2024年最佳实践
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    // MARK: - 当前活跃服务
    private var activeService: ActiveMusicService?
    
    // 活跃服务类型
    enum ActiveMusicService {
        case subsonic
        case audioStation
        case musicKit
        case local
    }
    
    private init() {
        setupAudioSessionNotifications()
    }
    
    // MARK: - 音频会话控制
    
    /// 请求独占音频会话控制权（中断其他音乐应用）
    func requestAudioSession(for service: ActiveMusicService) -> Bool {
        print("🎵 \(service) 请求独占音频会话控制权")
        
        // 🔑 重要：每次都重新配置，确保强制中断
        let previousService = activeService
        activeService = service
        
        if let previous = previousService, previous != service {
            print("🔄 切换音频服务: \(previous) -> \(service)")
        }
        
        // 🔑 使用2024年最佳实践配置
        return setupExclusiveAudioSession(for: service)
    }
    
    /// 释放音频会话控制权
    func releaseAudioSession(for service: ActiveMusicService) {
        guard activeService == service else { 
            print("⚠️ \(service) 尝试释放不属于它的音频会话")
            return 
        }
        
        print("🔄 \(service) 释放音频会话控制权")
        activeService = nil
        
        // 优雅地停用音频会话，通知其他应用可以恢复
        deactivateAudioSession()
    }
    
    /// 获取当前活跃服务
    func getCurrentActiveService() -> ActiveMusicService? {
        return activeService
    }
    
    // MARK: - 🔑 2024年最佳实践：独占音频会话配置
    
    private func setupExclusiveAudioSession(for service: ActiveMusicService) -> Bool {
        print("🔧 为 \(service) 配置独占音频会话（2024最佳实践）")
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 🔑 步骤1：配置独占播放类别，关键是不使用任何混音选项
            print("   步骤1: 设置独占播放类别")
            try session.setCategory(.playback, mode: .default, options: [])
            
            // 🔑 步骤2：激活会话，这会自动中断其他音乐应用
            print("   步骤2: 激活音频会话（将中断其他音乐应用）")
            try session.setActive(true)
            
            // 🔑 步骤3：启用远程控制
            DispatchQueue.main.async {
                UIApplication.shared.beginReceivingRemoteControlEvents()
            }
            
            // 🔑 验证配置
            print("✅ \(service) 独占音频会话配置成功")
            print("   类别: \(session.category.rawValue)")
            print("   模式: \(session.mode.rawValue)")
            print("   选项: \(session.categoryOptions)")
            print("   其他音频播放状态: \(session.isOtherAudioPlaying)")
            
            if session.isOtherAudioPlaying {
                print("⚠️ 警告：仍有其他音频在播放，可能需要额外处理")
            } else {
                print("✅ 成功获得独占音频控制权")
            }
            
            return true
            
        } catch let error {
            print("❌ \(service) 独占音频会话配置失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 音频会话中断处理
    
    private func setupAudioSessionNotifications() {
        // 🔑 中断通知 - 处理来电等系统中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // 🔑 路由变化通知 - 处理耳机插拔等
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🔔 音频会话中断: \(type == .began ? "开始" : "结束")")
        
        switch type {
        case .began:
            print("⏸️ 音频中断开始（来电、Siri等），当前服务: \(activeService?.description ?? "无")")
            // 系统级中断，应该暂停播放
            
        case .ended:
            print("▶️ 音频中断结束")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔄 系统建议恢复播放")
                    // 重新激活音频会话并恢复播放
                    if let service = activeService {
                        _ = setupExclusiveAudioSession(for: service)
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔄 音频路由变化: \(reason.rawValue)")
        
        switch reason {
        case .oldDeviceUnavailable:
            print("🎧 音频设备断开连接（如耳机拔出）")
            // 可能需要暂停播放
        case .newDeviceAvailable:
            print("🎧 新音频设备连接")
        default:
            break
        }
    }
    
    // MARK: - 私有方法
    
    private func deactivateAudioSession() {
        do {
            // 🔑 使用 notifyOthersOnDeactivation 让其他应用知道可以恢复播放
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            print("✅ 音频会话已停用，通知其他应用可以恢复播放")
        } catch {
            print("❌ 停用音频会话失败: \(error.localizedDescription)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 扩展：服务描述

extension AudioSessionManager.ActiveMusicService {
    var description: String {
        switch self {
        case .subsonic:
            return "Subsonic"
        case .audioStation:
            return "AudioStation"
        case .musicKit:
            return "MusicKit"
        case .local:
            return "本地音乐"
        }
    }
}
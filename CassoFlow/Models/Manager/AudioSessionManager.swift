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
        case local
    }
    
    private init() {
        setupAudioSessionNotifications()
    }
    
    // MARK: - 音频会话控制
    
    /// 请求独占音频会话控制权（中断其他音乐应用）
    func requestAudioSession(for service: ActiveMusicService) -> Bool {
        // 🔑 重要：每次都重新配置，确保强制中断
        let previousService = activeService
        activeService = service
        
        if let previous = previousService, previous != service {
            print("🔍 AudioSession: 切换服务 \(previous) -> \(service)")
        }
        
        // 🔑 关键修复：添加重试机制，确保音频会话配置成功
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            let success = setupExclusiveAudioSession(for: service)
            if success {
                print("🔍 AudioSession: 音频会话配置成功，重试次数: \(retryCount)")
                return true
            } else {
                retryCount += 1
                print("🔍 AudioSession: 音频会话配置失败，重试 \(retryCount)/\(maxRetries)")
                
                // 等待一段时间再重试
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        print("🔍 AudioSession: 音频会话配置最终失败")
        return false
    }
    
    /// 释放音频会话控制权
    func releaseAudioSession(for service: ActiveMusicService) {
        guard activeService == service else {
            print("🔍 AudioSession: \(service) 尝试释放不属于它的音频会话")
            return
        }
        
        print("🔍 AudioSession: \(service) 释放音频会话")
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
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 🔑 步骤1：先尝试停用当前会话，通知其他应用
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            
            // 🔑 步骤2：配置独占播放类别，关键是不使用任何混音选项
            try session.setCategory(.playback, mode: .default, options: [])
            
            // 🔑 步骤3：强制激活会话，这会自动中断其他音乐应用
            try session.setActive(true, options: [])
            
            // 🔑 步骤4：验证其他音频是否已停止
            if session.isOtherAudioPlaying {
                print("🔍 AudioSession: 检测到其他音频，尝试中断")
                
                // 再次尝试停用并激活
                try? session.setActive(false, options: [.notifyOthersOnDeactivation])
                Thread.sleep(forTimeInterval: 0.1) // 使用同步延迟
                try session.setActive(true, options: [])
                
                if session.isOtherAudioPlaying {
                    print("🔍 AudioSession: 警告 - 无法完全停止其他音频")
                } else {
                    print("🔍 AudioSession: 成功中断其他音频")
                }
            }
            
            // 🔑 步骤5：启用远程控制
            DispatchQueue.main.async {
                UIApplication.shared.beginReceivingRemoteControlEvents()
            }
            
            // 🔑 验证配置
            print("🔍 AudioSession: \(service) 配置成功，其他音频: \(session.isOtherAudioPlaying)")
            
            return true
            
        } catch let error {
            print("🔍 AudioSession: \(service) 配置失败 - \(error.localizedDescription)")
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
        
        // 🔑 新增：媒体服务重置通知 - 处理其他音乐应用启动
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        
        // 🔑 新增：静默切换通知 - 处理其他应用抢夺音频控制权
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSilenceSecondaryAudioHint),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🔍 AudioSession: 中断 \(type == .began ? "开始" : "结束")")
        
        switch type {
        case .began:
            print("🔍 AudioSession: 中断开始，服务: \(activeService?.description ?? "无")")
            // 🔑 关键：通知当前活跃服务停止播放
            self.notifyActiveServiceToStop()
            
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔍 AudioSession: 系统建议恢复播放")
                    // 重新激活音频会话并恢复播放
                    if let service = activeService {
                        _ = setupExclusiveAudioSession(for: service)
                        self.notifyActiveServiceToResume()
                    }
                } else {
                    print("🔍 AudioSession: 系统不建议恢复播放")
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
        
        print("🔍 AudioSession: 路由变化 \(reason.rawValue)")
        
        switch reason {
        case .oldDeviceUnavailable:
            print("🔍 AudioSession: 设备断开")
            // 可能需要暂停播放
        case .newDeviceAvailable:
            print("🔍 AudioSession: 新设备连接")
        default:
            break
        }
    }
    
    // MARK: - 🔑 新增：服务通知方法
    
    /// 通知当前活跃服务停止播放
    private func notifyActiveServiceToStop() {
        guard let service = activeService else { return }
        
        print("🔍 AudioSession: 通知 \(service) 停止播放")
        
        // 发送通知给相应的服务
        let notificationName: Notification.Name
        switch service {
        case .subsonic:
            notificationName = .subsonicShouldStopPlaying
        case .audioStation:
            notificationName = .audioStationShouldStopPlaying
        case .local:
            notificationName = .localMusicShouldStopPlaying
        }
        
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
    
    /// 通知当前活跃服务恢复播放
    private func notifyActiveServiceToResume() {
        guard let service = activeService else { return }
        
        print("🔍 AudioSession: 通知 \(service) 恢复播放")
        
        // 发送通知给相应的服务
        let notificationName: Notification.Name
        switch service {
        case .subsonic:
            notificationName = .subsonicShouldResumePlaying
        case .audioStation:
            notificationName = .audioStationShouldResumePlaying
        case .local:
            notificationName = .localMusicShouldResumePlaying
        }
        
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
    
    // MARK: - 私有方法
    
    private func deactivateAudioSession() {
        do {
            // 🔑 使用 notifyOthersOnDeactivation 让其他应用知道可以恢复播放
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            print("🔍 AudioSession: 会话已停用")
        } catch {
            print("🔍 AudioSession: 停用失败 - \(error.localizedDescription)")
        }
    }
    
    /// 🔑 新增：处理媒体服务重置
    @objc private func handleMediaServicesReset(_ notification: Notification) {
        print("🔍 AudioSession: 媒体服务重置")
        // 当其他音乐应用启动时，停止我们的播放
        self.notifyActiveServiceToStop()
    }
    
    /// 🔑 新增：处理静默提示（其他应用要求我们降低音量或停止）
    @objc private func handleSilenceSecondaryAudioHint(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .begin:
            print("🔍 AudioSession: 其他应用请求静默")
            // 🔑 关键：立即停止播放，让位给其他应用
            self.notifyActiveServiceToStop()
            
        case .end:
            print("🔍 AudioSession: 其他应用允许恢复")
            // 可以选择恢复播放，但通常不自动恢复
            
        @unknown default:
            break
        }
    }
    
    // MARK: - 🔑 新增：前台音频会话维护
    
    /// 确保音频会话在前台时保持活跃状态
    func ensureForegroundAudioSession() -> Bool {
        guard activeService != nil else {
            print("🔍 AudioSession: 无活跃服务，无法确保前台会话")
            return false
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 🔑 修改：更加温和地处理音频会话，避免不必要的中断
            // 首先检查会话是否已经处于正确状态
            if session.category == .playback {
                // 只需确保远程控制启用
                DispatchQueue.main.async {
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                }
                return true
            }
            
            // 如果会话类别不正确，温和地重新配置
            if session.category != .playback {
                try session.setCategory(.playback, mode: .default, options: [])
                // 不需要立即重新激活，避免中断
            }
            
            // 确保远程控制启用
            DispatchQueue.main.async {
                UIApplication.shared.beginReceivingRemoteControlEvents()
            }
            
            print("🔍 AudioSession: 前台会话确认完成")
            return true
            
        } catch let error {
            print("🔍 AudioSession: 前台会话失败 - \(error.localizedDescription)")
            return false
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
        case .local:
            return "本地音乐"
        }
    }
}

// MARK: - 🔑 新增：通知名称定义

extension Notification.Name {
    static let subsonicShouldStopPlaying = Notification.Name("SubsonicShouldStopPlaying")
    static let subsonicShouldResumePlaying = Notification.Name("SubsonicShouldResumePlaying")
    
    static let audioStationShouldStopPlaying = Notification.Name("AudioStationShouldStopPlaying")
    static let audioStationShouldResumePlaying = Notification.Name("AudioStationShouldResumePlaying")
    
    static let localMusicShouldStopPlaying = Notification.Name("LocalMusicShouldStopPlaying")
    static let localMusicShouldResumePlaying = Notification.Name("LocalMusicShouldResumePlaying")
}

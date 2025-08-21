import Foundation
import AVFoundation
import MediaPlayer

/// 统一音频会话管理器 - 解决多音乐服务冲突问题
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
    
    private init() {}
    
    // MARK: - 音频会话控制
    
    /// 请求音频会话控制权
    func requestAudioSession(for service: ActiveMusicService) -> Bool {
        // 如果已经是当前活跃服务，直接返回成功
        if activeService == service {
            print("✅ \(service) 已拥有音频会话控制权")
            return true
        }
        
        // 停用其他服务的音频会话
        deactivateCurrentService()
        
        // 设置新的活跃服务
        activeService = service
        
        // 配置音频会话
        return setupAudioSession(for: service)
    }
    
    /// 释放音频会话控制权
    func releaseAudioSession(for service: ActiveMusicService) {
        guard activeService == service else { return }
        
        print("🔄 \(service) 释放音频会话控制权")
        activeService = nil
        
        // 停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ 停用音频会话失败: \(error)")
        }
    }
    
    /// 获取当前活跃服务
    func getCurrentActiveService() -> ActiveMusicService? {
        return activeService
    }
    
    // MARK: - 私有方法
    
    private func deactivateCurrentService() {
        guard let current = activeService else { return }
        print("🔄 停用当前音频会话: \(current)")
        
        // 先停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ 停用音频会话失败: \(error)")
        }
    }
    
    private func setupAudioSession(for service: ActiveMusicService) -> Bool {
        print("🔧 为 \(service) 设置音频会话")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 设置音频会话类别
            try audioSession.setCategory(.playback, 
                                       mode: .default, 
                                       options: [.allowAirPlay, .allowBluetooth, .interruptSpokenAudioAndMixWithOthers])
            
            // 激活音频会话
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            // 开始接收远程控制事件
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            print("✅ \(service) 音频会话设置成功")
            return true
            
        } catch {
            print("❌ \(service) 音频会话设置失败: \(error)")
            return false
        }
    }
}

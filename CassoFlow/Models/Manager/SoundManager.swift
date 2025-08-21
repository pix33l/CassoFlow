//
//  SoundManager.swift
//  CassoFlow
//
//  Created by AI Assistant on 2025/6/17.
//

import SwiftUI
import AVFoundation

/// 音效管理器 - 负责管理应用中的所有音效
class SoundManager: ObservableObject {
    
    // MARK: - 音效类型枚举
    enum SoundEffect: String, CaseIterable {
        case button = "button"        // 按钮点击音效
        case eject = "eject"          // 弹出音效
        // case success = "success"
        // case error = "error"
        
        var fileName: String {
            return self.rawValue
        }
        
        var fileExtension: String {
            return "m4a"
        }
        
        var volume: Float {
            switch self {
            case .button:
                return 0.2
            case .eject:
                return 0.2
            }
        }
    }
    
    // MARK: - 音效播放器字典
    private var audioPlayers: [SoundEffect: AVAudioPlayer] = [:]
    
    // MARK: - 单例
    static let shared = SoundManager()
    
    private init() {
        // 完全移除音频会话配置
        setupAudioPlayers()
    }
    
    // MARK: - 初始化音效播放器
    private func setupAudioPlayers() {
        print("🔊 开始初始化音效播放器...")
        
        for effect in SoundEffect.allCases {
            guard let soundURL = Bundle.main.url(forResource: effect.fileName, withExtension: effect.fileExtension) else {
                print("⚠️ 未找到音效文件: \(effect.fileName).\(effect.fileExtension)")
                continue
            }
            
            print("🔊 找到音效文件: \(soundURL)")
            
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                player.volume = effect.volume
                audioPlayers[effect] = player
                print("✅ 成功加载音效: \(effect.fileName)")
            } catch {
                print("❌ 音效初始化失败: \(effect.fileName) - \(error.localizedDescription)")
            }
        }
        
        print("🔊 音效播放器初始化完成，共加载 \(audioPlayers.count) 个音效")
    }
    
    // MARK: - 播放音效
    func playSound(_ effect: SoundEffect) {
        guard let player = audioPlayers[effect] else {
            print("❌ 未找到音效播放器: \(effect.fileName)")
            return
        }
        
        // 完全移除音频会话配置，直接播放
        player.stop()
        player.currentTime = 0
        player.play()
        
        print("🔊 播放音效: \(effect.fileName)")
    }
    
    // MARK: - 设置音效音量
    func setVolume(_ volume: Float, for effect: SoundEffect) {
        guard let player = audioPlayers[effect] else { return }
        player.volume = max(0.0, min(1.0, volume)) // 确保音量在0-1范围内
    }
    
    // MARK: - 设置所有音效音量
    func setGlobalVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        for (effect, player) in audioPlayers {
            player.volume = clampedVolume * effect.volume // 保持相对音量比例
        }
    }
    
    // MARK: - 预加载音效（可选）
    func preloadSound(_ effect: SoundEffect) {
        audioPlayers[effect]?.prepareToPlay()
    }
    
    // MARK: - 检查音效是否可用
    func isSoundAvailable(_ effect: SoundEffect) -> Bool {
        return audioPlayers[effect] != nil
    }
}

// MARK: - SwiftUI 视图扩展
extension View {
    /// 为按钮添加音效
    func buttonSound(_ effect: SoundManager.SoundEffect) -> some View {
        self.modifier(ButtonSoundModifier(effect: effect))
    }
}

// MARK: - 按钮音效修饰符
struct ButtonSoundModifier: ViewModifier {
    let effect: SoundManager.SoundEffect
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        SoundManager.shared.playSound(effect)
                    }
            )
    }
}

// MARK: - 音效按钮修饰符
struct SoundEffectButtonStyle: ButtonStyle {
    let soundEffect: SoundManager.SoundEffect
    
    init(soundEffect: SoundManager.SoundEffect) {
        self.soundEffect = soundEffect
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                // 在按下时播放音效（从false变为true）
                if !oldValue && newValue {
                    SoundManager.shared.playSound(soundEffect)
                }
            }
    }
}

import AVFoundation
import Combine
import Foundation

/// 音频效果管理器
class AudioEffectsManager: ObservableObject {
    static let shared = AudioEffectsManager()
    
    private var audioEngine: AVAudioEngine
    private var noisePlayer: AVAudioPlayerNode
    private var mixerNode: AVAudioMixerNode
    
    @Published var isCassetteEffectEnabled: Bool = false
    @Published var isMusicPlaying: Bool = false {
        didSet {
            updateCassetteEffect()
        }
    }
    
    // 磁带音效音频文件
    private var cassetteNoiseBuffer: AVAudioPCMBuffer?
    
    private init() {
        audioEngine = AVAudioEngine()
        noisePlayer = AVAudioPlayerNode()
        mixerNode = AVAudioMixerNode()
        
        setupAudioSession()
        setupAudioEngine()
        loadCassetteNoiseAudio()
        loadSettings()
        setupAudioEngineObservers()
    }
    
    /// 配置音频会话以允许与 MusicKit 共存
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 使用 .playback 类别，允许背景播放并与其他音频混合
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("🎵 音频会话配置成功 - 支持音频混合")
        } catch {
            print("🎵 音频会话配置失败: \(error)")
        }
    }
    
    /// 设置音频引擎监听器
    private func setupAudioEngineObservers() {
        // 监听音频引擎配置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: audioEngine
        )
        
        // 监听音频会话中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleConfigurationChange() {
        print("🎵 音频引擎配置发生变化，重新启动...")
        restartAudioEngine()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🎵 音频会话中断开始")
            stopCassetteEffect()
        case .ended:
            print("🎵 音频会话中断结束")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🎵 恢复音频播放")
                    restartAudioEngine()
                }
            }
        @unknown default:
            break
        }
    }
    
    /// 重新启动音频引擎
    private func restartAudioEngine() {
        audioEngine.stop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                try self.audioEngine.start()
                print("🎵 音频引擎重新启动成功")
                
                // 如果之前在播放磁带音效，重新开始
                if self.isCassetteEffectEnabled && self.isMusicPlaying {
                    self.startCassetteEffect()
                }
            } catch {
                print("🎵 音频引擎重新启动失败: \(error)")
            }
        }
    }
    
    /// 设置音频引擎
    private func setupAudioEngine() {
        // 添加节点到音频引擎
        audioEngine.attach(noisePlayer)
        audioEngine.attach(mixerNode)
        
        // 获取输出格式
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        
        // 连接节点 - 确保格式兼容
        audioEngine.connect(noisePlayer, to: mixerNode, format: outputFormat)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: outputFormat)
        
        // 设置音量
        noisePlayer.volume = 0.5 // 磁带音效音量
        
        // 准备音频引擎
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            print("🎵 音频引擎启动成功")
        } catch {
            print("🎵 音频引擎启动失败: \(error)")
        }
    }
    
    /// 加载磁带噪音音频
    private func loadCassetteNoiseAudio() {
        // 生成程序化的磁带噪音
        generateCassetteNoise()
    }
    
    /// 生成磁带噪音音频缓冲区
    private func generateCassetteNoise() {
        // 使用与音频引擎输出相同的格式
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channels = outputFormat.channelCount
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
            print("🎵 无法创建音频格式")
            return
        }
        
        let frameCount = AVAudioFrameCount(sampleRate * 3) // 3秒的音频
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("🎵 无法创建音频缓冲区")
            return
        }
        
        buffer.frameLength = frameCount
        
        // 生成白噪音和磁带特有的嘶嘶声
        guard let channelData = buffer.floatChannelData else {
            print("🎵 无法获取音频通道数据")
            return
        }
        
        for channel in 0..<Int(channels) {
            let channelBuffer = channelData[channel]
            
            for frame in 0..<Int(frameCount) {
                // 生成白噪音 (-1 到 1 之间的随机值)
                let whiteNoise = Float.random(in: -0.06...0.06)
                
                // 添加低频抖动效果 (磁带的慢速度变化)
                let flutter = sin(Float(frame) * 0.0008) * 0.02
                
                // 添加中频磁带摩擦声
                let tape_friction = sin(Float(frame) * 0.02) * 0.015
                
                // 添加高频嘶嘶声
                let hiss = Float.random(in: -0.01...0.01)
                
                // 偶尔的噪点 (模拟磁带瑕疵)
                let crackle = (Float.random(in: 0...1) > 0.998) ? Float.random(in: -0.08...0.08) : 0.0
                
                let sample = whiteNoise + flutter + tape_friction + hiss + crackle
                channelBuffer[frame] = sample * 0.5 // 整体降低音量
            }
        }
        
        cassetteNoiseBuffer = buffer
        print("🎵 磁带噪音音频生成完成 (采样率: \(sampleRate), 通道数: \(channels))")
    }
    
    /// 更新磁带效果
    private func updateCassetteEffect() {
        // 只有当磁带音效开启且音乐正在播放时才播放噪音
        if isCassetteEffectEnabled && isMusicPlaying {
            startCassetteEffect()
        } else {
            stopCassetteEffect()
        }
        
        let status = (isCassetteEffectEnabled && isMusicPlaying) ? "播放中" : "已停止"
        print("🎵 磁带音效状态: \(status) (音效开关: \(isCassetteEffectEnabled), 音乐播放: \(isMusicPlaying))")
    }
    
    /// 开始播放磁带效果
    private func startCassetteEffect() {
        guard let buffer = cassetteNoiseBuffer else {
            print("🎵 磁带噪音缓冲区未准备好")
            return
        }
        
        // 确保音频引擎正在运行
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("🎵 重新启动音频引擎")
            } catch {
                print("🎵 无法启动音频引擎: \(error)")
                return
            }
        }
        
        // 如果已经在播放，直接返回
        if noisePlayer.isPlaying {
            print("🎵 磁带音效已在播放中")
            return
        }
        
        // 停止之前的播放并清除缓冲区
        noisePlayer.stop()
        
        // 循环播放噪音
        noisePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        
        noisePlayer.play()
        print("🎵 开始播放磁带噪音效果 (音量: \(noisePlayer.volume))")
    }
    
    /// 停止磁带效果
    private func stopCassetteEffect() {
        if noisePlayer.isPlaying {
            noisePlayer.stop()
            print("🎵 停止磁带噪音效果")
        }
    }
    
    /// 从 UserDefaults 加载设置
    private func loadSettings() {
        isCassetteEffectEnabled = UserDefaults.standard.bool(forKey: "CassetteEffectEnabled")
        print("🎵 加载磁带音效设置: \(isCassetteEffectEnabled)")
    }
    
    /// 设置磁带效果开关
    func setCassetteEffect(enabled: Bool) {
        isCassetteEffectEnabled = enabled
        updateCassetteEffect()
    }
    
    /// 设置音乐播放状态
    func setMusicPlayingState(_ isPlaying: Bool) {
        print("🎵 更新音乐播放状态: \(isMusicPlaying) -> \(isPlaying)")
        isMusicPlaying = isPlaying
    }
    
    /// 调整磁带噪音音量
    func setCassetteNoiseVolume(_ volume: Float) {
        noisePlayer.volume = max(0.0, min(1.0, volume))
        print("🎵 设置磁带噪音音量: \(volume)")
    }
    
    /// 清理资源
    deinit {
        NotificationCenter.default.removeObserver(self)
        audioEngine.stop()
        print("🎵 音频效果管理器已清理")
    }
}

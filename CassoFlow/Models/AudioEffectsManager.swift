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
        } catch {
            // 音频会话配置失败，静默处理
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
            stopCassetteEffect()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
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
                
                // 如果之前在播放磁带音效，重新开始
                if self.isCassetteEffectEnabled && self.isMusicPlaying {
                    self.startCassetteEffect()
                }
            } catch {
                // 音频引擎重新启动失败，静默处理
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
        
        // 初始音量设为0，等待用户设置或加载保存的设置
        noisePlayer.volume = 0.0
        
        // 准备音频引擎
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            // 音频引擎启动失败，静默处理
        }
    }
    
    /// 加载磁带噪音音频
    private func loadCassetteNoiseAudio() {
        // 生成程序化的磁带噪音
        generateCassetteNoise()
    }
    
    /// 生成磁带噪音音频缓冲区 - 支持自定义参数
    func regenerateCassetteNoise(
        whiteNoiseRange: Float = 0.06,
        flutterAmplitude: Float = 0.02,
        flutterFrequency: Float = 0.0008,
        frictionAmplitude: Float = 0.015,
        frictionFrequency: Float = 0.02,
        hissRange: Float = 0.01,
        crackleThreshold: Float = 0.998,
        crackleRange: Float = 0.08
    ) {
        // 使用与音频引擎输出相同的格式
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channels = outputFormat.channelCount
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
            return
        }
        
        let frameCount = AVAudioFrameCount(sampleRate * 3) // 3秒的音频
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        
        buffer.frameLength = frameCount
        
        // 生成白噪音和磁带特有的嘶嘶声
        guard let channelData = buffer.floatChannelData else {
            return
        }
        
        for channel in 0..<Int(channels) {
            let channelBuffer = channelData[channel]
            
            for frame in 0..<Int(frameCount) {
                // 生成白噪音 (使用自定义范围)
                let whiteNoise = Float.random(in: -whiteNoiseRange...whiteNoiseRange)
                
                // 添加低频抖动效果 (磁带的慢速度变化) - 使用自定义参数
                let flutter = sin(Float(frame) * flutterFrequency) * flutterAmplitude
                
                // 添加中频磁带摩擦声 - 使用自定义参数
                let tape_friction = sin(Float(frame) * frictionFrequency) * frictionAmplitude
                
                // 添加高频嘶嘶声 - 使用自定义范围
                let hiss = Float.random(in: -hissRange...hissRange)
                
                // 偶尔的噪点 (模拟磁带瑕疵) - 使用自定义参数
                let crackle = (Float.random(in: 0...1) > crackleThreshold) ? Float.random(in: -crackleRange...crackleRange) : 0.0
                
                let sample = whiteNoise + flutter + tape_friction + hiss + crackle
                channelBuffer[frame] = sample * 0.5 // 固定整体音量为0.5
            }
        }
        
        cassetteNoiseBuffer = buffer
        
        // 如果当前正在播放音效，重新开始播放新的缓冲区
        if noisePlayer.isPlaying {
            noisePlayer.stop()
            if isCassetteEffectEnabled && isMusicPlaying {
                startCassetteEffect()
            }
        }
    }
    
    /// 生成磁带噪音音频缓冲区 - 使用默认参数
    private func generateCassetteNoise() {
        regenerateCassetteNoise()
    }
    
    /// 更新磁带效果
    private func updateCassetteEffect() {
        // 确定目标状态
        let shouldPlay = isCassetteEffectEnabled && isMusicPlaying
        
        // 只有当磁带音效开启且音乐正在播放时才播放噪音
        if shouldPlay {
            startCassetteEffect()
        } else {
            stopCassetteEffect()
        }
    }
    
    /// 开始播放磁带效果
    private func startCassetteEffect() {
        guard let buffer = cassetteNoiseBuffer else {
            return
        }
        
        // 确保音频引擎正在运行
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                return
            }
        }
        
        // 如果已经在播放，先停止再重新开始
        if noisePlayer.isPlaying {
            noisePlayer.stop()
        }
        
        // 清除之前的缓冲区调度
        noisePlayer.reset()
        
        // 循环播放噪音
        noisePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        
        noisePlayer.play()
    }
    
    /// 停止磁带效果
    private func stopCassetteEffect() {
        if noisePlayer.isPlaying {
            noisePlayer.stop()
        }
    }
    
    /// 从 UserDefaults 加载设置
    private func loadSettings() {
        // 加载保存的音量设置，如果没有则使用默认值0.5
        let savedVolume = UserDefaults.standard.object(forKey: "CassetteEffectVolume") as? Float ?? 0.5
        noisePlayer.volume = savedVolume
    }
    
    /// 设置磁带效果开关
    func setCassetteEffect(enabled: Bool) {
        isCassetteEffectEnabled = enabled
        updateCassetteEffect()
    }
    
    /// 设置音乐播放状态
    func setMusicPlayingState(_ isPlaying: Bool) {
        guard isMusicPlaying != isPlaying else { return }
        
        isMusicPlaying = isPlaying
    }
    
    /// 调整磁带噪音音量
    func setCassetteNoiseVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        noisePlayer.volume = clampedVolume
        
        // 保存到UserDefaults
        UserDefaults.standard.set(clampedVolume, forKey: "CassetteEffectVolume")
    }
    
    /// 清理资源
    deinit {
        NotificationCenter.default.removeObserver(self)
        audioEngine.stop()
    }
}

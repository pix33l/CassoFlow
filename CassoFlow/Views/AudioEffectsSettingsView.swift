import SwiftUI

struct AudioEffectsSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var audioEffectsManager = AudioEffectsManager.shared
    
    // 音效参数状态
    @State private var whiteNoiseRange: Float = 0.06
    @State private var flutterAmplitude: Float = 0.02
    @State private var flutterFrequency: Float = 0.0008
    @State private var frictionAmplitude: Float = 0.015
    @State private var frictionFrequency: Float = 0.02
    @State private var hissRange: Float = 0.01
    @State private var crackleThreshold: Float = 0.998
    @State private var crackleRange: Float = 0.08
    @State private var masterVolume: Float = 0.5
    
    // 预设方案
    private let presets: [AudioEffectPreset] = [
        AudioEffectPreset(
            name: "轻度",
            whiteNoiseRange: 0.03,
            flutterAmplitude: 0.01,
            flutterFrequency: 0.0006,
            frictionAmplitude: 0.008,
            frictionFrequency: 0.015,
            hissRange: 0.005,
            crackleThreshold: 0.999,
            crackleRange: 0.04,
            masterVolume: 0.3
        ),
        AudioEffectPreset(
            name: "标准",
            whiteNoiseRange: 0.06,
            flutterAmplitude: 0.02,
            flutterFrequency: 0.0008,
            frictionAmplitude: 0.015,
            frictionFrequency: 0.02,
            hissRange: 0.01,
            crackleThreshold: 0.998,
            crackleRange: 0.08,
            masterVolume: 0.5
        ),
        AudioEffectPreset(
            name: "重度",
            whiteNoiseRange: 0.12,
            flutterAmplitude: 0.04,
            flutterFrequency: 0.001,
            frictionAmplitude: 0.03,
            frictionFrequency: 0.025,
            hissRange: 0.02,
            crackleThreshold: 0.995,
            crackleRange: 0.15,
            masterVolume: 0.7
        ),
        AudioEffectPreset(
            name: "怀旧",
            whiteNoiseRange: 0.08,
            flutterAmplitude: 0.035,
            flutterFrequency: 0.0005,
            frictionAmplitude: 0.025,
            frictionFrequency: 0.018,
            hissRange: 0.015,
            crackleThreshold: 0.996,
            crackleRange: 0.12,
            masterVolume: 0.6
        )
    ]
    
    var body: some View {
        NavigationView {
            List {
                
                // 预设方案
                Section(header: Text("音效预设").padding(.leading, 20)) {
                    HStack(spacing: 12) {
                        ForEach(presets, id: \.name) { preset in
                            Button(action: {
                                applyPreset(preset)
                                if musicService.isHapticFeedbackEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: getPresetIcon(for: preset.name))
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60) // 统一高度
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.blue)
                                )
                                .contentShape(Rectangle()) // 确保整个区域都可点击
                            }
                            .buttonStyle(PlainButtonStyle()) // 移除默认按钮样式
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets()) // 移除List行的默认内边距
                .listRowBackground(Color.clear) // 清除List行背景
                
                // 开关和总音量控制
                Section(header: Text("音效音量")) {
/*                    Toggle("启用磁带音效", isOn: Binding(
                        get: { audioEffectsManager.isCassetteEffectEnabled },
                        set: { audioEffectsManager.setCassetteEffect(enabled: $0) }
                    ))
 */
                    
                    VStack(alignment: .leading, spacing: 8) {
                            Text("音量")
                                .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $masterVolume, in: 0...1, step: 0.01) { editing in
                                if !editing {
                                    audioEffectsManager.setCassetteNoiseVolume(masterVolume)
                                    saveSettings()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
                
                // 白噪音设置
                Section(header: Text("底噪")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("强度")
                            .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $whiteNoiseRange, in: 0...0.2, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
                
                // 抖动效果设置
                Section(header: Text("低频抖动 (Flutter)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("强度")
                            .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $flutterAmplitude, in: 0...0.1, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("频率")
                            .font(.subheadline)
                        HStack {
                            Text("低")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $flutterFrequency, in: 0.0001...0.002, step: 0.0001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("高")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
                
                // 摩擦声设置
                Section(header: Text("磁带摩擦声")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("强度")
                            .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $frictionAmplitude, in: 0...0.05, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("频率")
                            .font(.subheadline)
                        HStack {
                            Text("低")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $frictionFrequency, in: 0.01...0.05, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("高")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
                
                // 嘶嘶声设置
                Section(header: Text("高频嘶嘶声")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("强度")
                            .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $hissRange, in: 0...0.03, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
                
                // 噪点设置
                Section(header: Text("瑕疵噪点 (Crackle)")) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("强度")
                            .font(.subheadline)
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: $crackleRange, in: 0...0.2, step: 0.001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("频率")
                            .font(.subheadline)
                        HStack {
                            Text("低")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            Slider(value: Binding(
                                get: {
                                    // 将阈值转换为频率值：1.0 - threshold
                                    // threshold 0.9999 -> frequency 0.0001 (稀少)
                                    // threshold 0.990 -> frequency 0.01 (频繁)
                                    1.0 - crackleThreshold
                                },
                                set: { newFrequency in
                                    // 将频率值转换回阈值：1.0 - frequency
                                    crackleThreshold = 1.0 - newFrequency
                                }
                            ), in: 0.0001...0.01, step: 0.0001) { editing in
                                if !editing {
                                    regenerateAudio()
                                }
                            }
                            Text("高")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                        }
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .onDisappear {
                saveSettings()
            }
        }
    }
    
    // MARK: - 私有方法
    
    // 获取预设方案对应的图标
    private func getPresetIcon(for presetName: String) -> String {
        switch presetName {
        case "轻度":
            return "speaker.wave.1"  // 单波浪，表示轻微
        case "标准":
            return "speaker.wave.2"  // 双波浪，表示标准
        case "重度":
            return "speaker.wave.3"  // 三波浪，表示重度
        case "怀旧":
            return "clock.arrow.circlepath"  // 复古时钟，表示怀旧
        default:
            return "speaker.wave.2"
        }
    }
    
    private func regenerateAudio() {
        audioEffectsManager.regenerateCassetteNoise(
            whiteNoiseRange: whiteNoiseRange,
            flutterAmplitude: flutterAmplitude,
            flutterFrequency: flutterFrequency,
            frictionAmplitude: frictionAmplitude,
            frictionFrequency: frictionFrequency,
            hissRange: hissRange,
            crackleThreshold: crackleThreshold,
            crackleRange: crackleRange
        )
        saveSettings()
    }
    
    // 预设
    private func applyPreset(_ preset: AudioEffectPreset) {
        whiteNoiseRange = preset.whiteNoiseRange
        flutterAmplitude = preset.flutterAmplitude
        flutterFrequency = preset.flutterFrequency
        frictionAmplitude = preset.frictionAmplitude
        frictionFrequency = preset.frictionFrequency
        hissRange = preset.hissRange
        crackleThreshold = preset.crackleThreshold
        crackleRange = preset.crackleRange
        masterVolume = preset.masterVolume
        
        regenerateAudio()
        audioEffectsManager.setCassetteNoiseVolume(masterVolume)
    }
    
    //保存设置
    private func saveSettings() {
        let settings = AudioEffectSettings(
            whiteNoiseRange: whiteNoiseRange,
            flutterAmplitude: flutterAmplitude,
            flutterFrequency: flutterFrequency,
            frictionAmplitude: frictionAmplitude,
            frictionFrequency: frictionFrequency,
            hissRange: hissRange,
            crackleThreshold: crackleThreshold,
            crackleRange: crackleRange,
            masterVolume: masterVolume
        )
        
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "AudioEffectSettings")
        }
    }
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "AudioEffectSettings"),
              let settings = try? JSONDecoder().decode(AudioEffectSettings.self, from: data) else {
            return
        }
        
        whiteNoiseRange = settings.whiteNoiseRange
        flutterAmplitude = settings.flutterAmplitude
        flutterFrequency = settings.flutterFrequency
        frictionAmplitude = settings.frictionAmplitude
        frictionFrequency = settings.frictionFrequency
        hissRange = settings.hissRange
        crackleThreshold = settings.crackleThreshold
        crackleRange = settings.crackleRange
        masterVolume = settings.masterVolume
    }
}

// MARK: - 数据模型

struct AudioEffectSettings: Codable {
    let whiteNoiseRange: Float
    let flutterAmplitude: Float
    let flutterFrequency: Float
    let frictionAmplitude: Float
    let frictionFrequency: Float
    let hissRange: Float
    let crackleThreshold: Float
    let crackleRange: Float
    let masterVolume: Float
}

struct AudioEffectPreset {
    let name: String
    let whiteNoiseRange: Float
    let flutterAmplitude: Float
    let flutterFrequency: Float
    let frictionAmplitude: Float
    let frictionFrequency: Float
    let hissRange: Float
    let crackleThreshold: Float
    let crackleRange: Float
    let masterVolume: Float
}

#Preview {
    AudioEffectsSettingsView()
        .environmentObject(MusicService.shared)
}

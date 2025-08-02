import SwiftUI

struct MusicSourceSettingsView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var showingSubsonicSettings = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "music.quarternote.3")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("音乐数据源")
                                .font(.headline)
                            Text("选择您的音乐服务提供商")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("当前数据源")
            }
            
            Section {
                // Apple Music 选项
                Button(action: {
                    musicService.currentDataSource = .musicKit
                }) {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Music")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("使用您的 Apple Music 资料库")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .musicKit {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Subsonic 选项
                Button(action: {
                    musicService.currentDataSource = .subsonic
                }) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subsonic")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("连接到您的个人音乐服务器")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .subsonic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("可用的音乐源")
            } footer: {
                Text("选择您希望使用的音乐服务。切换数据源会停止当前播放。")
            }
            
            // Subsonic 配置部分
            if musicService.currentDataSource == .subsonic {
                Section {
                    Button(action: {
                        showingSubsonicSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            
                            Text("配置 Subsonic 服务器")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 连接状态显示
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.secondary)
                        
                        Text("连接状态")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if musicService.getSubsonicService().isConnected {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已连接")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("未连接")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("Subsonic 设置")
                } footer: {
                    Text("配置您的 Subsonic 服务器连接信息。需要有效的服务器地址、用户名和密码。")
                }
            }
            
            // 数据源功能对比
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        feature: "音乐资料库",
                        appleMusicSupported: true,
                        subsonicSupported: true
                    )
                    
                    FeatureRow(
                        feature: "播放列表",
                        appleMusicSupported: true,
                        subsonicSupported: true
                    )
                    
                    FeatureRow(
                        feature: "搜索功能",
                        appleMusicSupported: true,
                        subsonicSupported: true
                    )
                    
                    FeatureRow(
                        feature: "离线播放",
                        appleMusicSupported: true,
                        subsonicSupported: false
                    )
                    
                    FeatureRow(
                        feature: "自托管服务器",
                        appleMusicSupported: false,
                        subsonicSupported: true
                    )
                    
                    FeatureRow(
                        feature: "无月费订阅",
                        appleMusicSupported: false,
                        subsonicSupported: true
                    )
                }
            } header: {
                Text("功能对比")
            }
        }
        .navigationTitle("音乐服务商")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSubsonicSettings) {
            SubsonicSettingsView()
        }
    }
}

// MARK: - 功能对比行

struct FeatureRow: View {
    let feature: String
    let appleMusicSupported: Bool
    let subsonicSupported: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.body)
            
            Spacer()
            
            // Apple Music 支持状态
            VStack(alignment: .center, spacing: 2) {
                Image(systemName: appleMusicSupported ? "checkmark" : "xmark")
                    .font(.caption)
                    .foregroundColor(appleMusicSupported ? .green : .red)
                
                Text("Apple")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            
            // Subsonic 支持状态
            VStack(alignment: .center, spacing: 2) {
                Image(systemName: subsonicSupported ? "checkmark" : "xmark")
                    .font(.caption)
                    .foregroundColor(subsonicSupported ? .green : .red)
                
                Text("Subsonic")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
        }
    }
}

// MARK: - 预览

struct MusicSourceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MusicSourceSettingsView()
                .environmentObject(MusicService.shared)
        }
    }
}
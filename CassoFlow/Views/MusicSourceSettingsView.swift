import SwiftUI

struct MusicSourceSettingsView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var showingSubsonicSettings = false
    
    var body: some View {
        List {
            
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
                
                Button(action: {
                    musicService.currentDataSource = .musicKit
                }) {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spotify")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("使用您的 Spotify 资料库")
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
                Text("音乐数据源")
            } footer: {
                Text("选择您希望使用的音乐服务。")
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
        }
        .navigationTitle("音乐服务商")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSubsonicSettings) {
            SubsonicSettingsView()
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

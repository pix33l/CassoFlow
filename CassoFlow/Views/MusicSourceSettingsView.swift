import SwiftUI

struct MusicSourceSettingsView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var showingSubsonicSettings = false
    @State private var showingAudioStationSettings = false
    
    var body: some View {
        List {
            
            Section {
                // Apple Music 选项
                Button(action: {
                    musicService.currentDataSource = .musicKit
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Music")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("使用您的 Apple Music 媒体库")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .musicKit {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            header: {
                Text("流媒体")
            }
            
            Section {
                
                Button(action: {
                    musicService.currentDataSource = .audioStation
                }) {
                    HStack {
                        Image("Audio-Station")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Station")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("使用您的群晖 Audio Station 媒体库")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .audioStation {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.yellow)
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
                        
                        Image("Subsonic")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                        
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subsonic API")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("连接到您的个人音乐服务器（Subsonic API），如 Subsonic、Navidrome、Airsonic、Madsonic等")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .subsonic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                        
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("音乐服务器")
            }
            
                
            Section {
                // 本地文件 选项
                Button(action: {
                    musicService.currentDataSource = .local
                }) {
                    HStack {
                        
                        Image("Subsonic")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)

                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本地文件")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("使用本地文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if musicService.currentDataSource == .local {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }

                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("本地文件")
            }
            
            // Subsonic 配置部分
            if musicService.currentDataSource == .subsonic {
                Section {
                    Button(action: {
                        showingSubsonicSettings = true
                    }) {
                        HStack {
                            Text("配置 Subsonic API 服务器")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
//                    // 连接状态显示
//                    HStack {
//                        Text("连接状态")
//                            .foregroundColor(.primary)
//                        
//                        Spacer()
//                        
//                        // 🔑 修改连接状态检查逻辑
//                        if musicService.getSubsonicService().isConnected {
//                            HStack {
//                                Image(systemName: "checkmark.circle.fill")
//                                    .foregroundColor(.green)
//                                Text("已连接")
//                                    .font(.body)
//                                    .foregroundColor(.green)
//                            }
//                        } else {
//                            // 🔑 检查是否有配置信息
//                            let subsonicService = musicService.getSubsonicService()
//                            let apiClient = subsonicService.getAPIClient()
//                            
//                            if !apiClient.serverURL.isEmpty && !apiClient.username.isEmpty && !apiClient.password.isEmpty {
//                                // 有配置但未连接
//                                HStack {
//                                    Image(systemName: "exclamationmark.circle.fill")
//                                        .foregroundColor(.orange)
//                                    Text("未连接 - 点击测试连接")
//                                        .font(.body)
//                                        .foregroundColor(.orange)
//                                }
//                            } else {
//                                // 无配置
//                                HStack {
//                                    Image(systemName: "xmark.circle.fill")
//                                        .foregroundColor(.red)
//                                    Text("未配置")
//                                        .font(.body)
//                                        .foregroundColor(.red)
//                                }
//                            }
//                        }
//                    }
                } header: {
                    Text("Subsonic 设置")
                } footer: {
                    Text("配置您的 Subsonic API 服务器,需要准备有效的服务器地址、用户名和密码。")
                }
            }

            // Audio Station 配置部分
            if musicService.currentDataSource == .audioStation {
                Section {
                    Button(action: {
                        showingAudioStationSettings = true
                    }) {
                        HStack {
                            Text("配置 Audio Station 服务器")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
//                    // 连接状态显示
//                    HStack {
//                        Text("连接状态")
//                            .foregroundColor(.primary)
//                        
//                        Spacer()
//                        
//                        // 🔑 修改连接状态检查逻辑
//                        if musicService.getAudioStationService().isConnected {
//                            HStack {
//                                Image(systemName: "checkmark.circle.fill")
//                                    .foregroundColor(.green)
//                                Text("已连接")
//                                    .font(.body)
//                                    .foregroundColor(.green)
//                            }
//                        } else {
//                            // 🔑 检查是否有配置信息
//                            let audioStationService = musicService.getAudioStationService()
//                            // 🔑 直接访问API客户端的属性
//                            let config = audioStationService.getConfiguration()
//                            
//                            if !config.baseURL.isEmpty && !config.username.isEmpty && !config.password.isEmpty {
//                                // 有配置但未连接
//                                HStack {
//                                    Image(systemName: "exclamationmark.circle.fill")
//                                        .foregroundColor(.orange)
//                                    Text("未连接 - 点击测试连接")
//                                        .font(.body)
//                                        .foregroundColor(.orange)
//                                }
//                            } else {
//                                // 无配置
//                                HStack {
//                                    Image(systemName: "xmark.circle.fill")
//                                        .foregroundColor(.red)
//                                    Text("未配置")
//                                        .font(.body)
//                                        .foregroundColor(.red)
//                                }
//                            }
//                        }
//                    }
                } header: {
                    Text("Audio Station 设置")
                } footer: {
                    Text("配置您的群晖 Audio Station 服务器，需要准备有效的服务器地址、用户名和密码。")
                }
            }
        }
        .navigationTitle("音乐提供商")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSubsonicSettings) {
            SubsonicSettingsView()
        }
        .sheet(isPresented: $showingAudioStationSettings) {
            AudioStationSettingsView()
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

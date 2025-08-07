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
                Text("请选择您希望使用的音乐提供商")
            }
            
            // Subsonic 配置部分
            if musicService.currentDataSource == .subsonic {
                Section {
                    Button(action: {
                        showingSubsonicSettings = true
                    }) {
                        HStack {
//                            Image(systemName: "gear")
//                                .foregroundColor(.blue)
                            
                            Text("配置 Subsonic API 服务器")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 连接状态显示
                    HStack {
//                        Image(systemName: "antenna.radiowaves.left.and.right")
//                            .foregroundColor(.secondary)
                        
                        Text("连接状态")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if musicService.getSubsonicService().isConnected {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已连接")
                                    .font(.body)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("未连接")
                                    .font(.body)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("Subsonic 设置")
                } footer: {
                    Text("配置您的 Subsonic API 服务器,需要准备有效的服务器地址、用户名和密码。")
                }
            }
        }
        .navigationTitle("音乐提供商")
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

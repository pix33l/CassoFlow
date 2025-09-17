import SwiftUI

struct MusicSourceSettingsView: View {
    @EnvironmentObject private var musicService: MusicService
    
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
                // 本地文件 选项
                Button(action: {
                    musicService.currentDataSource = .local
                }) {
                    HStack {
                        
                        Image(systemName: "folder.fill")
                            .font(.title)
                            .foregroundColor(.white)
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
        }
        .navigationTitle("音乐提供商")
        .navigationBarTitleDisplayMode(.inline)
    }
}

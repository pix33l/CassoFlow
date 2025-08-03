import SwiftUI

struct SubsonicSettingsView: View {
    @StateObject private var apiClient = SubsonicAPIClient()
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .notTested
    @State private var showPassword = false
    
    enum ConnectionStatus: Equatable {
        case notTested
        case connecting
        case success
        case failed(String)
        
        var color: Color {
            switch self {
            case .notTested:
                return .secondary
            case .connecting:
                return .blue
            case .success:
                return .green
            case .failed:
                return .red
            }
        }
        
        var iconName: String {
            switch self {
            case .notTested:
                return "circle"
            case .connecting:
                return "arrow.clockwise"
            case .success:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .notTested:
                return "未测试"
            case .connecting:
                return "连接中..."
            case .success:
                return "连接成功"
            case .failed(let error):
                return "连接失败：\(error)"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subsonic服务器")
                                    .font(.headline)
                                Text("连接到您的个人音乐服务器")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 连接状态指示器
                        HStack {
                            Image(systemName: connectionStatus.iconName)
                                .foregroundColor(connectionStatus.color)
                                .rotationEffect(.degrees(connectionStatus == .connecting ? 360 : 0))
                                .animation(getRotationAnimation(), value: connectionStatus)
                            
                            Text(connectionStatus.message)
                                .font(.caption)
                                .foregroundColor(connectionStatus.color)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("服务器状态")
                }
                
                Section {
                    // 服务器URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("服务器地址")
                            .font(.headline)
                        
                        TextField("https://your-server.com", text: $apiClient.serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("输入您的Subsonic服务器完整URL地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 用户名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用户名")
                            .font(.headline)
                        
                        TextField("用户名", text: $apiClient.username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // 密码
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("密码")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Group {
                            if showPassword {
                                TextField("密码", text: $apiClient.password)
                            } else {
                                SecureField("密码", text: $apiClient.password)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }
                } header: {
                    Text("服务器配置")
                } footer: {
                    Text("请输入您的Subsonic服务器登录信息。密码将安全存储在设备上。")
                }
                
                Section {
                    // 测试连接按钮
                    Button(action: testConnection) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            
                            Text(isConnecting ? "测试连接中..." : "测试连接")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(canTestConnection ? .white : .secondary)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canTestConnection || isConnecting)
                    
                    // 保存按钮
                    Button(action: saveConfiguration) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存配置")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSave)
                    
                } footer: {
                    if connectionStatus == .success {
                        Text("✅ 配置正确，可以开始使用Subsonic服务")
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("关于Subsonic")
                            .font(.headline)
                        
                        Text("Subsonic是一个个人音乐流媒体服务器，允许您从任何地方访问自己的音乐收藏。")
                            .font(.body)
                        
                        Text("要使用此功能，您需要：")
                            .font(.body)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• 一个运行中的Subsonic服务器")
                            Text("• 服务器的URL地址")
                            Text("• 有效的用户账户")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    }
                } header: {
                    Text("帮助信息")
                }
            }
            .navigationTitle("Subsonic设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var canTestConnection: Bool {
        !apiClient.serverURL.isEmpty && 
        !apiClient.username.isEmpty && 
        !apiClient.password.isEmpty
    }
    
    private var canSave: Bool {
        canTestConnection
    }
    
    // MARK: - 辅助方法
    
    private func getRotationAnimation() -> Animation? {
        if case .connecting = connectionStatus {
            return Animation.linear.repeatForever(autoreverses: false)
        } else {
            return Animation.default
        }
    }
    
    // MARK: - 方法
    
    private func testConnection() {
        guard canTestConnection else { return }
        
        isConnecting = true
        connectionStatus = .connecting
        
        Task {
            do {
                let success = try await apiClient.ping()
                
                await MainActor.run {
                    isConnecting = false
                    connectionStatus = success ? .success : .failed("未知错误")
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionStatus = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    private func saveConfiguration() {
        apiClient.saveConfiguration()
        
        // 显示保存成功提示
        // 这里可以添加HapticFeedback或Toast提示
    }
}

// MARK: - 预览

struct SubsonicSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SubsonicSettingsView()
    }
}

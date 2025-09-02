import SwiftUI

struct AudioStationSettingsView: View {
    @StateObject private var audioStationService = AudioStationMusicService.shared
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) private var dismiss
    
    @State private var baseURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .notTested
    @State private var showPassword = false
    @State private var showSaveSuccess = false
    @State private var rotationAngle: Double = 0
    
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
                return .secondary
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
                return "arrow.trianglehead.2.clockwise"
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
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image("Audio-Station")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("群晖 Audio Station")
                                .font(.headline)
                            Text("私人音乐媒体库服务")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 测试连接按钮
                        Button(action: testConnection) {
                            HStack {
                                Text(isConnecting ? "连接中..." : "测试连接")
                                    .fontWeight(.bold)
                                    .font(.footnote)
                            }
                            .frame(width: 54)
                            .foregroundColor(canTestConnection ? .black : .secondary)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow) // 改为黄色
                        .disabled(!canTestConnection || isConnecting)
                    }
                } header: {
                    Text("服务器状态")
                } footer: {
                    HStack {
                        Image(systemName: connectionStatus.iconName)
                            .font(.footnote)
                            .foregroundColor(connectionStatus.color)
                            .rotationEffect(.degrees(rotationAngle))
                            .onChange(of: connectionStatus) { _, newStatus in
                                if newStatus == .connecting {
                                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                        rotationAngle = 360
                                    }
                                } else {
                                    withAnimation(.default) {
                                        rotationAngle = 0
                                    }
                                }
                            }
                        
                        Text(connectionStatus.message)
                            .font(.footnote)
                            .foregroundColor(connectionStatus.color)
                    }
                }
                
                Section {
                    // 服务器地址
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服务器地址")
                            .font(.headline)
                        
                        TextField("https://", text: $baseURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    // 用户名
                    VStack(alignment: .leading, spacing: 12) {
                        Text("用户名")
                            .font(.headline)
                        
                        TextField("用户名", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    // 密码
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("密码")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.yellow) // 改为黄色
                            }
                        }
                        
                        Group {
                            if showPassword {
                                TextField("密码", text: $password)
                            } else {
                                SecureField("密码", text: $password)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("服务器设置")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请确保：")
                        Text("• 服务器地址包含协议（http:// 或 https://）")
                        Text("• 端口号正确（默认5000或5001）")
                        Text("• 用户账户有 Audio Station 访问权限")
                        Text("密码将安全存储在设备上。")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // 保存按钮
            VStack {
                Button(action: saveConfiguration) {
                    HStack {
                        if showSaveSuccess {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(showSaveSuccess ? "保存成功" : "保存")
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!canSave ? Color.gray : Color.yellow) // 改为黄色
                    .foregroundColor(!canSave ? Color.white : Color.black) // 改为黑色文字（和Subsonic一致）
                    .cornerRadius(12)
                }
                .disabled(!canSave)
                .padding()
            }
            
            .navigationTitle("Audio Station 设置")
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
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var canTestConnection: Bool {
        !baseURL.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty
    }
    
    private var canSave: Bool {
        // 只有连接测试成功后才能保存
        connectionStatus == .success
    }
    
    // MARK: - 方法
    
    private func loadCurrentSettings() {
        let config = audioStationService.getConfiguration()
        baseURL = config.baseURL
        username = config.username
        password = config.password
        
        // 如果已有配置且已连接，则标记为连接成功
        if !baseURL.isEmpty && !username.isEmpty && !password.isEmpty && audioStationService.isConnected {
            connectionStatus = .success
        }
    }
    
    private func testConnection() {
        guard canTestConnection else { return }
        
        isConnecting = true
        connectionStatus = .connecting
        
        // 配置服务
        audioStationService.configure(baseURL: baseURL, username: username, password: password)
        
        Task {
            do {
                let success = try await audioStationService.connect()
                
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
        // 保存配置（已在testConnection中完成）
        
        // 显示保存成功提示
        showSaveSuccess = true
        
        // 触觉反馈
        if musicService.isHapticFeedbackEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // 3秒后隐藏成功提示并关闭视图
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showSaveSuccess = false
            dismiss()
        }
    }
}

// MARK: - 预览

struct AudioStationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AudioStationSettingsView()
            .environmentObject(MusicService()) // 添加必需的环境对象
    }
}

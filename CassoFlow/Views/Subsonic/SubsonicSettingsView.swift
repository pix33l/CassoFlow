import SwiftUI

struct SubsonicSettingsView: View {
    @StateObject private var apiClient = SubsonicAPIClient()
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .notTested
    @State private var showPassword = false
    @State private var showSaveSuccess = false // 添加保存成功状态
    @State private var rotationAngle: Double = 0 // 添加旋转角度状态
    
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
                        Image("Subsonic")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subsonic API 服务器")
                                .font(.headline)
                            // 连接状态指示器
//                            HStack {
//                                Image(systemName: connectionStatus.iconName)
//                                    .font(.footnote)
//                                    .foregroundColor(connectionStatus.color)
//                                    .rotationEffect(.degrees(rotationAngle))
//                                    .onChange(of: connectionStatus) { _, newStatus in
//                                        if newStatus == .connecting {
//                                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
//                                                rotationAngle = 360
//                                            }
//                                        } else {
//                                            withAnimation(.default) {
//                                                rotationAngle = 0
//                                            }
//                                        }
//                                    }
//                                
//                                Text(connectionStatus.message)
//                                    .font(.footnote)
//                                    .foregroundColor(connectionStatus.color)
//                            }
                        }
                        
                        Spacer()
                        // 测试连接按钮
                        Button(action: testConnection) {
                            HStack {
//                                if isConnecting {
//                                    ProgressView()
//                                        .scaleEffect(0.8)
//                                        .progressViewStyle(CircularProgressViewStyle())
//                                } else {
//                                    Image(systemName: "antenna.radiowaves.left.and.right")
//                                }
                                
                                Text(isConnecting ? "连接中..." : "测试连接")
                                    .fontWeight(.bold)
                                    .font(.footnote)
                            }
                            .frame(width: 54)
                            .foregroundColor(canTestConnection ? .black : .secondary)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
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
                    // 服务器URL
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服务器地址")
                            .font(.headline)
                        
                        TextField("https://your-server.com", text: $apiClient.serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
//                        Text("请输入您的 Subsonic API 服务器完整 URL 地址")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
                    }
                    
                    // 用户名
                    VStack(alignment: .leading, spacing: 12) {
                        Text("用户名")
                            .font(.headline)
                        
                        TextField("用户名", text: $apiClient.username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
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
                                    .foregroundColor(.yellow)
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
                    Text("服务器设置")
                } footer: {
                    Text("请输入服务器登录信息，密码将安全存储在设备上。")
                }
                
//                Section {
//                    // 测试连接按钮
//                    Button(action: testConnection) {
//                        HStack {
//                            if isConnecting {
//                                ProgressView()
//                                    .scaleEffect(0.8)
//                                    .progressViewStyle(CircularProgressViewStyle())
//                            } else {
//                                Image(systemName: "antenna.radiowaves.left.and.right")
//                            }
//                            
//                            Text(isConnecting ? "测试连接中..." : "测试连接")
//                        }
//                        .frame(maxWidth: .infinity)
//                        .foregroundColor(canTestConnection ? .white : .secondary)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .disabled(!canTestConnection || isConnecting)
                    
                    // 保存按钮
//                    Button(action: saveConfiguration) {
//                        HStack {
//                            Image(systemName: "checkmark.circle.fill")
//                            Text("保存")
//                        }
//                        .foregroundStyle(.black)
//                        .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .tint(.yellow)
//                    .disabled(!canSave)
//                    
//                } footer: {
//                    if showSaveSuccess {
//                        Text("保存成功，可以开始使用 Subsonic 服务")
//                            .foregroundColor(.green)
//                    }
//                }
            }
            
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
                    .background(!canSave ? Color.gray : Color.yellow) // 禁用时变灰
                    .foregroundColor(!canSave ? Color.white : Color.black) // 禁用时文字变白
                    .cornerRadius(12)
                }
                .disabled(!canSave) // 移动到这里！
                .padding()
            }
            
            .navigationTitle("Subsonic API 设置")
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
        // 只有连接测试成功后才能保存
        connectionStatus == .success
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
        showSaveSuccess = true
        
        // 触觉反馈
        if musicService.isHapticFeedbackEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // 3秒后隐藏成功提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showSaveSuccess = false
            dismiss()
        }
    }
}

// MARK: - 预览

struct SubsonicSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SubsonicSettingsView()
    }
}

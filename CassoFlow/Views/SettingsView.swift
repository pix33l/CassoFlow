import SwiftUI

enum WebLink: String {
    case privacyPolicy = "https://pix3l.me/cf-privacy-policy"
    case termsOfUse = "https://pix3l.me/cf-terms-of-use"
    case appStoreReview = "https://apps.apple.com/app/id6746403175?action=write-review"
}

struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

struct LinkRow: View {
    let title: String
    let destination: URL
    let icon: String
    
    var body: some View {
        Link(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)
                
                Text(title)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.3))
            }
            .foregroundColor(.primary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var storeManager = StoreManager()

    @State private var closeTapped = false
    @State private var showingShareSheet = false
    @State private var showingPaywall = false
    
    private var feedbackMailURL: URL? {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceModel = "iOS Device" // 简化设备信息
        let locale = Locale.current
        let region = locale.region?.identifier ?? "Unknown"
        let language = locale.language.languageCode?.identifier ?? "Unknown"
        
        let body = """
        
        
        ---
        App: CassoFlow
        Version: \(appVersion) (\(appBuild))
        Device: \(deviceModel)
        System: \(systemVersion)
        Region: \(region)
        Language: \(language)
        """.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let subject = "CassoFlow 意见反馈".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        return URL(string: "mailto:service@pix3l.me?subject=\(subject)&body=\(body)")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        NavigationView {
            List {
                // Pro版本升级卡片
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(colorScheme == .dark ? "PRO-dark" : "PRO-light")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 30)
                        
                        Text(storeManager.membershipStatus.displayText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if storeManager.membershipStatus.shouldShowUpgradeButton {
                            HStack {
                                Text("立即升级")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(colorScheme == .dark ? .white : .black)
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .cornerRadius(15)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 只有在显示升级按钮时才可以点击
                        if storeManager.membershipStatus.shouldShowUpgradeButton {
                            print("🔘 PRO升级区域被点击")
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            showingPaywall = true
                        }
                    }
                }
                // 通用设置
                Section(header: Text("通用")) {
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "recordingtape")
                                .font(.body)
                                .frame(width: 20)
                            
                            Toggle("磁带音效", isOn: Binding(
                                get: {
                                    // 测试模式：显示真实状态，不检查会员
                                    return musicService.isCassetteEffectEnabled
                                    // 原始会员检查逻辑（已注释）：
                                    // return storeManager.membershipStatus.isActive && musicService.isCassetteEffectEnabled
                                },
                                set: { newValue in
                                    // 测试模式：直接设置，不检查会员
                                    musicService.setCassetteEffect(enabled: newValue)
                                    // 原始会员检查逻辑（已注释）：
                                    // if storeManager.membershipStatus.isActive {
                                    //     musicService.setCassetteEffect(enabled: newValue)
                                    // } else {
                                    //     // 非会员用户点击时显示升级提示
                                    //     print("🔘 非会员点击磁带音效，弹出PaywallView")
                                    //     showingPaywall = true
                                    // }
                                }
                            ))
                            // 移除 disabled，让非会员也能点击
                            .onChange(of: musicService.isCassetteEffectEnabled) { _, newValue in
                                print("🎵 磁带音效开关切换: \(newValue)")
                            }
                        }
                        
                        HStack {
                            Spacer().frame(width: 25) // 与图标对齐
                            // 测试模式：隐藏Pro标识
                            // if !storeManager.membershipStatus.isActive {
                            //     ProBadge()
                            // }
                            Text("模拟磁带底噪和低频抖动")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // 新增：音效调节入口
                       if musicService.isCassetteEffectEnabled {
                            NavigationLink(destination: AudioEffectsSettingsView().environmentObject(musicService)) {
                                HStack {
                                    Spacer().frame(width: 25) // 与图标对齐
//                                    Image(systemName: "slider.horizontal.3")
                                    Text("调节音效参数")
                                    Spacer()
                                }
                                .padding(.top, 5)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "hand.tap")
                                .font(.body)
                                .frame(width: 20)
                            
                            Toggle("触觉反馈", isOn: Binding(
                                get: {
                                    // 测试模式：显示真实状态，不检查会员
                                    return musicService.isHapticFeedbackEnabled
                                    // 原始会员检查逻辑（已注释）：
                                    // return storeManager.membershipStatus.isActive && musicService.isHapticFeedbackEnabled
                                },
                                set: { newValue in
                                    // 测试模式：直接设置，不检查会员
                                    musicService.setHapticFeedback(enabled: newValue)
                                    // 原始会员检查逻辑（已注释）：
                                    // if storeManager.membershipStatus.isActive {
                                    //     musicService.setHapticFeedback(enabled: newValue)
                                    // } else {
                                    //     // 非会员用户点击时显示升级提示
                                    //     print("🔘 非会员点击触觉反馈，弹出PaywallView")
                                    //     showingPaywall = true
                                    // }
                                }
                            ))
                            // 移除 disabled，让非会员也能点击
                        }
                        
                        HStack {
                            Spacer().frame(width: 25) // 与图标对齐
                            // 测试模式：隐藏Pro标识
                            // if !storeManager.membershipStatus.isActive {
                            //     ProBadge()
                            // }
                            Text("增加反馈来模拟实体操作感")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "sun.max")
                                .font(.body)
                                .frame(width: 20)
                            
                            Toggle("屏幕常亮", isOn: Binding(
                                get: {
                                    // 测试模式：显示真实状态，不检查会员
                                    return musicService.isScreenAlwaysOn
                                    // 原始会员检查逻辑（已注释）：
                                    // return storeManager.membershipStatus.isActive && musicService.isScreenAlwaysOn
                                },
                                set: { newValue in
                                    // 测试模式：直接设置，不检查会员
                                    musicService.setScreenAlwaysOn(enabled: newValue)
                                    // 原始会员检查逻辑（已注释）：
                                    // if storeManager.membershipStatus.isActive {
                                    //     musicService.setScreenAlwaysOn(enabled: newValue)
                                    // } else {
                                    //     // 非会员用户点击时显示升级提示
                                    //     print("🔘 非会员点击屏幕常亮，弹出PaywallView")
                                    //     showingPaywall = true
                                    // }
                                }
                            ))
                            // 移除 disabled，让非会员也能点击
                            .onChange(of: musicService.isScreenAlwaysOn) { _, newValue in
                                print("🔆 屏幕常亮开关切换: \(newValue)")
                            }
                        }
                        
                        HStack {
                            Spacer().frame(width: 25) // 与图标对齐
                            // 测试模式：隐藏Pro标识
                            // if !storeManager.membershipStatus.isActive {
                            //     ProBadge()
                            // }
                            Text("保持屏幕一直不锁屏")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                // 支持我们
                Section(header: Text("支持我们")) {
                    LinkRow(
                        title: String(localized:"给我们五星好评"),
                        destination: URL(string: WebLink.appStoreReview.rawValue)!,
                        icon: "star"
                    )
                    
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .frame(width: 20)
                            
                            Text("把应用推荐给朋友")
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.3))
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Button {
                        if let mailURL = feedbackMailURL {
                            openURL(mailURL)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.body)
                                .frame(width: 20)
                            
                            Text("意见反馈")
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.3))
                        }
                        .foregroundColor(.primary)
                    }
                }
                // 其他设置
                Section(header: Text("其他")) {
                    Button {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                                .frame(width: 20)
                            
                            
                            Text("恢复购买")
                            
                            Spacer()
                            
                            if storeManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.primary.opacity(0.3))
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .disabled(storeManager.isLoading)
                    
                    NavigationLink(destination: ContactUsView()) {
                        HStack {
                            Image(systemName: "person") // 使用系统 person 图标
                            Text("关于作者")
                        }
                    }
                    
                    // 修改隐私政策链接
                    LinkRow(
                        title: String(localized: "隐私政策"),
                        destination: URL(string: WebLink.privacyPolicy.rawValue)!,
                        icon: "lock"
                    )
                    
                    // 修改使用条款链接
                    LinkRow(
                        title: String(localized: "使用条款"),
                        destination: URL(string: WebLink.termsOfUse.rawValue)!,
                        icon: "book"
                    )
                }
                HStack {
                    Spacer()
                    VStack {
                        Text("PIX3L DESIGN STUDIO")
                            .fontWeight(.bold)
                        Text("版本 \(appVersion) (\(appBuild))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [
                    "快来试试 CassoFlow - 独特的磁带风格音乐播放器！",
                    URL(string: "https://apps.apple.com/app/id6746403175")!
                ])
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        closeTapped.toggle()
                        // 修复：只有会员才能使用触觉反馈
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(8)           // 增加内边距以扩大背景圆形
                            .background(
                                Circle()           // 圆形背景
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                }
            }
            .alert("提示", isPresented: $storeManager.showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(storeManager.alertMessage)
            }
            .onAppear {
                Task {
                    await storeManager.updateMembershipStatus()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MusicService.shared)
}

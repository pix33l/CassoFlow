import SwiftUI

enum WebLink: String {
    case privacyPolicy = "https://pix3l.me/CF-privacy-policy"
    case termsOfUse = "https://pix3l.me/CF-terms-of-use"
    case appStoreReview = "https://apps.apple.com/app/id6746403175?action=write-review"
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
                    .frame(width: 30)
                
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
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var musicService: MusicService
    
    @State private var closeTapped = false
    @State private var showingShareSheet = false
    
    private var feedbackMailURL: URL? {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
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

    var body: some View {
        NavigationView {
            List {
                // Pro版本升级卡片
                Section {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("CASSOFLOW PRO")
                                .font(.headline)
                            Text("仅需¥48.00，获取全部功能")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            // 处理升级操作
                        }) {
                            Text("立即升级")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 通用设置
                Section(header: Text("通用")) {
                    
                    HStack {
                        Image(systemName: "recordingtape")
                            .font(.body)
                            .frame(width: 30)
                        
                        Toggle("磁带音效", isOn: Binding(
                            get: { musicService.isCassetteEffectEnabled },
                            set: { newValue in
                                musicService.setCassetteEffect(enabled: newValue)
                            }
                        ))
                        .onChange(of: musicService.isCassetteEffectEnabled) { _, newValue in
                            print("🎵 磁带音效开关切换: \(newValue)")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "hand.tap")
                            .font(.body)
                            .frame(width: 30)
                        
                        Toggle("触觉反馈", isOn: Binding(
                            get: { musicService.isHapticFeedbackEnabled },
                            set: { newValue in
                                musicService.setHapticFeedback(enabled: newValue)
                            }
                        ))
                        .sensoryFeedback(.selection, trigger: musicService.isHapticFeedbackEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "sun.max")
                            .font(.body)
                            .frame(width: 30)
                        
                        Toggle("屏幕常亮", isOn: Binding(
                            get: { musicService.isScreenAlwaysOn },
                            set: { newValue in
                                musicService.setScreenAlwaysOn(enabled: newValue)
                            }
                        ))
                        .onChange(of: musicService.isScreenAlwaysOn) { _, newValue in
                            print("🔆 屏幕常亮开关切换: \(newValue)")
                        }
                    }
                }
                
                // 支持我们
                Section(header: Text("支持我们")) {
                    LinkRow(
                        title: "给我们五星好评",
                        destination: URL(string: WebLink.appStoreReview.rawValue)!,
                        icon: "star.fill"
                    )
                    
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .frame(width: 30)
                            
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
                                .frame(width: 30)
                            
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
                    NavigationLink("恢复购买") {
                        Text("恢复购买页面")
                    }
                    NavigationLink("关于作者") {
                        Text("关于页面")
                    }
                    
                    // 修改隐私政策链接
                    LinkRow(
                        title: String(localized:"隐私政策"),
                        destination: URL(string: WebLink.privacyPolicy.rawValue)!,
                        icon: "lock"
                    )
                    
                    // 修改使用条款链接
                    LinkRow(
                        title: String(localized:"使用条款"),
                        destination: URL(string: WebLink.termsOfUse.rawValue)!,
                        icon: "book"
                    )
                    
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [
                    "快来试试 CassoFlow - 独特的磁带风格音乐播放器！",
                    URL(string: "https://apps.apple.com/app/id6746403175")!
                ])
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        closeTapped.toggle()
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
                    .sensoryFeedback(.impact(weight: .light), trigger: closeTapped)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MusicService.shared)
}

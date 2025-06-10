import SwiftUI

enum WebLink: String {
    case privacyPolicy = "https://pix3l.me/CF-privacy-policy"
    case termsOfUse = "https://pix3l.me/CF-terms-of-use"
}

struct LinkRow: View {
    let title: String
    let destination: URL
    
    var body: some View {
        Link(destination: destination) {
            HStack {
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

struct SettingsView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var musicService: MusicService
    @State private var isScreenAlwaysOn = true
    
    @State private var closeTapped = false
    
    var body: some View {
        NavigationView {
            List {
                // Pro版本升级卡片
                Section {
                    HStack {
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
                    
                    Toggle("磁带音效", isOn: Binding(
                        get: { musicService.isCassetteEffectEnabled },
                        set: { newValue in
                            musicService.setCassetteEffect(enabled: newValue)
                        }
                    ))
                    .onChange(of: musicService.isCassetteEffectEnabled) { _, newValue in
                        print("🎵 磁带音效开关切换: \(newValue)")
                    }
                    
                    Toggle("触觉反馈", isOn: Binding(
                        get: { musicService.isHapticFeedbackEnabled },
                        set: { newValue in
                            musicService.setHapticFeedback(enabled: newValue)
                        }
                    ))
                    .sensoryFeedback(.selection, trigger: musicService.isHapticFeedbackEnabled)
                    
                    Toggle("屏幕常亮", isOn: $isScreenAlwaysOn)
                }
                
                // 支持我们
                Section(header: Text("支持我们")) {
                    NavigationLink("给我们五星好评") {
                        Text("五星好评页面")
                    }
                    NavigationLink("把应用推荐给朋友") {
                        Text("分享页面")
                    }
                    NavigationLink("常见问题") {
                        Text("FAQ页面")
                    }
                    NavigationLink("意见反馈") {
                        Text("反馈页面")
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
                        destination: URL(string: WebLink.privacyPolicy.rawValue)!
                    )
                    
                    // 修改使用条款链接
                    LinkRow(
                        title: String(localized:"使用条款"),
                        destination: URL(string: WebLink.termsOfUse.rawValue)!
                    )
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
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

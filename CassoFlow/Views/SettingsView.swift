import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @State private var isSoundEnabled = true
    @State private var isHapticEnabled = true
    @State private var isScreenAlwaysOn = true
    
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
                    NavigationLink(destination: Text("音乐服务设置")) {
                        HStack {
                            Text("音乐提供商")
                            Spacer()
                            Text("Spotify")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("音效", isOn: $isSoundEnabled)
                    Toggle("触觉反馈", isOn: $isHapticEnabled)
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
                    NavigationLink("隐私政策") {
                        Text("隐私政策页面")
                    }
                    NavigationLink("使用条款") {
                        Text("使用条款页面")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
}

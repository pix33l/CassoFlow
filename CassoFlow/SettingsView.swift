

import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        NavigationStack {
            List {
                // 外观设置
                Section(header: Text("外观设置")) {
                    Picker("主题模式", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // 语言设置
                Section(header: Text("语言设置")) {
                    Picker("应用语言", selection: $selectedLanguage) {
                        Text("跟随系统").tag("auto")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // 关于与支持
                Section {
                    NavigationLink("意见反馈") {
                        FeedbackView()
                    }
                    
                    NavigationLink("隐私政策") {
                        WebView(url: URL(string: "https://yourdomain.com/privacy")!)
                    }
                    
                    NavigationLink("使用条款") {
                        WebView(url: URL(string: "https://yourdomain.com/terms")!)
                    }
                    
                    NavigationLink("关于作者") {
                        AboutView(version: appVersion)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 主题枚举
enum AppTheme: String, CaseIterable {
    case light, dark, system
    
    var displayName: String {
        switch self {
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        case .system: return "跟随系统"
        }
    }
}

// 反馈视图
struct FeedbackView: View {
    @State private var feedbackText = ""
    
    var body: some View {
        Form {
            TextField("请输入您的反馈意见", text: $feedbackText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 200)
            
            Button("提交反馈") {
                // 实现反馈提交逻辑
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("意见反馈")
    }
}

// 关于视图
struct AboutView: View {
    let version: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "info.circle")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("磁带音乐播放器")
                .font(.title)
            
            Text("版本: \(version)")
                .foregroundColor(.secondary)
            
            Text("开发者: YourName")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("关于")
    }
}

// Web视图(用于显示条款和隐私政策)
struct WebView: View {
    let url: URL
    
    var body: some View {
        // 实际项目中可以使用WKWebView
        Text("网页内容: \(url.absoluteString)")
            .navigationTitle("网页浏览")
    }
}

#Preview {
    SettingsView()
}


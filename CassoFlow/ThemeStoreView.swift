import SwiftUI

struct ThemeStoreView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var musicPlayer: MusicPlayerService
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                // 改为TabView展示
                TabView(selection: $selectedTab) {
                    ForEach(TapeTheme.allCases, id: \.self) { theme in
                        ThemeDetailView(theme: theme)
                            .tag(TapeTheme.allCases.firstIndex(of: theme) ?? 0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // 底部操作区域
                ThemeActionView(
                    selectedTheme: TapeTheme.allCases[selectedTab],
                    isCurrentTheme: musicPlayer.currentTapeTheme == TapeTheme.allCases[selectedTab]
                )
                .padding()
            }
            .navigationTitle("磁带主题商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await purchaseManager.setupProducts()
            }
        }
    }
}

// 新增主题详情视图
struct ThemeDetailView: View {
    let theme: TapeTheme
    
    var body: some View {
        VStack {
            Image(theme.rawValue)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
    }
}

// 新增底部操作视图
struct ThemeActionView: View {
    let selectedTheme: TapeTheme
    let isCurrentTheme: Bool
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var musicPlayer: MusicPlayerService
    
    var body: some View {
        VStack(spacing: 12) {
            Text(selectedTheme.rawValue)
                .font(.title2.bold())
            
            if selectedTheme.isLocked && !purchaseManager.purchasedThemes.contains(selectedTheme) {
                VStack {
                    Text("¥6.00") // 这里可以根据实际产品价格调整
                        .font(.headline)
                    
                    Button("购买主题") {
                        Task { await purchaseManager.purchaseTheme(selectedTheme) }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            } else if isCurrentTheme {
                Text("正在使用")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Button("使用主题") {
                    musicPlayer.changeTapeTheme(selectedTheme)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview("默认") {
    let purchaseManager = PurchaseManager()
    let musicPlayer = MusicPlayerService()
    ThemeStoreView()
        .environmentObject(musicPlayer)
        .environmentObject(purchaseManager)
}

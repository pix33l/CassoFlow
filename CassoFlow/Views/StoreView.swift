import SwiftUI

struct StoreView: View {
    // MARK: - 属性
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    @State private var selectedSkinIndex = 0
    
    // 使用集中定义的皮肤
    private var skins: [Skin] { Skin.allSkins }
    
    // MARK: - 主体视图
    var body: some View {
        VStack(spacing: 20) {
            headerView
            skinCarousel
            purchaseButton
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 子视图
    
    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            Text("皮肤商店")
                .font(.title.bold())
            
            Spacer()
            
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    /// 皮肤轮播区域
    private var skinCarousel: some View {
        TabView(selection: $selectedSkinIndex) {
            ForEach(Array(skins.enumerated()), id: \.offset) { index, skin in
                SkinCardView(skin: skin)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 500)
    }
    
    /// 购买/使用按钮
    private var purchaseButton: some View {
        Button {
            applySelectedSkin()
        } label: {
            Text(buttonTitle)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackgroundColor)
                .foregroundColor(buttonForegroundColor)
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    // MARK: - 计算属性
    
    private var currentSkin: Skin {
        skins[selectedSkinIndex]
    }
    
    private var buttonTitle: String {
        currentSkin.isOwned ? "使用" : "¥\(currentSkin.price)"
    }
    
    private var buttonBackgroundColor: Color {
        currentSkin.isOwned ? Color.blue : Color.white
    }
    
    private var buttonForegroundColor: Color {
        currentSkin.isOwned ? Color.white : Color.black
    }
    
    // MARK: - 方法
    
    private func applySelectedSkin() {
        musicService.currentSkin = currentSkin
        dismiss()
    }
}

// MARK: - 皮肤数据模型
struct Skin: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String
    let price: Int
    var isOwned: Bool
    let backgroundColor: Color
    
    // 集中定义所有皮肤
    static let allSkins: [Skin] = [
        Skin(
            name: "经典磁带",
            description: "复古磁带播放器外观，重温经典音乐体验",
            imageName: "CF-001",
            price: 12,
            isOwned: false,
            backgroundColor: Color("cassetteLight")
        ),
        Skin(
            name: "未来科技",
            description: "炫酷科技感设计，带来未来音乐体验",
            imageName: "CF-003",
            price: 12,
            isOwned: false,
            backgroundColor: Color("bg-CF-001")
        ),
        Skin(
            name: "CF-101",
            description: "1972",
            imageName: "CF-101",
            price: 12,
            isOwned: false,
            backgroundColor: Color("bg-CF-101")
        )
    ]
    
    // 提供默认皮肤快捷访问
    static let defaultSkin = allSkins[0]
    static let premiumSkin = allSkins[1]
    static let darkSkin = allSkins[2]
}

// MARK: - 皮肤卡片视图
struct SkinCardView: View {
    let skin: Skin
    
    var body: some View {
        VStack(spacing: 20) {
            // 皮肤主图
            Image(skin.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 400)
                .padding()
                .cornerRadius(12)
                .padding(.horizontal)
            
            // 皮肤信息
            VStack(spacing: 8) {
                Text(skin.name)
                    .font(.title2.bold())
                
                Text(skin.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }
}

#Preview {
    StoreView()
        .environmentObject(MusicService.shared)
}

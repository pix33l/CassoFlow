import SwiftUI

struct StoreView: View {
    // MARK: - 属性
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    @State private var selectedSegment = 0
    @State private var selectedSkinIndex: Int
    
    // 初始化时设置当前皮肤索引
    init() {
        let currentSkin = MusicService.shared.currentSkin
        _selectedSkinIndex = State(initialValue: Skin.allSkins.firstIndex(where: { $0.id == currentSkin.id }) ?? 0)
    }
    
    // 使用集中定义的皮肤
    private var skins: [Skin] { Skin.allSkins }
    
    // MARK: - 主体视图
    var body: some View {
        NavigationView {
            VStack {
/*                HStack {
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
*/
                
                // 分段控制器
                Picker("商品类型", selection: $selectedSegment) {
                    Text("播放器").tag(0)
                    Text("磁带").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedSkinIndex) {
                    ForEach(Array(skins.enumerated()), id: \.offset) { index, skin in
                        SkinCardView(skin: skin)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 550)
                
                Spacer()
                
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
            .navigationTitle("商店")
            .navigationBarTitleDisplayMode(.inline)
        }
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
    let buttonColor: Color
    let buttonTextColor: Color
    let buttonOutlineColor: Color
    let screenColor: Color
    let screenTextColor: Color
    let screenOutlineColor: Color
    let playerImage: String
    let cassetteImage: String
    let cassetteHole: String
    
    // 集中定义所有皮肤
    static let allSkins: [Skin] = [
        Skin(
            name: "CF-0",
            description: "1988",
            imageName: "CF-001",
            price: 12,
            isOwned: true,
            backgroundColor: Color("cassetteLight"),
            buttonColor: Color("cassetteLight"),
            buttonTextColor: Color("cassetteDark"),
            buttonOutlineColor: Color("cassetteDark"),
            screenColor: Color("cassetteLight"),
            screenTextColor: Color("cassetteDark"),
            screenOutlineColor: Color("cassetteDark"),
            playerImage: "cover-CF-001",
            cassetteImage: "cassette",
            cassetteHole: "hole"
        ),
        Skin(
            name: "CF-L2",
            description: "1985",
            imageName: "CF-L2",
            price: 12,
            isOwned: false,
            backgroundColor: Color("bg-CF-11"),
            buttonColor: Color("bg-button-CF-11"),
            buttonTextColor: Color("text-screen-CF-11"),
            buttonOutlineColor: Color("bg-button-CF-11"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "cover-CF-L2",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        ),
        Skin(
            name: "CF-101",
            description: "1972",
            imageName: "CF-101",
            price: 12,
            isOwned: false,
            backgroundColor: .black,
            buttonColor: .black,
            buttonTextColor: .white,
            buttonOutlineColor: .black,
            screenColor: Color("bg-screen-CF-11"),
            screenTextColor: Color("text-screen-CF-11"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "cover-CF-101",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        ),
        Skin(
            name: "CF-DT1",
            description: "1993",
            imageName: "CF-101",
            price: 12,
            isOwned: true,
            backgroundColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonOutlineColor: .clear,
            screenColor: Color("bg-screen-CF-11"),
            screenTextColor: Color("text-screen-CF-11"),
            screenOutlineColor: .black,
            playerImage: "cover-CF-DT1",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        )
    ]
    
    // 提供默认皮肤快捷访问
    static let defaultSkin = allSkins[0]
    static let CFL2 = allSkins[1]
    static let darkSkin = allSkins[2]
    static let CFDT1 = allSkins[3]
}

// MARK: - 皮肤卡片视图
struct SkinCardView: View {
    let skin: Skin
    
    var body: some View {
        VStack(spacing: 10) {
            // 皮肤主图
            Image(skin.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .padding()
            
            // 皮肤信息
            VStack(spacing: 5) {
                Text(skin.name)
                    .font(.title2.bold())
                
                Text(skin.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    StoreView()
        .environmentObject(MusicService.shared)
}

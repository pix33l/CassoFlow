import SwiftUI

struct StoreView: View {
    // MARK: - 属性
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    @State private var selectedSegment = 0
    @State private var selectedPlayerName: String
    @State private var selectedCassetteName: String
    
    // 数据集
    private var playerSkins: [PlayerSkin] { PlayerSkin.playerSkins }
    private var cassetteSkins: [CassetteSkin] { CassetteSkin.cassetteSkins }
    
    // 初始化设置
    init() {
        _selectedPlayerName = State(initialValue: MusicService.shared.currentPlayerSkin.name)
        _selectedCassetteName = State(initialValue: MusicService.shared.currentCassetteSkin.name)
    }
    
    // 根据选项卡显示正确内容
    var currentSkinType: (PlayerSkin?, CassetteSkin?) {
        if selectedSegment == 0 {
            return (playerSkins.first { $0.name == selectedPlayerName }, nil)
        } else {
            return (nil, cassetteSkins.first { $0.name == selectedCassetteName })
        }
    }
    
    // MARK: - 主体视图
    var body: some View {
        NavigationView {
            VStack {
                // 分段控制器
                Picker("商品类型", selection: $selectedSegment) {
                    Text("播放器").tag(0)
                    Text("磁带").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // TabView根据选项卡选择展示不同内容
                TabView(selection: Binding<AnyHashable>(
                    get: {
                        selectedSegment == 0 ? AnyHashable(selectedPlayerName) : AnyHashable(selectedCassetteName)
                    },
                    set: {
                        if let name = $0.base as? String {
                            if selectedSegment == 0 { selectedPlayerName = name }
                            else { selectedCassetteName = name }
                        }
                    }
                )) {
                    if selectedSegment == 0 {
                        ForEach(playerSkins, id: \.name) { skin in
                            SkinCardView(playerSkin: skin, cassetteSkin: nil)
                                .tag(skin.name as AnyHashable)
                        }
                    } else {
                        ForEach(cassetteSkins, id: \.name) { skin in
                            SkinCardView(playerSkin: nil, cassetteSkin: skin)
                                .tag(skin.name as AnyHashable)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 580)
                
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
                .padding(.bottom, 20)
            }
            .navigationTitle("商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
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
        }
    }
    
    // MARK: - 计算属性
    private var buttonTitle: String {
        if let playerSkin = currentSkinType.0, playerSkin.isOwned {
            return "使用"
        } else if let cassetteSkin = currentSkinType.1, cassetteSkin.isOwned {
            return "使用"
        } else if let playerSkin = currentSkinType.0 {
            return "¥\(playerSkin.price)"
        } else if let cassetteSkin = currentSkinType.1 {
            return "¥\(cassetteSkin.price)"
        }
        return "获取皮肤"
    }
    
    private var buttonBackgroundColor: Color {
        if let playerSkin = currentSkinType.0, playerSkin.isOwned {
            return Color.blue
        } else if let cassetteSkin = currentSkinType.1, cassetteSkin.isOwned {
            return Color.blue
        }
        return Color.white
    }
    
    private var buttonForegroundColor: Color {
        if let playerSkin = currentSkinType.0, playerSkin.isOwned {
            return Color.white
        } else if let cassetteSkin = currentSkinType.1, cassetteSkin.isOwned {
            return Color.white
        }
        return Color.black
    }
    
    // MARK: - 方法
    private func applySelectedSkin() {
        if let playerSkin = currentSkinType.0 {
            // 使用 setPlayerSkin 方法来保存皮肤选择
            musicService.setPlayerSkin(playerSkin)
        } else if let cassetteSkin = currentSkinType.1 {
            // 使用 setCassetteSkin 方法来保存皮肤选择
            musicService.setCassetteSkin(cassetteSkin)
        }
        dismiss()
    }
}

// MARK: - 皮肤卡片视图
struct SkinCardView: View {
    let playerSkin: PlayerSkin?
    let cassetteSkin: CassetteSkin?
    
    var body: some View {
        VStack(spacing: 10) {
            if let playerSkin = playerSkin {
                // 显示播放器皮肤
                Image(playerSkin.coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .padding(.bottom)
                
                VStack(spacing: 5) {
                    Text(playerSkin.name)
                        .font(.title2.bold())
                    
                    Text(playerSkin.year)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(playerSkin.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity)
            } else if let cassetteSkin = cassetteSkin {
                // 显示磁带皮肤
                Image(cassetteSkin.cassetteImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 380)
                    .padding()
                
                VStack(spacing: 5) {
                    Text(cassetteSkin.name)
                        .font(.title2.bold())
                    
                    Text(cassetteSkin.year)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    StoreView()
        .environmentObject(MusicService.shared)
}

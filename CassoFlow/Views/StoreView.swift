import SwiftUI

struct StoreView: View {
    // MARK: - 属性
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var storeManager = StoreManager()
    @Environment(\.dismiss) var dismiss
    @State private var selectedSegment = 0
    @State private var selectedPlayerName: String
    @State private var selectedCassetteName: String
    
    @State private var closeTapped = false
    @State private var applyTapped = false
    @State private var purchaseInProgress = false
    
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
                .onChange(of: selectedSegment) { _, _ in
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
                
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
                            SkinCardView(
                                playerSkin: skin,
                                cassetteSkin: nil,
                                storeManager: storeManager
                            )
                            .tag(skin.name as AnyHashable)
                        }
                    } else {
                        ForEach(cassetteSkins, id: \.name) { skin in
                            SkinCardView(
                                playerSkin: nil,
                                cassetteSkin: skin,
                                storeManager: storeManager
                            )
                            .tag(skin.name as AnyHashable)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 580)
                .onChange(of: selectedSegment == 0 ? selectedPlayerName : selectedCassetteName) { _, _ in
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
                
                Spacer()
                
                // 主操作按钮
                Button {
                    applyTapped.toggle()
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                    handleMainButtonAction()
                } label: {
                    HStack {
                        if purchaseInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: buttonForegroundColor))
                                .scaleEffect(0.8)
                        }
                        
                        Text(buttonTitle)
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonBackgroundColor)
                    .foregroundColor(buttonForegroundColor)
                    .cornerRadius(10)
                    .opacity(purchaseInProgress ? 0.7 : 1.0)
                }
                .disabled(purchaseInProgress || storeManager.isLoading)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        closeTapped.toggle()
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
            .alert("提示", isPresented: $storeManager.showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(storeManager.alertMessage)
            }
            .task {
                // 页面加载时获取产品信息
                await storeManager.fetchProducts()
            }
        }
    }
    
    // MARK: - 计算属性
    private var buttonTitle: String {
        if let playerSkin = currentSkinType.0 {
            if isCurrentSkinOwned() {
                return "使用"
            } else {
                return SkinHelper.getPlayerSkinPrice(playerSkin.name, storeManager: storeManager)
            }
        } else if let cassetteSkin = currentSkinType.1 {
            if isCurrentSkinOwned() {
                return "使用"
            } else {
                return SkinHelper.getCassetteSkinPrice(cassetteSkin.name, storeManager: storeManager)
            }
        }
        return "获取皮肤"
    }
    
    private var buttonBackgroundColor: Color {
        if isCurrentSkinOwned() {
            return Color.blue
        }
        return Color.white
    }
    
    private var buttonForegroundColor: Color {
        if isCurrentSkinOwned() {
            return Color.white
        }
        return Color.black
    }
    
    // MARK: - 私有方法
    
    /// 检查当前选中的皮肤是否已拥有
    private func isCurrentSkinOwned() -> Bool {
        if let playerSkin = currentSkinType.0 {
            return SkinHelper.isPlayerSkinOwned(playerSkin.name, storeManager: storeManager)
        } else if let cassetteSkin = currentSkinType.1 {
            return SkinHelper.isCassetteSkinOwned(cassetteSkin.name, storeManager: storeManager)
        }
        return false
    }
    
    /// 处理主按钮操作（使用或购买）
    private func handleMainButtonAction() {
        if isCurrentSkinOwned() {
            // 已拥有，直接使用
            applySelectedSkin()
        } else {
            // 未拥有，进行购买
            Task {
                await purchaseCurrentSkin()
            }
        }
    }
    
    /// 购买当前选中的皮肤
    private func purchaseCurrentSkin() async {
        purchaseInProgress = true
        
        var productID = ""
        
        if let playerSkin = currentSkinType.0 {
            productID = SkinHelper.getPlayerSkinProductID(playerSkin.name)
        } else if let cassetteSkin = currentSkinType.1 {
            productID = SkinHelper.getCassetteSkinProductID(cassetteSkin.name)
        }
        
        guard !productID.isEmpty,
              let product = storeManager.getProduct(for: productID) else {
            purchaseInProgress = false
            storeManager.alertMessage = "无法找到该产品信息"
            storeManager.showAlert = true
            return
        }
        
        let result = await storeManager.purchase(product)
        
        switch result {
        case .success(let message):
            storeManager.alertMessage = message
            storeManager.showAlert = true
            // 购买成功后自动应用皮肤
            applySelectedSkin()
            
        case .cancelled:
            break // 用户取消，不显示提示
            
        case .failed(let errorMessage):
            storeManager.alertMessage = errorMessage
            storeManager.showAlert = true
            
        case .pending:
            storeManager.alertMessage = "购买正在处理中，请稍后查看。"
            storeManager.showAlert = true
        }
        
        purchaseInProgress = false
    }
    
    /// 应用选中的皮肤
    private func applySelectedSkin() {
        if let playerSkin = currentSkinType.0 {
            musicService.setPlayerSkin(playerSkin)
        } else if let cassetteSkin = currentSkinType.1 {
            musicService.setCassetteSkin(cassetteSkin)
        }
        dismiss()
    }
}

// MARK: - 皮肤卡片视图
struct SkinCardView: View {
    let playerSkin: PlayerSkin?
    let cassetteSkin: CassetteSkin?
    let storeManager: StoreManager
    
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
                    
                    Text(cassetteSkin.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
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

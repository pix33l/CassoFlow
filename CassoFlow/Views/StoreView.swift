import SwiftUI

struct StoreView: View {
    // MARK: - 属性
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedSegment = 0
    @State private var selectedPlayerName: String = ""
    @State private var selectedCassetteName: String = ""
    
    @State private var closeTapped = false
    @State private var applyTapped = false
    @State private var purchaseInProgress = false
    @State private var showingPaywall = false

    // 数据集
    private var playerSkins: [PlayerSkin] { PlayerSkin.playerSkins }
    private var cassetteSkins: [CassetteSkin] { CassetteSkin.cassetteSkins }
    
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
                
                Spacer()
                
                if selectedSegment == 0 {
                    // 播放器皮肤TabView
                    TabView(selection: $selectedPlayerName) {
                        ForEach(playerSkins, id: \.name) { skin in
                            SkinCardView(
                                playerSkin: skin,
                                cassetteSkin: nil,
                                storeManager: storeManager
                            )
                            .tag(skin.name)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .onChange(of: selectedPlayerName) { _, _ in
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                } else {
                    // 磁带皮肤TabView
                    TabView(selection: $selectedCassetteName) {
                        ForEach(cassetteSkins, id: \.name) { skin in
                            SkinCardView(
                                playerSkin: nil,
                                cassetteSkin: skin,
                                storeManager: storeManager
                            )
                            .tag(skin.name)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .onChange(of: selectedCassetteName) { _, _ in
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
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
                .disabled(purchaseInProgress || storeManager.isLoading || isCurrentSkinInUse())
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
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
            .fullScreenCover(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
                    .environmentObject(musicService)
            }
            .task {
                // 页面加载时获取产品信息
                await storeManager.fetchProducts()
            }
            .onAppear {
                selectedPlayerName = musicService.currentPlayerSkin.name
                selectedCassetteName = musicService.currentCassetteSkin.name
                print("🏪 StoreView onAppear - 播放器皮肤: \(selectedPlayerName), 磁带皮肤: \(selectedCassetteName)")
            }
        }
    }
    
    // MARK: - 计算属性
    private var buttonTitle: String {
        if isCurrentSkinInUse() {
            return String(localized: "使用中")
        } else if isCurrentSkinOwned() {
            return String(localized: "选择")
        } else {
            if let playerSkin = currentSkinType.0 {
                return SkinHelper.getPlayerSkinPrice(playerSkin.name, storeManager: storeManager)
            } else if let cassetteSkin = currentSkinType.1 {
                return SkinHelper.getCassetteSkinPrice(cassetteSkin.name, storeManager: storeManager)
            }
        }
        return String(localized: "皮肤数据异常")
    }
    
    private var buttonBackgroundColor: Color {
        if isCurrentSkinInUse() {
            return Color.gray.opacity(0.3)
        } else if isCurrentSkinOwned() {
            return Color.white
        }
        // 会员用户对于收费皮肤也显示蓝色背景
        if storeManager.membershipStatus.isActive && !isFreeSkin() {
            return Color.yellow
        }
        return Color.yellow
    }
    
    private var buttonForegroundColor: Color {
        if isCurrentSkinInUse() {
            return Color.secondary
        } else if isCurrentSkinOwned() {
            return Color.black
        }
        // 会员用户对于收费皮肤也显示白色文字
        if storeManager.membershipStatus.isActive && !isFreeSkin() {
            return Color.black
        }
        return Color.black
    }
    
    // MARK: - 私有方法
    
    /// 检查当前选中的皮肤是否正在使用中
    private func isCurrentSkinInUse() -> Bool {
        if let playerSkin = currentSkinType.0 {
            return musicService.currentPlayerSkin.name == playerSkin.name
        } else if let cassetteSkin = currentSkinType.1 {
            return musicService.currentCassetteSkin.name == cassetteSkin.name
        }
        return false
    }
    
    /// 检查当前选中的皮肤是否已拥有
    private func isCurrentSkinOwned() -> Bool {
        if let playerSkin = currentSkinType.0 {
            return SkinHelper.isPlayerSkinOwned(playerSkin.name, storeManager: storeManager)
        } else if let cassetteSkin = currentSkinType.1 {
            return SkinHelper.isCassetteSkinOwned(cassetteSkin.name, storeManager: storeManager)
        }
        return false
    }
    
    /// 检查当前皮肤是否为免费皮肤
    private func isFreeSkin() -> Bool {
        if let playerSkin = currentSkinType.0 {
            return playerSkin.isFreeDefaultSkin()
        } else if let cassetteSkin = currentSkinType.1 {
            return cassetteSkin.isFreeDefaultSkin()
        }
        return false
    }
    
    /// 检查当前皮肤是否为会员专享皮肤
    private func isMemberExclusiveSkin() -> Bool {
        if let playerSkin = currentSkinType.0 {
            return playerSkin.isMemberExclusiveSkin()
        } else if let cassetteSkin = currentSkinType.1 {
            return cassetteSkin.isMemberExclusiveSkin()
        }
        return false
    }
    
    /// 处理主按钮操作（使用或购买）
    private func handleMainButtonAction() {
        // 如果是正在使用中的皮肤，不执行任何操作
        if isCurrentSkinInUse() {
            return
        }
        
        if isCurrentSkinOwned() {
            // 已拥有，直接使用
            applySelectedSkin()
        } else {
            // 检查是否为会员专享皮肤且用户不是会员
            if isMemberExclusiveSkin() && !storeManager.membershipStatus.isActive {
                // 会员专享皮肤，非会员用户跳转到 PaywallView
                showingPaywall = true
                return
            }
            
            // 检查是否为会员用户
            if storeManager.membershipStatus.isActive {
                // 会员用户可以直接使用所有皮肤
                applySelectedSkin()
            } else {
                // 非会员用户需要购买皮肤
                Task {
                    await purchaseCurrentSkin()
                }
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
        
        // 如果是会员专享皮肤，不执行购买逻辑
        if isMemberExclusiveSkin() {
            purchaseInProgress = false
            showingPaywall = true
            return
        }
        
        guard !productID.isEmpty,
              let product = storeManager.getProduct(for: productID) else {
            purchaseInProgress = false
            storeManager.alertMessage = String(localized: "无法找到该产品信息")
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
            storeManager.alertMessage = String(localized: "购买正在处理中，请稍后查看")
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
                if !storeManager.membershipStatus.isActive {
                    PayLabel()
                        .environmentObject(storeManager)
                }
                
                Image(playerSkin.coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 500)
                    .padding()
                
                VStack(spacing: 5) {
                    Text(playerSkin.name)
                        .font(.title2.bold())
                    
//                    Text(playerSkin.year)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .padding(.bottom, 10)
                    
                    Text(playerSkin.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity)
                
            } else if let cassetteSkin = cassetteSkin {
                // 显示磁带皮肤
                if !storeManager.membershipStatus.isActive {
                    PayLabel()
                        .environmentObject(storeManager)
                }
                
                Image(cassetteSkin.coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 500)
                    .padding()
                
                VStack(spacing: 5) {
                    Text(cassetteSkin.name)
                        .font(.title2.bold())
                    
//                    Text(cassetteSkin.year)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .padding(.bottom, 10)
                    
                    Text(cassetteSkin.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 50)
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

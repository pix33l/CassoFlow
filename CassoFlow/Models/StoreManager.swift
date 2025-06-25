//
//  StoreManager.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/5/26.
//

import StoreKit
import Foundation

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var ownedProducts: Set<String> = []
    
    @Published var membershipStatus: MembershipStatus = .notMember
    @Published var subscriptionExpirationDate: Date?
    
    private var transactionUpdateTask: Task<Void, Never>?
    
    enum MembershipStatus {
        case notMember
        case lifetimeMember
        case monthlyMember(expiresOn: Date)
        case yearlyMember(expiresOn: Date)
        
        var isActive: Bool {
            switch self {
            case .notMember:
                return false
            case .lifetimeMember:
                return true
            case .monthlyMember(let expiresOn), .yearlyMember(let expiresOn):
                return expiresOn > Date()
            }
        }
        
        var displayText: String {
            switch self {
            case .notMember:
                return String(localized:"升级 PRO 会员，获取全部高级功能")
            case .lifetimeMember:
                return String(localized:"尊贵的永久 Pro 会员")
            case .monthlyMember(let expiresOn), .yearlyMember(let expiresOn):
                let formatter = DateFormatter()
                // 使用系统的本地化日期格式
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                // 使用当前用户的区域设置
                formatter.locale = Locale.current
                return String(localized:"Pro 会员将在\(formatter.string(from: expiresOn))到期")
            }
        }
        
        var shouldShowUpgradeButton: Bool {
            switch self {
            case .notMember:
                return true
            case .lifetimeMember, .monthlyMember, .yearlyMember:
                return false
            }
        }
    }

    // MARK: - 购买状态枚举
    enum PurchaseResult {
        case success(String)
        case cancelled
        case failed(String)
        case pending
    }
    
    // MARK: - 产品ID常量
    struct ProductIDs {
        // 会员订阅
        static let lifetime = "me.pix3l.CassoFlow.Lifetime"
        static let yearly = "me.pix3l.CassoFlow.Yearly"
        static let monthly = "me.pix3l.CassoFlow.Monthly"
        
        // 播放器皮肤
        static let cfPC13 = "me.pix3l.CassoFlow.CF_PC13"
        static let cfM10 = "me.pix3l.CassoFlow.CF_M10"
        static let cfMU = "me.pix3l.CassoFlow.CF_MU"
        static let cfL2 = "me.pix3l.CassoFlow.CF_L2"
        static let cf2 = "me.pix3l.CassoFlow.CF_2"
        static let cf22 = "me.pix3l.CassoFlow.CF_22"
        static let cf504 = "me.pix3l.CassoFlow.CF_504"
        static let cfD6C = "me.pix3l.CassoFlow.CF_D6C"
        static let cfDT1 = "me.pix3l.CassoFlow.CF_DT1"
        
        // 磁带皮肤
        static let cftW60 = "me.pix3l.CassoFlow.CFT_W60"
        static let cftC60 = "me.pix3l.CassoFlow.CFT_C60"
        static let cft60CR = "me.pix3l.CassoFlow.CFT_60CR"
        static let cftMM = "me.pix3l.CassoFlow.CFT_MM"
        
        // 所有产品ID
        static let allProducts = [
            lifetime, yearly, monthly,
            cfPC13, cfM10, cfMU, cfL2, cf2, cf22, cf504, cfD6C, cfDT1,
            cftW60, cftC60, cft60CR, cftMM
        ]
    }
    
    init() {
        // 启动时检查已拥有的产品
        Task {
            await loadOwnedProducts()
            await updateMembershipStatus()
        }
        
        startTransactionListener()
    }
    
    private func startTransactionListener() {
        transactionUpdateTask = Task {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    print("✅ 收到交易更新: \(transaction.productID)")
                    await handleTransactionUpdate(transaction)
                case .unverified(let transaction, let error):
                    print("❌ 未验证的交易更新: \(transaction.productID), 错误: \(error)")
                }
            }
        }
    }
    
    private func handleTransactionUpdate(_ transaction: Transaction) async {
        // 完成交易
        await transaction.finish()
        
        // 更新拥有的产品列表
        ownedProducts.insert(transaction.productID)
        
        // 解锁相应功能
        await handleSuccessfulPurchase(transaction)
        
        print("🔄 交易已处理并完成: \(transaction.productID)")
    }
    
    deinit {
        transactionUpdateTask?.cancel()
    }

    // MARK: - 获取产品信息
    func fetchProducts() async {
        isLoading = true
        
        do {
            products = try await Product.products(for: ProductIDs.allProducts)
            print("✅ 成功加载 \(products.count) 个产品")
            
            // 排序产品：会员产品在前，皮肤产品在后
            products.sort { product1, product2 in
                let membershipProducts = [ProductIDs.lifetime, ProductIDs.yearly, ProductIDs.monthly]
                let isMembership1 = membershipProducts.contains(product1.id)
                let isMembership2 = membershipProducts.contains(product2.id)
                
                if isMembership1 && !isMembership2 {
                    return true
                } else if !isMembership1 && isMembership2 {
                    return false
                } else {
                    return product1.displayPrice < product2.displayPrice
                }
            }
            
        } catch {
            print("❌ 加载商品失败: \(error)")
            showErrorAlert("加载商品失败: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - 购买产品
    func purchase(_ product: Product) async -> PurchaseResult {
        isLoading = true
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // ✅ 购买成功，解锁功能
                    await handleSuccessfulPurchase(transaction)
                    await transaction.finish()
                    isLoading = false
                    return .success(String(localized: "购买成功！已为您解锁内容"))
                    
                case .unverified(_, let error):
                    print("❌ 购买验证失败: \(error)")
                    isLoading = false
                    return .failed(String(localized: "购买验证失败，请稍后重试"))
                }
                
            case .userCancelled:
                print("ℹ️ 用户取消购买")
                isLoading = false
                return .cancelled
                
            case .pending:
                print("⏳ 购买等待中")
                isLoading = false
                return .pending
                
            @unknown default:
                print("❓ 未知购买结果")
                isLoading = false
                return .failed(String(localized: "购买失败，未知错误"))
            }
            
        } catch {
            print("❌ 购买出错: \(error)")
            isLoading = false
            return .failed(String(localized: "购买失败: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - 恢复购买
    func restorePurchases() async {
        isLoading = true
        var restoredCount = 0
        var restoredItems: [String] = []
        
        // 遍历所有当前有效的交易
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let productName = await handleSuccessfulPurchase(transaction)
                await transaction.finish()
                if let name = productName {
                    restoredCount += 1
                    restoredItems.append(name)
                }
            }
        }
        
        // 显示恢复结果
        if restoredCount > 0 {
            let itemList = restoredItems.joined(separator: "、")
            showSuccessAlert(String(localized: "成功恢复 \(restoredCount) 个购买项目：\(itemList)"))
            print("✅ 成功恢复 \(restoredCount) 个购买项目")
        } else {
            showInfoAlert(String(localized: "没有找到可恢复的购买项目"))
            print("ℹ️ 没有找到可恢复的购买项目")
        }
        
        isLoading = false
    }
    
    // MARK: - 处理成功购买/恢复
    @discardableResult
    private func handleSuccessfulPurchase(_ transaction: Transaction) async -> String? {
        let productID = transaction.productID
        ownedProducts.insert(productID)
        
        // 根据产品ID解锁相应功能
        let result: String?
        switch productID {
        // 会员产品
        case ProductIDs.lifetime:
            unlockPremiumFeatures()
            result = "终身会员"
            
        case ProductIDs.yearly:
            unlockPremiumFeatures()
            result = "年度会员"
            
        case ProductIDs.monthly:
            unlockPremiumFeatures()
            result = "月度会员"
            
        // 播放器皮肤
        case ProductIDs.cfPC13:
            unlockPlayerSkin("CF-PC13")
            result = "CF-PC13"
            
        case ProductIDs.cfM10:
            unlockPlayerSkin("CF-M10")
            result = "CF-M10"
            
        case ProductIDs.cfMU:
            unlockPlayerSkin("CF-MU")
            result = "CF-MU"
            
        case ProductIDs.cfL2:
            unlockPlayerSkin("CF-L2")
            result = "CF-L2"
            
        case ProductIDs.cf2:
            unlockPlayerSkin("CF-2")
            result = "CF-2"
            
        case ProductIDs.cf22:
            unlockPlayerSkin("CF-22")
            result = "CF-22"
            
        case ProductIDs.cf504:
            unlockPlayerSkin("CF-504")
            result = "CF-504"
            
        case ProductIDs.cfD6C:
            unlockPlayerSkin("CF-D6C")
            result = "CF-D6C"
            
        case ProductIDs.cfDT1:
            unlockPlayerSkin("CF-DT1")
            result = "CF-DT1"
            
        // 磁带皮肤
        case ProductIDs.cftW60:
            unlockCassetteSkin("CFT-TRA")
            result = "CFT-TRA"
            
        case ProductIDs.cftC60:
            unlockCassetteSkin("CFT-C60")
            result = "CFT-C60"
            
        case ProductIDs.cftC60:
            unlockCassetteSkin("CFT-60CR")
            result = "CFT-60CR"
            
        case ProductIDs.cftMM:
            unlockCassetteSkin("CFT-MM")
            result = "CFT-MM"
            
        default:
            print("⚠️ 未知产品ID: \(productID)")
            result = nil
        }
        
        await updateMembershipStatus()
        
        return result
    }
    
    // MARK: - 解锁功能方法
    
    /// 解锁会员功能
    private func unlockPremiumFeatures() {
        // 保存会员状态到UserDefaults
        UserDefaults.standard.set(true, forKey: "isPremiumUser")
        print(String(localized: "已解锁会员功能"))
    }
    
    /// 解锁播放器皮肤
    private func unlockPlayerSkin(_ skinName: String) {
        let key = "owned_player_skin_\(skinName)"
        UserDefaults.standard.set(true, forKey: key)
        print(String(localized: "已解锁播放器皮肤: \(skinName)"))
    }
    
    /// 解锁磁带皮肤
    private func unlockCassetteSkin(_ skinName: String) {
        let key = "owned_cassette_skin_\(skinName)"
        UserDefaults.standard.set(true, forKey: key)
        print(String(localized: "已解锁磁带皮肤: \(skinName)"))
    }
    
    // MARK: - 检查购买状态
    
    /// 检查是否为会员用户
    func isPremiumUser() -> Bool {
        return UserDefaults.standard.bool(forKey: "isPremiumUser") ||
               ownedProducts.contains(ProductIDs.lifetime) ||
               ownedProducts.contains(ProductIDs.yearly) ||
               ownedProducts.contains(ProductIDs.monthly)
    }
    
    /// 检查是否拥有播放器皮肤
    func ownsPlayerSkin(_ skinName: String) -> Bool {
        let key = "owned_player_skin_\(skinName)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// 检查是否拥有磁带皮肤
    func ownsCassetteSkin(_ skinName: String) -> Bool {
        let key = "owned_cassette_skin_\(skinName)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func updateMembershipStatus() async {
        // 首先检查终身会员
        if ownedProducts.contains(ProductIDs.lifetime) {
            membershipStatus = .lifetimeMember
            return
        }
        
        // 检查订阅状态
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let productID = transaction.productID
                
                // 检查订阅是否仍有效
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        switch productID {
                        case ProductIDs.yearly:
                            membershipStatus = .yearlyMember(expiresOn: expirationDate)
                            subscriptionExpirationDate = expirationDate
                            return
                        case ProductIDs.monthly:
                            membershipStatus = .monthlyMember(expiresOn: expirationDate)
                            subscriptionExpirationDate = expirationDate
                            return
                        default:
                            break
                        }
                    }
                }
            }
        }
        
        // 如果没有找到有效订阅，设为非会员
        membershipStatus = .notMember
        subscriptionExpirationDate = nil
    }
    
    // MARK: - 加载已拥有的产品
    private func loadOwnedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ownedProducts.insert(transaction.productID)
            }
        }
        print("📦 已加载 \(ownedProducts.count) 个已购买产品")
        
        await updateMembershipStatus()
    }
    
    // MARK: - 弹窗提示方法
    private func showSuccessAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func showErrorAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func showInfoAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // MARK: - 获取产品价格
    func getProductPrice(for productID: String) -> String {
        guard let product = products.first(where: { $0.id == productID }) else {
            return String(localized: "暂无价格")
        }
        return product.displayPrice
    }
    
    // MARK: - 获取产品信息
    func getProduct(for productID: String) -> Product? {
        return products.first(where: { $0.id == productID })
    }
}

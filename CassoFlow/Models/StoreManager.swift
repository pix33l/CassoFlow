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
    
    // 使用 nonisolated 标记，允许从任何线程访问
    nonisolated static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var ownedProducts: Set<String> = []
    
    @Published var membershipStatus: MembershipStatus = .notMember
    @Published var subscriptionExpirationDate: Date?
    
    private var transactionUpdateTask: Task<Void, Never>?
    
    enum MembershipStatus: Equatable {
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
                return String(localized:"尊贵的永久 PRO 会员")
            case .monthlyMember(let expiresOn), .yearlyMember(let expiresOn):
                let formatter = DateFormatter()
                // 使用系统的本地化日期格式
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                // 使用当前用户的区域设置
                formatter.locale = Locale.current
                return String(localized:"PRO 会员将在\(formatter.string(from: expiresOn))到期")
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
        static let cfMU01 = "me.pix3l.CassoFlow.CF_MU01"
        static let cfL2 = "me.pix3l.CassoFlow.CF_L2"
        static let cf2 = "me.pix3l.CassoFlow.CF_2"
        static let cf22 = "me.pix3l.CassoFlow.CF_22"
        static let cf504 = "me.pix3l.CassoFlow.CF_504"
        static let cfD6C = "me.pix3l.CassoFlow.CF_D6C"
        static let cfDD9 = "me.pix3l.CassoFlow.CF_DD9"
        static let cfDT1 = "me.pix3l.CassoFlow.CF_DT1"
        
        // 磁带皮肤
        static let cftW60 = "me.pix3l.CassoFlow.CFT_W60"
        static let cftC60 = "me.pix3l.CassoFlow.CFT_C60"
        static let cft60CR = "me.pix3l.CassoFlow.CFT_60CR"
        static let cftMM60 = "me.pix3l.CassoFlow.CFT_MM60"
        
        // 所有产品ID
        static let allProducts = [
            lifetime, yearly, monthly,
            cfPC13, cfM10, cfMU01, cfL2, cf2, cf22, cf504, cfD6C, cfDD9, cfDT1,
            cftW60, cftC60, cft60CR, cftMM60
        ]
    }
    
    nonisolated init() {
        // 异步初始化，确保在主线程上执行
        Task { @MainActor in
            // 先快速加载本地缓存的会员状态
            loadMembershipFromLocal()
            
            // 异步进行完整的在线校验
            Task {
                await loadOwnedProducts()
                await updateMembershipStatus()
            }
            
            startTransactionListener()
        }
    }
    
    private func startTransactionListener() {
        transactionUpdateTask = Task {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await handleTransactionUpdate(transaction)
                case .unverified(_, _):
                    break
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
    }

    deinit {
        transactionUpdateTask?.cancel()
    }

    // MARK: - 从本地快速加载会员状态
    private func loadMembershipFromLocal() {
        // 检查本地是否有终身会员标记
        if UserDefaults.standard.bool(forKey: "isPremiumUser") {
            membershipStatus = .lifetimeMember
            return
        }
        
        // 检查本地保存的订阅过期时间
        if let expirationDate = UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date {
            if expirationDate > Date() {
                let subscriptionType = UserDefaults.standard.string(forKey: "subscriptionType") ?? "yearly"
                switch subscriptionType {
                case "yearly":
                    membershipStatus = .yearlyMember(expiresOn: expirationDate)
                case "monthly":
                    membershipStatus = .monthlyMember(expiresOn: expirationDate)
                default:
                    membershipStatus = .yearlyMember(expiresOn: expirationDate)
                }
                subscriptionExpirationDate = expirationDate
                return
            } else {
                // 订阅过期，清除过期的订阅缓存
                UserDefaults.standard.removeObject(forKey: "subscriptionExpirationDate")
                UserDefaults.standard.removeObject(forKey: "subscriptionType")
                
                // 再次检查是否有终身会员标记
                if UserDefaults.standard.bool(forKey: "isPremiumUser") {
                    membershipStatus = .lifetimeMember
                    return
                }
            }
        }
        
        // 默认为非会员
        membershipStatus = .notMember
    }
    
    // MARK: - 获取产品信息
    func fetchProducts() async {
        isLoading = true
        
        do {
            products = try await Product.products(for: ProductIDs.allProducts)
            
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
                    // 购买成功，解锁功能
                    await handleSuccessfulPurchase(transaction)
                    await transaction.finish()
                    isLoading = false
                    return .success(String(localized: "购买成功！已为您解锁内容"))
                    
                case .unverified(_, _):
                    isLoading = false
                    return .failed(String(localized: "购买验证失败，请稍后重试"))
                }
                
            case .userCancelled:
                isLoading = false
                return .cancelled
                
            case .pending:
                isLoading = false
                return .pending
                
            @unknown default:
                isLoading = false
                return .failed(String(localized: "购买失败，未知错误"))
            }
            
        } catch {
            isLoading = false
            return .failed(String(localized: "购买失败：\(error.localizedDescription)"))
        }
    }
    
    // MARK: - 恢复购买
    func restorePurchases() async {
        isLoading = true
        var restoredCount = 0
        var restoredItems: [String] = []
        
        let restorationTask = Task {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    let productName = await handleSuccessfulPurchase(transaction)
                    // 注意：不要在这里调用 transaction.finish()，因为这是恢复购买不是新购买
                    if let name = productName {
                        restoredCount += 1
                        restoredItems.append(name)
                    }
                }
            }
        }
        
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒超时
            restorationTask.cancel()
        }
        
        // 等待恢复完成或超时
        _ = await restorationTask.value
        timeoutTask.cancel()
        
        isLoading = false
        
        // 显示恢复结果
        if restoredCount > 0 {
            let itemList = restoredItems.joined(separator: "、")
            showSuccessAlert(String(localized: "成功恢复 \(restoredCount) 个购买项目：\(itemList)"))
        } else {
            showInfoAlert(String(localized: "没有找到可恢复的购买项目"))
        }
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
            result = "永久 PRO"
            
        case ProductIDs.yearly:
            result = "年度 PRO"
            
        case ProductIDs.monthly:
            result = "月度 PRO"
            
        // 播放器皮肤
        case ProductIDs.cfPC13:
            unlockPlayerSkin("CF-PC13")
            result = "CF-PC13 播放器"
            
        case ProductIDs.cfM10:
            unlockPlayerSkin("CF-M10")
            result = "CF-M10 播放器"
            
        case ProductIDs.cfMU01:
            unlockPlayerSkin("CF-MU01")
            result = "CF-MU01 播放器"
            
        case ProductIDs.cfL2:
            unlockPlayerSkin("CF-L2")
            result = "CF-L2 播放器"
            
        case ProductIDs.cf2:
            unlockPlayerSkin("CF-2")
            result = "CF-2 播放器"
            
        case ProductIDs.cf22:
            unlockPlayerSkin("CF-22")
            result = "CF-22 播放器"
            
        case ProductIDs.cf504:
            unlockPlayerSkin("CF-504")
            result = "CF-504 播放器"
            
        case ProductIDs.cfDD9:
            unlockPlayerSkin("CF-DD9")
            result = "CF-DD9 播放器"
            
        case ProductIDs.cfD6C:
            unlockPlayerSkin("CF-D6C")
            result = "CF-D6C 播放器"
            
        case ProductIDs.cfDT1:
            unlockPlayerSkin("CF-DT1")
            result = "CF-DT1 播放器"
            
        // 磁带皮肤
        case ProductIDs.cftW60:
            unlockCassetteSkin("CFT-TRA")
            result = "CFT-TRA 磁带"
            
        case ProductIDs.cftC60:
            unlockCassetteSkin("CFT-C60")
            result = "CFT-C60 磁带"
            
        case ProductIDs.cft60CR:
            unlockCassetteSkin("CFT-60CR")
            result = "CFT-60CR 磁带"
            
        case ProductIDs.cftMM60:
            unlockCassetteSkin("CFT-MM60")
            result = "CFT-MM60 磁带"
            
        default:
            result = nil
        }

        await updateMembershipStatus()
        
        return result
    }
    
    // MARK: - 解锁功能方法
    
    /// 解锁播放器皮肤
    private func unlockPlayerSkin(_ skinName: String) {
        let key = "owned_player_skin_\(skinName)"
        UserDefaults.standard.set(true, forKey: key)
    }
    
    /// 解锁磁带皮肤
    private func unlockCassetteSkin(_ skinName: String) {
        let key = "owned_cassette_skin_\(skinName)"
        UserDefaults.standard.set(true, forKey: key)
    }
    
    // MARK: - 检查购买状态
    
    /// 检查是否为会员用户
    func isPremiumUser() -> Bool {
        /// 检查是否为会员用户
        return membershipStatus.isActive
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
        
        var foundActiveEntitlement = false
        let previousStatus = membershipStatus
        
        let statusTask = Task {
            // 检查订阅状态（月度/年度会员）
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    let productID = transaction.productID
                    
                    // 检查订阅是否仍有效
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            foundActiveEntitlement = true
                            switch productID {
                            case ProductIDs.yearly:
                                membershipStatus = .yearlyMember(expiresOn: expirationDate)
                                subscriptionExpirationDate = expirationDate
                                // 保存到本地
                                UserDefaults.standard.set(expirationDate, forKey: "subscriptionExpirationDate")
                                UserDefaults.standard.set("yearly", forKey: "subscriptionType")
                            case ProductIDs.monthly:
                                membershipStatus = .monthlyMember(expiresOn: expirationDate)
                                subscriptionExpirationDate = expirationDate
                                // 保存到本地
                                UserDefaults.standard.set(expirationDate, forKey: "subscriptionExpirationDate")
                                UserDefaults.standard.set("monthly", forKey: "subscriptionType")
                            default:
                                break
                            }
                            return
                        }
                    }
                    // 检查终身会员购买记录
                    else if productID == ProductIDs.lifetime {
                        foundActiveEntitlement = true
                        membershipStatus = .lifetimeMember
                        // 保存到本地
                        UserDefaults.standard.set(true, forKey: "isPremiumUser")
                        return
                    }
                }
            }
        }
        
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 延长到10秒超时
            statusTask.cancel()
        }
        
        _ = await statusTask.value
        timeoutTask.cancel()
        
        // 只有在成功获取到 StoreKit 数据且没有找到活跃权益时，才进行本地检查
        if !foundActiveEntitlement {
            // 检查 ownedProducts 中的终身会员
            if ownedProducts.contains(ProductIDs.lifetime) {
                membershipStatus = .lifetimeMember
                UserDefaults.standard.set(true, forKey: "isPremiumUser")
                // 找到终身会员，直接返回，不继续检查
            }
            // 如果在线验证失败，但本地有会员标记，保持会员状态
            else if UserDefaults.standard.bool(forKey: "isPremiumUser") {
                membershipStatus = .lifetimeMember
                // 保持现有会员状态，不继续检查
            }
            // 检查本地订阅缓存
            else if let expirationDate = UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date,
               expirationDate > Date() {
                let subscriptionType = UserDefaults.standard.string(forKey: "subscriptionType") ?? "yearly"
                switch subscriptionType {
                case "yearly":
                    membershipStatus = .yearlyMember(expiresOn: expirationDate)
                case "monthly":
                    membershipStatus = .monthlyMember(expiresOn: expirationDate)
                default:
                    membershipStatus = .yearlyMember(expiresOn: expirationDate)
                }
                subscriptionExpirationDate = expirationDate
                // 保持现有订阅状态
            }
            // 只有在确认所有检查都失败时，才设置为非会员并清除缓存
            else {
                membershipStatus = .notMember
                subscriptionExpirationDate = nil
                // 清除过期的本地缓存
                UserDefaults.standard.removeObject(forKey: "subscriptionExpirationDate")
                UserDefaults.standard.removeObject(forKey: "subscriptionType")
            }
        }
        
        // 检查会员状态是否从有效变为无效（只在这种情况下发送通知）
        if previousStatus.isActive && !membershipStatus.isActive {
            // 发送会员状态变化通知（会员过期）
//            DispatchQueue.main.async {
            Task { @MainActor in
                NotificationCenter.default.post(name: NSNotification.Name("MembershipStatusChanged"), object: nil)
            }
        }
    }
    
    // MARK: - 加载已拥有的产品
    private func loadOwnedProducts() async {
        let loadTask = Task {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    ownedProducts.insert(transaction.productID)
                }
            }
        }
        
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒超时
            loadTask.cancel()
        }
        
        _ = await loadTask.value
        timeoutTask.cancel()
        
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

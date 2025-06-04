//
//  StoreManager.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/5/26.
//

import StoreKit

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    
    func fetchProducts() async {
        do {
            products = try await Product.products(for: ["me.pix3l.CassoFlow.lifetime", "me.pix3l.CassoFlow.yearly", "me.pix3l.CassoFlow.monthly"])
        } catch {
            print("加载商品失败: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // ✅ 解锁功能
                    print("购买成功")
                }
            case .userCancelled:
                print("用户取消购买")
            default:
                break
            }
        } catch {
            print("购买出错: \(error)")
        }
    }
    
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == "me.pix3l.CassoFlow.lifetime" {
                    // ✅ 恢复成功
                }
            }
        }
    }
    
}

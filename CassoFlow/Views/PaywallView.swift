//
//  PaywallView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/14.
//

import SwiftUI
import StoreKit

enum MembershipProduct: String, CaseIterable {
    // FIX: 修正产品ID以匹配StoreKitConfig.storekit中的配置
    case monthly = "me.pix3l.CassoFlow.Monthly"
    case yearly = "me.pix3l.CassoFlow.Yearly"
    case lifetime = "me.pix3l.CassoFlow.Lifetime"
    
    var displayName: String {
        switch self {
        case .monthly: return String(localized: "月度")
        case .yearly: return String(localized: "年度")
        case .lifetime: return String(localized: "永久")
        }
    }
    
    var tag: String? {
        switch self {
        case .yearly: return String(localized: "省 50%")
        case .lifetime: return String(localized: "最划算")
        default: return nil
        }
    }
    
    var buttonText: String {
        switch self {
        case .monthly: return String(localized: "开始 3 天免费试用")
        case .yearly: return String(localized: "开始 7 天免费试用")
        case .lifetime: return String(localized: "继续")
        }
    }
}

struct FeatureRow: View {
    
    let systemImage: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20.0, height: 20.0)
            
            
            VStack(alignment: .leading){
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 15)
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var musicService: MusicService
    @State private var selectedPlan: MembershipProduct = .monthly
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    private var isPro: Bool {
        storeManager.isPremiumUser()
    }
    
    var body: some View {

        // 主要内容区域
        ScrollView {
            VStack(spacing: 30) {
                // 标题和副标题
                VStack(spacing: 10) {
                    Image("PRO-dark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30.0)
                    
                    Text("升级 PRO 会员，获取全部高级功能")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Image("paywall-cassette")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .padding(.horizontal, -10)
                
                // 付费选项
                VStack(spacing: 10) {
                    ForEach(MembershipProduct.allCases, id: \.self) { plan in
                        if let product = storeManager.getProduct(for: plan.rawValue) {
                            PlanOptionView(
                                product: product,
                                plan: plan,
                                isSelected: selectedPlan == plan
                            ) {
                                selectedPlan = plan
                            }
                        } else {
                            VStack {
                                Text("产品未找到")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(plan.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .border(Color.red.opacity(0.3))
                        }
                    }
                }
                
                VStack {
                    Text("您将获得")
                        .font(.title)
                        .fontWeight(.bold)
                    // 功能列表
                    VStack(alignment: .leading, spacing: 0) {
                        FeatureRow(
                            systemImage: "recordingtape",
                            title: String(localized: "解锁所有皮肤"),
                            description: String(localized:"无限使用所有播放器和磁带皮肤")
                        )
                        Divider()
                        FeatureRow(
                            systemImage: "waveform",
                            title: String(localized: "磁带音效"),
                            description: String(localized:"模拟真实磁带音效")
                        )
                        Divider()
                        FeatureRow(
                            systemImage: "hand.tap",
                            title: String(localized: "触觉反馈"),
                            description: String(localized:"模拟实体操作的交互反馈")
                        )
                        Divider()
                        FeatureRow(
                            systemImage: "sun.max",
                            title: String(localized: "屏幕常亮"),
                            description: String(localized:"持续欣赏磁带转动的机械感")
                        )
                        Divider()
                        FeatureRow(
                            systemImage: "infinity",
                            title: String(localized: "未来更新"),
                            description: String(localized:"一次性付费，享受未来功能更新")
                        )
                    }
                    .padding(.horizontal)
                    .background(.white.opacity(0.1))
                    .cornerRadius(10)
                }
                
                
                Text("确认购买后，将通过您的 Apple 帐户收取费用。 PRO 会员订阅默认会自动续订，除非在当前订阅结束前至少提前 24 小时前往「设置 -  Apple 账户 - 订阅」关闭自动续订，否则您的 Apple 账户将在当前订阅结束前的 24 小时内被收取续订费用。试用 PRO 会员期间内，如不手动关闭自动续订，则会在试用期结束时自动开通订阅并扣取费用。免费试用机会仅在每位用户首次订阅前试用一次，购买订阅后剩余的免费试用期（如有）将自动失效。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 底部链接
                HStack {
                    HStack(spacing: 10) {
                        Link("隐私政策", destination: URL(string: "https://pix3l.me/cf-privacy-policy/")!)
                        
                        Text("|")
                        
                        Link("使用条款", destination: URL(string: "https://pix3l.me/cf-terms-of-use/")!)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .top) {
            HStack{
                Button("恢复购买") {
                    Task {
                        await storeManager.restorePurchases()
                        
                        if storeManager.isPremiumUser() {
                            // 恢复购买成功，延迟关闭避免视图更新冲突
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                dismiss()
                            }
                        }
                        // 如果恢复购买失败（用户依然不是会员），不关闭页面
                        // 失败提示会通过 storeManager.showAlert 显示
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .foregroundColor(.primary)
                .disabled(storeManager.isLoading)
                .padding()
                
                Spacer()
                
                Button {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.25))
                        )
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                Task {
                    if let product = storeManager.getProduct(for: selectedPlan.rawValue) {
                        let result = await storeManager.purchase(product)
                        
                        switch result {
                        case .success(_):
                            // 购买成功，延迟关闭页面避免视图更新冲突
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                dismiss()
                            }
                        case .cancelled:
                            // 用户取消，不做任何操作
                            break
                        case .failed(let error):
                            errorMessage = error
                            showError = true
                        case .pending:
                            errorMessage = "购买正在处理中，请稍后再试"
                            showError = true
                        }
                    } else {
                        // 产品不存在的错误处理
                        errorMessage = "产品信息加载失败，请重试"
                        showError = true
                    }
                }
            }) {
                ZStack {
                    Text(selectedPlan.buttonText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    
                    if storeManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .disabled(storeManager.isLoading || storeManager.products.isEmpty)
            .padding()
        }

        .onAppear {
            // 页面出现时加载产品信息
            Task {
                await storeManager.fetchProducts()
                
                // if storeManager.isPremiumUser() {
                //     dismiss()
                // }
            }
        }
        .interactiveDismissDisabled(storeManager.isLoading)
        .alert("购买失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("提示", isPresented: $storeManager.showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(storeManager.alertMessage)
        }
    }
}

struct PlanOptionView: View {
    let product: Product
    let plan: MembershipProduct
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var borderColor: Color {
        if isSelected {
            return .white
        } else {
            return .white.opacity(0.2)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .white.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    
                    Text(plan.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let tag = plan.tag {
                        Text(tag)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else {
                        Color.clear
                            .frame(height: 26)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(getPerDayPrice(for: product))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(backgroundColor)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture(perform: action)

    }
    
    private func getPerDayPrice(for product: Product) -> String {
        switch plan {
        case .monthly:
            let dailyPrice = product.price / 30
            return String(localized: "仅 \(dailyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))) /天")
        case .yearly:
            let dailyPrice = product.price / 365
            return String(localized: "仅 \(dailyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))) /天")
        case .lifetime:
            return String(localized: "一次性付费")
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}

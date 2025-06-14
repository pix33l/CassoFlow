//
//  PaywallView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/14.
//

import SwiftUI
import StoreKit

enum MembershipProduct: String, CaseIterable {
    case monthly = "me.pix3l.CassoFlow.monthly"
    case yearly = "me.pix3l.CassoFlow.yearly"
    case lifetime = "me.pix3l.CassoFlow.lifetime"
    
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
    
    @Environment(\.colorScheme) var colorScheme
    let systemImage: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30.0, height: 30.0)
            
            
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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedPlan: MembershipProduct = .monthly
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    private var isPro: Bool {
        storeManager.isPremiumUser()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 主要内容区域
                ScrollView {
                    VStack(spacing: 10) {
                        // 标题和副标题
                        VStack(alignment: .leading, spacing: 10) {
                            Image(colorScheme == .dark ? "PRO-dark" : "PRO-light")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 30.0)
                            
                            Text("解锁 PRO 会员，获取全部高级功能")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        
                        // 功能列表
                        VStack(alignment: .leading, spacing: 0) {
                            FeatureRow(
                                systemImage: "recordingtape",
                                title: String(localized: "解锁所有皮肤"),
                                description: String(localized:"使用所有磁带播放器和磁带皮肤")
                            )
                            Divider()
                            FeatureRow(
                                systemImage: "waveform",
                                title: String(localized: "磁带音效"),
                                description: String(localized:"享受真实的磁带音质体验")
                            )
                            Divider()
                            FeatureRow(
                                systemImage: "sun.max",
                                title: String(localized: "屏幕常亮"),
                                description: String(localized:"持续欣赏磁带转动的韵律")
                            )
                            Divider()
                            FeatureRow(
                                systemImage: "infinity",
                                title: String(localized: "未来更新"),
                                description: String(localized:"一次性付费，享受未来的功能更新")
                            )
                        }
                        .padding(.horizontal)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : .gray.opacity(0.15))
                        .cornerRadius(10)
                        
                        // 付费选项
                        VStack(spacing: 15) {
                            HStack(spacing: 10) {
                                ForEach(MembershipProduct.allCases, id: \.self) { plan in
                                    if let product = storeManager.getProduct(for: plan.rawValue) {
                                        PlanOptionView(
                                            product: product,
                                            plan: plan,
                                            isSelected: selectedPlan == plan
                                        ) {
                                            selectedPlan = plan
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 底部链接
                        HStack {
                            HStack(spacing: 10) {
                                Link("隐私政策", destination: URL(string: "https://pix3l.me/cf-privacy-policy/")!)
                                
                                Text("|")
                                
                                Link("使用条款", destination: URL(string: "https://pix3l.me/cf-terms-of-use/")!)
                            }
                            .font(.footnote)
                            .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("恢复购买") {
                                Task {
                                    print("🔄 开始恢复购买")
                                    await storeManager.restorePurchases()
                                    print("🔄 恢复购买完成，当前会员状态: \(storeManager.isPremiumUser())")
                                    
                                    // 检查是否成功恢复为会员用户
                                    if storeManager.isPremiumUser() {
                                        print("✅ 检测到会员状态，准备关闭页面")
                                        // 使用延迟关闭来避免视图更新冲突
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            dismiss()
                                        }
                                    } else {
                                        print("❌ 恢复购买后仍非会员状态")
                                    }
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .disabled(storeManager.isLoading)
                        }
                        .padding(.bottom, 10)
                    }
                    .padding()
                }
                
                // 底部固定按钮
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
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(colorScheme == .dark ? .white : .black)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .cornerRadius(12)
                        
                        if storeManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                        }
                    }
                }
                .disabled(storeManager.isLoading)
                .padding()
            }
        }
        .onAppear {
            // 页面出现时加载产品信息
            Task {
                await storeManager.fetchProducts()
                
                // 如果用户已经是会员，直接关闭页面
                if storeManager.isPremiumUser() {
                    dismiss()
                }
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
            return colorScheme == .dark ? .white : .black
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return (colorScheme == .dark ? Color.white : Color.black).opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var tagBackgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var tagForegroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var body: some View {
        VStack {
            if let tag = plan.tag {
                Text(tag)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagBackgroundColor)
                    .foregroundColor(tagForegroundColor)
                    .cornerRadius(4)
            } else {
                Color.clear
                    .frame(height: 26)
            }
            
            VStack(spacing: 5) {
                Text(plan.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(getPerDayPrice(for: product))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
            return String(localized: "一次性付费，永久拥有")
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}

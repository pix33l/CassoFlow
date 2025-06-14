//
//  ContactUsView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/13.
//

import SwiftUI

struct ContactUsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.locale) var locale // 添加语言环境
    
    // 判断是否为中文环境
    private var isChineseLocale: Bool {
        return locale.language.languageCode?.identifier.starts(with: "zh") ?? false
    }
    
    var body: some View {
        
        ScrollView { // 添加ScrollView
            
            VStack(spacing: 0) { // 添加spacing: 0 以控制间距
                
                HStack {
                    
                    Image(colorScheme == .dark ? "PIX3L-dark" : "PIX3L-light")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80.0, height: 80.0)
                    
                    Text("PIX3L STUDIO 是一家专注于数字产品的独立个人工作室，致力于探索数字世界的无限可能。通过创新的想法和卓越的设计为用户提供独一无二的体验。")
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding()
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("联系方式")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 0) {
                        ContactRow(
                            systemImage: "Safari",
                            title: String(localized: "网站"),
                            account: "https://pix3l.me"
                        )
                        
                        Divider()
                        
                        ContactRow(
                            systemImage: "Email",
                            title: String(localized: "邮箱"),
                            account: "service@pix3l.me"
                        )
                        
                        if isChineseLocale {
                            
                            Divider()
                            
                            ContactRow(
                                systemImage: "Wechat",
                                title: String(localized: "微信"),
                                account: "pix3l_me（备注：专注拉力）"
                            )
                        
                            Divider()
                        
                            ContactRow(
                                systemImage: "Douyin",
                                title: String(localized: "抖音"),
                                account: "pix3l_me"
                            )
                        }
                        
                        if !isChineseLocale {
                            Divider()
                        } else {
                            Divider()
                        }
                        
                        ContactRow(
                            systemImage: "Rednote",
                            title: String(localized: "小红书"),
                            account: "pix3l_me"
                        )
                        
                        Divider()
                        
                        ContactRow(
                            systemImage: "Instagram",
                            title: "Instagram",
                            account: "pix3l_me"
                        )
                        
                        Divider()
                        
                        ContactRow(
                            systemImage: "X",
                            title: "X(Twitter)",
                            account: "pix3l_me"
                        )
                    }
                    .padding(.horizontal)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : .white)
                    .cornerRadius(10)
                    
                    
/*                    VStack(alignment: .leading) {
                        Text("3rd Resouurce Fonts License:")
                            .font(.subheadline)
                        Text("Fusion Pixel: Copyright © 2021-2023, TakWolf")
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding()
 */
                }
                .padding(.vertical)
            }
            .padding(.horizontal)
        }
        .background(colorScheme == .dark ? .clear : .gray.opacity(0.15))
    }
}

struct ContactRow: View {
    
    @Environment(\.colorScheme) var colorScheme
    let systemImage: String
    let title: String
    let account: String
    @State private var showCopiedAlert = false // 添加状态变量来控制提示
    
    var body: some View {
        HStack(spacing: 15) {

            VStack(alignment: .leading){
                Text(title)
                Text(account)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                UIPasteboard.general.string = account
                showCopiedAlert = true
                
                // 2秒后自动隐藏提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopiedAlert = false
                }
            }) {
                Image(systemName: "document.on.document")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .overlay(
            Text("已复制")
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(colorScheme == .dark ? .white : .black)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(8)
                .opacity(showCopiedAlert ? 1 : 0)
                .animation(.easeInOut, value: showCopiedAlert),
            alignment: .trailing
        )
    }
}

#Preview {
    ContactUsView()
}

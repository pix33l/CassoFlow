//
//  ContactUsView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/13.
//

import SwiftUI

struct ContactUsView: View {
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image("PIX3L")
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 60.0, height: 60.0)
                    
                    Text("PIX3L DESIGN 是专注数字产品的独立个人工作室，以创新设计与卓越理念，为用户打造数字世界的独特体验。")
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .padding([.leading], 4)
                }
            }
            
            Section("联系方式") {
                ContactRow(
                    title: String(localized: "网站"),
                    account: "https://pix3l.me"
                )
                
                ContactRow(
                    title: String(localized: "邮箱"),
                    account: "service@pix3l.me"
                )
                
                ContactRow(
                    title: String(localized: "微信"),
                    account: "pix3l_me（备注：CassoFlow）"
                )
            
                ContactRow(
                    title: String(localized: "抖音"),
                    account: "pix3l_me"
                )
                
                ContactRow(
                    title: String(localized: "小红书"),
                    account: "pix3l_me"
                )
                
                ContactRow(
                    title: "Instagram",
                    account: "pix3l_me"
                )
                
                ContactRow(
                    title: "X(Twitter)",
                    account: "pix3l_me"
                )
            }
        }
        .navigationTitle("关于作者")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactRow: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let account: String
    @State private var showCopiedAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(account)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
            }
        }
        .overlay(
            Text("已复制")
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.secondary)
                .foregroundColor(.primary)
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

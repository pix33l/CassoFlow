//
//  CustomStyle.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/11.
//

import SwiftUI

// 自定义进度条样式结构
struct CustomProgressViewStyle: ProgressViewStyle {
    var tint: Color
    var background: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .frame(width: geometry.size.width, height: 4)
                    .foregroundColor(background)
                
                Capsule()
                    .frame(
                        width: CGFloat(configuration.fractionCompleted ?? 0) * geometry.size.width,
                        height: 4
                    )
                    .foregroundColor(tint)
            }
        }
        .frame(height: 4)
    }
}

// 自定义3D按钮样式结构
struct ThreeDButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack{
            let offset: CGFloat = 5
            
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(Color.gray.gradient)
                .offset(y: offset)
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(
                    Color.gray.gradient
//                    Gradient(colors: [Color.blue, Color.green])
                    .shadow(.inner(color: .white.opacity(0.2), radius: 2, x: 0, y: 2))
                    .shadow(.inner(color: .black.opacity(0.1), radius: 2 , x: 0, y: -2))
                )
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .offset(y: configuration.isPressed ? offset : 0)
            RoundedRectangle(cornerRadius: 8)
                .inset(by: 2)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .foregroundStyle(Gradient(colors: [Color.white.opacity(0.1),Color.white.opacity(0.05)]))
                .shadow(color: .white.opacity(0.2), radius: 4, y: 2)
                .offset(y: configuration.isPressed ? offset : 0)
            
            configuration.label
                .offset(y: configuration.isPressed ? offset : 0)
        }
        .compositingGroup()
        .shadow(radius: 8, y: 4)
    }
}

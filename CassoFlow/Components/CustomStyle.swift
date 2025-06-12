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

// 自定义3D按钮样式结构 - 支持外部控制按压状态
struct ThreeDButtonStyleWithExternalPress: ButtonStyle {
    
    @EnvironmentObject private var musicService: MusicService
    let externalIsPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let offset: CGFloat = 5
        let isPressed = configuration.isPressed || externalIsPressed // 使用外部状态或内部状态
        
        return ZStack{
            // 按钮的外框内凹
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.black.opacity(0.2)
                    .shadow(.inner(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)))
                .offset(y: offset)
            
            // 按钮的外框描边
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 4)
                .stroke(Color.black, lineWidth: 4)
                .offset(y: offset)
            
            // 按钮的厚度
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 4)
                .foregroundStyle(Color(musicService.currentPlayerSkin.buttonShadowColor))
                .offset(y: offset)
            
            // 按钮的点击面
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 4)
                .foregroundStyle(
                    Color(musicService.currentPlayerSkin.buttonColor)
//                    Gradient(colors: [Color.blue, Color.green])
                    .shadow(.inner(color: .white.opacity(0.1), radius: 2, x: 0, y: 1))
                    .shadow(.inner(color: .black.opacity(0.1), radius: 2 , x: 0, y: -1))
                )
                
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的凹面效果
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 4)
                .foregroundStyle(Gradient(colors: [Color.white.opacity(0.05),Color.white.opacity(0.15)]))
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的高光效果
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 5)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 2)
//                .foregroundStyle(Gradient(colors: [Color.white.opacity(0.2),Color.white.opacity(0.1)]))
                .shadow(color: .white.opacity(0.05), radius: 6, y: 3)
                .offset(y: isPressed ? offset : 0)
            
            configuration.label
                .offset(y: isPressed ? offset : 0)
        }
        .animation(.easeOut(duration: 0.2), value: isPressed)
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        // 播放按钮预览
        Button(action: {
            print("播放按钮被点击")
        }) {
            Image(systemName: "play.fill")
                .font(.title3)
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 50)
        .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
        
        // 暂停按钮预览
        Button(action: {
            print("暂停按钮被点击")
        }) {
            Image(systemName: "pause.fill")
                .font(.title3)
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 50)
        .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
        
        // 快进按钮预览
        Button(action: {
            print("快进按钮被点击")
        }) {
            Image(systemName: "forward.fill")
                .font(.title3)
                .foregroundColor(.black)
        }
        .frame(width: 60, height: 50)
        .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
        
        // 按钮组合预览
        HStack(spacing: 15) {
            Button("测试") { }
                .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                .frame(width: 80, height: 40)
            
            Button("按钮") { }
                .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                .frame(width: 80, height: 40)
        }
    }
    .padding()
    .background(Color.gray)
    .environmentObject(MusicService.shared)
}

//
//  CustomProgressViewStyle.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/9/17.
//


import SwiftUI
//import AVFoundation

// 自定义3D按钮样式结构 - 支持外部控制按压状态
struct ThreeDButtonStyle: ButtonStyle {
    
    let externalIsPressed: Bool
    
//    // 静态音效播放器，避免频繁创建销毁
//    private static var buttonAudioPlayer: AVAudioPlayer? = {
//        guard let soundURL = Bundle.main.url(forResource: "button", withExtension: "m4a") else {
//            print("❌ 未找到按钮音效文件")
//            return nil
//        }
//
//        do {
//            let player = try AVAudioPlayer(contentsOf: soundURL)
//            player.prepareToPlay()
//            player.volume = 0.2 // 降低音量避免与其他音效冲突
//            return player
//        } catch {
//            print("❌ 按钮音效初始化失败: \(error.localizedDescription)")
//            return nil
//        }
//    }()
    
    func makeBody(configuration: Configuration) -> some View {
        let offset: CGFloat = 8
        let isPressed = configuration.isPressed || externalIsPressed // 使用外部状态或内部状态
        
        return ZStack{
            // 按钮的外框内凹
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.black.opacity(0.2)
                    .shadow(.inner(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)))
                .offset(y: offset)
            
            // 按钮的外框描边
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 4)
                .stroke(Color.black, lineWidth: 4)
                .offset(y: offset)
            
            // 按钮的厚度
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 4)
                .foregroundStyle(Color("shadow-button-dark"))
                .offset(y: offset)
            
            // 按钮的点击面
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 4)
                .foregroundStyle(
                    Color("button-dark")
//                    Gradient(colors: [Color.blue, Color.green])
                    .shadow(.inner(color: .white.opacity(0.1), radius: 2, x: 0, y: 1))
                    .shadow(.inner(color: .black.opacity(0.1), radius: 2 , x: 0, y: -1))
                )
                
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的凹面效果
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 5)
                .foregroundStyle(Gradient(colors: [Color.black.opacity(0.15),Color.white.opacity(0.05)]))
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的高光效果
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 5)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
//                .foregroundStyle(Gradient(colors: [Color.white.opacity(0.2),Color.white.opacity(0.1)]))
 //               .shadow(color: .white.opacity(0.05), radius: 6, y: 3)
                .offset(y: isPressed ? offset : 0)
            
            configuration.label
                .offset(y: isPressed ? offset : 0)
        }
//        .frame(height: buttonHeight)
        .animation(.easeOut(duration: 0.2), value: isPressed)
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

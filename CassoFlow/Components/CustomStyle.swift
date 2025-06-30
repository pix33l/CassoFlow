//
//  CustomStyle.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/11.
//

import SwiftUI
//import AVFoundation

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
        // 使用皮肤的圆角半径和按钮高度
        let cornerRadius = musicService.currentPlayerSkin.buttonCornerRadius
        
        return ZStack{
            // 按钮的外框内凹
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundStyle(.black.opacity(0.2)
                    .shadow(.inner(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)))
                .offset(y: offset)
            
            // 按钮的外框描边
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: 4)
                .stroke(Color.black, lineWidth: 4)
                .offset(y: offset)
            
            // 按钮的厚度
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: 4)
                .foregroundStyle(Color(musicService.currentPlayerSkin.buttonShadowColor))
                .offset(y: offset)
            
            // 按钮的点击面
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: 4)
                .foregroundStyle(
                    Color(musicService.currentPlayerSkin.buttonColor)
//                    Gradient(colors: [Color.blue, Color.green])
                    .shadow(.inner(color: .white.opacity(0.1), radius: 2, x: 0, y: 1))
                    .shadow(.inner(color: .black.opacity(0.1), radius: 2 , x: 0, y: -1))
                )
                
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的凹面效果
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: 5)
                .foregroundStyle(Gradient(colors: [Color.black.opacity(0.15),Color.white.opacity(0.05)]))
                .offset(y: isPressed ? offset : 0)
            
            // 按钮的点击面的高光效果
            RoundedRectangle(cornerRadius: cornerRadius)
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
        .onChange(of: isPressed) { oldValue, newValue in
            // 使用防抖动机制，避免频繁触发
            if !oldValue && newValue {
                SoundManager.shared.playSound(.button)
//                // 播放按钮音效
//                DispatchQueue.main.async {
//                    Self.buttonAudioPlayer?.stop()
//                    Self.buttonAudioPlayer?.currentTime = 0
//                    Self.buttonAudioPlayer?.play()
//                }
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

// 音频波形动画视图
struct AudioWaveView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var animationAmounts = [0.5, 0.3, 0.7, 0.4, 0.6]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.primary)
                    .frame(width: 2, height: animationAmounts[index] * 20)
                    .animation(
                        // 只有在播放时才有动画，暂停时保持静态
                        musicService.isPlaying ?
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1) :
                        nil,
                        value: animationAmounts[index]
                    )
                    .onAppear {
                        if musicService.isPlaying {
                            animationAmounts[index] = [0.3, 0.5, 0.7, 0.9, 0.6].randomElement()!
                        }
                    }
                    .onChange(of: musicService.isPlaying) { _, isPlaying in
                        if isPlaying {
                            // 开始播放时，重新设置随机高度并开始动画
                            animationAmounts[index] = [0.3, 0.5, 0.7, 0.9, 0.6].randomElement()!
                        }
                        // 暂停时不需要做任何事，动画会自然停止并保持当前高度
                    }
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct PayLabel: View {
    @State private var showingPaywall = false
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    
    private var lifetimePrice: String? {
        if let product = storeManager.getProduct(for: "me.pix3l.CassoFlow.Lifetime") {
            return product.displayPrice
        }
        return nil
    }
    
    private var displayText: String {
        if let price = lifetimePrice {
            return String(localized: "\(price) 终身使用所有功能和主题")
        } else {
            return String(localized:"终身使用所有功能和主题")
        }
    }
    
    var body: some View {
        Button {
            if musicService.isHapticFeedbackEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            showingPaywall = true
        } label: {
            HStack{
                VStack(alignment: .leading) {
                    Image("PRO-black")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 12)
                    Text(displayText)
                        .font(.caption2)
                        .foregroundColor(Color.black)
                }
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundColor(.black)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.yellow)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.black, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(storeManager)
                .environmentObject(musicService)
        }
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

#Preview("支付标签") {
    PayLabel()
        .environmentObject(MusicService.shared)
}

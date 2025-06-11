//
//  ButtonStyle.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/11.
//

import SwiftUI

struct CustomButtonStyle: View {
    
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack {
            
            HStack(spacing: 10) {
                Button {
                    
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .frame(width: 60, height: 50)
                .buttonStyle(ThreeDButtonStyle())
                
                Button {
                    
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .frame(width: 60, height: 50)
                .buttonStyle(ThreeDButtonStyle())
                
                Button {
                    
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .frame(width: 60, height: 50)
                .buttonStyle(ThreeDButtonStyle())
            }
            
            Image(systemName: "play.fill")
                .font(.title)
                .frame(width: 60, height: 50)
                .foregroundColor(musicService.currentPlayerSkin.buttonTextColor)
                .background(musicService.currentPlayerSkin.buttonColor
                    .shadow(.inner(color: .white.opacity(0.4), radius: 2, x: 0, y: 4))
                    .shadow(.inner(color: .black.opacity(0.2), radius: 2 , x: 0, y: -4))
                )
                .overlay(RoundedRectangle(cornerRadius: 8).inset(by: 6).fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.1),Color.white.opacity(0.05)]),startPoint: .top,endPoint: .bottom)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(musicService.currentPlayerSkin.buttonOutlineColor), lineWidth: 2)
                )
            ZStack{
                RoundedRectangle(cornerRadius: 8)
                    .background(.gray
                        .shadow(.inner(color: .white.opacity(0.4), radius: 2, x: 0, y: 4))
                        .shadow(.inner(color: .black.opacity(0.2), radius: 2 , x: 0, y: -4))
                    )
                    .frame(width: 120, height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).inset(by: 6).fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.1),Color.white.opacity(0.05)]),startPoint: .top,endPoint: .bottom)))
                
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundColor(musicService.currentPlayerSkin.buttonTextColor)
            }
        }
    }
}

#Preview {
    CustomButtonStyle()
        .environmentObject(MusicService.shared)

}

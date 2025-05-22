//
//  ContentView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/5/14.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        PlayerView()
    }
}

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return ContentView()
        .environmentObject(musicService)
}

//
//  UniversalQueueView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/9/17.
//


import SwiftUI

/// 统一播放队列视图路由器 - 根据当前数据源自动切换到对应的视图
struct UniversalQueueView: View {
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        Group {
            switch musicService.currentDataSource {
            case .musicKit:
                // 使用Apple Music队列视图
                QueueView()

            case .local:
                // 使用Local队列视图
                LocalQueueView()
                
            }
        }
        .animation(.easeInOut(duration: 0.3), value: musicService.currentDataSource)
    }
}

//
//  TapeTheme.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/5/12.
//



import SwiftUI

enum TapeTheme: String, CaseIterable {
    case defaultTheme = "default"
    case vintageRed = "vintage_red"
    case neonBlue = "neon_blue"
    
    var isLocked: Bool {
        self != .defaultTheme
    }
    
    // 按钮位置配置
    struct ButtonPositions {
        let playButton: CGPoint
        let prevButton: CGPoint
        let nextButton: CGPoint
    }
    
    // 歌曲信息位置配置
    struct InfoPositions {
        let title: CGPoint
        let artist: CGPoint
        let currentTime: CGPoint
        let duration: CGPoint
    }
    
    var buttonPositions: ButtonPositions {
        switch self {
        case .defaultTheme:
            return ButtonPositions(
                playButton: CGPoint(x: 0.5, y: 0.8),
                prevButton: CGPoint(x: 0.3, y: 0.8),
                nextButton: CGPoint(x: 0.7, y: 0.8)
            )
        case .vintageRed:
            return ButtonPositions(
                playButton: CGPoint(x: 0.5, y: 0.75),
                prevButton: CGPoint(x: 0.25, y: 0.75),
                nextButton: CGPoint(x: 0.75, y: 0.75)
            )
        case .neonBlue:
            return ButtonPositions(
                playButton: CGPoint(x: 0.5, y: 0.85),
                prevButton: CGPoint(x: 0.35, y: 0.85),
                nextButton: CGPoint(x: 0.65, y: 0.85)
            )
        }
    }
    
    var infoPositions: InfoPositions {
        switch self {
        case .defaultTheme:
            return InfoPositions(
                title: CGPoint(x: 0.5, y: 0.2),
                artist: CGPoint(x: 0.5, y: 0.25),
                currentTime: CGPoint(x: 0.3, y: 0.9),
                duration: CGPoint(x: 0.7, y: 0.9)
            )
        case .vintageRed:
            return InfoPositions(
                title: CGPoint(x: 0.5, y: 0.15),
                artist: CGPoint(x: 0.5, y: 0.2),
                currentTime: CGPoint(x: 0.2, y: 0.85),
                duration: CGPoint(x: 0.8, y: 0.85)
            )
        case .neonBlue:
            return InfoPositions(
                title: CGPoint(x: 0.5, y: 0.25),
                artist: CGPoint(x: 0.5, y: 0.3),
                currentTime: CGPoint(x: 0.4, y: 0.95),
                duration: CGPoint(x: 0.6, y: 0.95)
            )
        }
    }
}

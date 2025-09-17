//
//  CassFlowWidget.swift
//  CassFlowWidget
//
//  Created by Zhang Shensen on 2025/9/17.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: Date(), musicData: SharedMusicData.default)
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> ()) {
        let musicData = UserDefaults.getMusicData()
        print("Widget getSnapshot - 获取音乐数据: \(musicData)")
        let entry = MusicEntry(date: Date(), musicData: musicData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // 获取当前音乐数据
        let musicData = UserDefaults.getMusicData()
        print("Widget getTimeline - 获取音乐数据: \(musicData)")
        let currentDate = Date()
        
        // 创建时间线条目
        let entry = MusicEntry(date: currentDate, musicData: musicData)
        
        // 如果正在播放，设置更频繁的刷新策略
        let refreshPolicy: TimelineReloadPolicy = musicData.isPlaying ? .after(Calendar.current.date(byAdding: .second, value: 5, to: currentDate)!) : .atEnd
        
        let timeline = Timeline(entries: [entry], policy: refreshPolicy)
        completion(timeline)
    }
}

struct MusicEntry: TimelineEntry {
    let date: Date
    let musicData: SharedMusicData
}

struct CassFlowWidgetEntryView: View {
    var entry: MusicEntry
    
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        VStack(spacing: 8) {
            // 歌曲信息显示
            VStack(spacing: 4) {
                Text(entry.musicData.title)
                    .font(.system(size: widgetFamily == .systemSmall ? 16 : 18, weight: .semibold))
                    .foregroundColor(Color("text-screen-blue"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(entry.musicData.artist)
                    .font(.system(size: widgetFamily == .systemSmall ? 14 : 16))
                    .foregroundColor(Color("text-screen-blue"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 4)
                    .fill(Color("bg-screen-blue"))

                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 8))
                
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.4), lineWidth: 8)
                            .blur(radius: 12)
                            .offset(x: 0, y: 0)
                            .mask(RoundedRectangle(cornerRadius: 8))
                    )

                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(.black), lineWidth: 4))
            )
//            .padding(10)
            
//            // 进度条（仅在中型和大尺寸widget中显示）
//            if widgetFamily != .systemSmall {
//                ProgressView(value: entry.musicData.currentDuration, total: max(entry.musicData.totalDuration, 1))
//                    .progressViewStyle(LinearProgressViewStyle())
//                    .tint(.blue)
//                
//                HStack {
//                    Text(formatTime(entry.musicData.currentDuration))
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                    
//                    Spacer()
//                    
//                    Text(formatTime(entry.musicData.totalDuration))
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//            }
            
            // 控制按钮
            HStack(spacing: widgetFamily == .systemSmall ? 0 : 4) {
                // 上一首按钮
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: widgetFamily == .systemSmall ? 12 : 20))
                        .frame(width: widgetFamily == .systemSmall ? 12 : 32, height: widgetFamily == .systemSmall ? 12 : 32)
                }
                
                // 播放/暂停按钮
                Button(intent: PlayPauseMusicIntent()) {
                    Image(systemName: entry.musicData.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: widgetFamily == .systemSmall ? 12 : 20))
                        .frame(width: widgetFamily == .systemSmall ? 12 : 32, height: widgetFamily == .systemSmall ? 12 : 32)
                }
                
                // 下一首按钮
                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: widgetFamily == .systemSmall ? 12 : 20))
                        .frame(width: widgetFamily == .systemSmall ? 12 : 32, height: widgetFamily == .systemSmall ? 12 : 32)
                }

            }
            .buttonStyle(ThreeDButtonStyle(externalIsPressed: false))
        }
//        .padding()
        .widgetURL(URL(string: "cassoflow://music-control")) // 深度链接到应用
    }
    
//    private func formatTime(_ time: TimeInterval) -> String {
//        let minutes = Int(time) / 60
//        let seconds = Int(time) % 60
//        return String(format: "%d:%02d", minutes, seconds)
//    }
}

struct CassFlowWidget: Widget {
    let kind: String = "CassFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CassFlowWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CassFlow音乐播放器")
        .description("显示当前播放的歌曲信息和控制按钮")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CassFlowWidget()
} timeline: {
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "示例歌曲",
        artist: "示例歌手",
        isPlaying: true,
        currentDuration: 120,
        totalDuration: 240
    ))
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "另一首歌曲",
        artist: "另一位歌手",
        isPlaying: false,
        currentDuration: 0,
        totalDuration: 180
    ))
}

#Preview(as: .systemMedium) {
    CassFlowWidget()
} timeline: {
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "这是一首很长的歌曲名称测试文字",
        artist: "这是一个很长的歌手名称测试",
        isPlaying: true,
        currentDuration: 150,
        totalDuration: 300
    ))
}

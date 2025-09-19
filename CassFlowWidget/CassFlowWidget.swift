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
        
        // 智能刷新策略
        let refreshPolicy: TimelineReloadPolicy
        
        if musicData.isPlaying {
            // 如果正在播放，使用较短的刷新间隔，确保播放状态及时更新
            refreshPolicy = .after(Calendar.current.date(byAdding: .second, value: 3, to: currentDate)!)
        } else {
            // 如果暂停或停止，使用较长的刷新间隔
            refreshPolicy = .after(Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!)
        }
        
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
        switch widgetFamily {
        case .systemSmall:

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(entry.musicData.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("text-screen-blue"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text(entry.musicData.artist)
                            .font(.system(size: 14))
                            .foregroundColor(Color("text-screen-blue"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
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
//                                .offset(x: 0, y: 0)
                                .mask(RoundedRectangle(cornerRadius: 8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(.black), lineWidth: 4))
                )
                
                // 控制按钮
                HStack {
                    ZStack {
                        if let artworkData = entry.musicData.artworkData {
                            // 背景层：模糊的专辑封面
                            Image(uiImage: UIImage(data: artworkData) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            // 默认封面
                            defaultAlbumCoverView()                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(.black), lineWidth: 2))
                    
                    // 播放/暂停按钮
                    Button(intent: PlayPauseMusicIntent()) {
                        Image(systemName: "playpause.fill"/*entry.musicData.isPlaying ? "pause.fill" : "play.fill"*/)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(ThreeDButtonStyle())
                    .padding(.bottom, 8)
                }
            }
            .containerBackground(for: .widget) {
                Image("bg-systemSmall")
                    .resizable()
                    .scaledToFill()
            }
            
        case .systemMedium:
                // 中等尺寸Widget布局
                HStack(spacing: 16) {
                    ZStack {
                        if let artworkData = entry.musicData.artworkData {
                            
//                            if musicService.currentCoverStyle == .rectangle {
//                                Image(uiImage: UIImage(data: artworkData) ?? UIImage())
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 80, height: 124)
//                                    .clipShape(Rectangle())
//                            } else {
                            
//                                // 背景层：模糊的专辑封面
//                                Image(uiImage: UIImage(data: artworkData) ?? UIImage())
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 80, height: 124)
//                                    .blur(radius: 8)
//                                    .overlay(Color.black.opacity(0.3))
//                                    .clipShape(Rectangle())
                                
                                // 前景层：清晰的专辑封面
                                Image(uiImage: UIImage(data: artworkData) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 124)
                                    .clipShape(Rectangle())
//                            }
                        } else {
                            // 默认封面
                            defaultAlbumCoverView()
                                .frame(width: 80, height: 124)
                        }
                        
                        // 使用随机磁带图片
                        Image(getRandomCassetteImage(for: entry.musicData.title))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 124)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    
                    // 右侧内容：歌曲信息和控制按钮
                    VStack(spacing: 8) {
                        // 歌曲信息显示
                        HStack{
                            Spacer()
                            VStack(spacing: 4) {
                                Text(entry.musicData.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("text-screen-blue"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text(entry.musicData.artist)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color("text-screen-blue"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            Spacer()
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
                        
                        // 控制按钮
                        HStack(spacing: 4) {
                            // 上一首按钮
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16))
//                                    .frame(width: 32, height: 16)
                            }
                            
                            // 播放/暂停按钮
                            Button(intent: PlayPauseMusicIntent()) {
                                Image(systemName: "playpause.fill"/*entry.musicData.isPlaying ? "pause.fill" : "play.fill"*/)
                                    .font(.system(size: 16))
//                                    .frame(width: 32, height: 16)
                            }
                            
                            // 下一首按钮
                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
//                                    .frame(width: 32, height: 16)
                            }
                        }
                        .buttonStyle(ThreeDButtonStyle())
                        .padding(.bottom, 8)
                    }
                }
                .containerBackground(for: .widget) {
                    Image("bg-systemMedium")
                        .resizable()
                        .scaledToFill()
                }
//        case .systemLarge:
//                // 大尺寸Widget布局 - 特殊磁带样式
//                VStack {
//                    ZStack {
//                        // 磁带背景
//                        Image("artwork-cassette")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 320, height: 230)
//                        
//                        // 磁带封面
//                        if let artworkData = entry.musicData.artworkData {
//                            Image(uiImage: UIImage(data: artworkData) ?? UIImage())
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: 225, height: 100)
//                                .blur(radius: 8)
//                                .overlay(
//                                    // 半透明遮罩确保文字清晰
//                                    Color.black.opacity(0.3)
//                                )
//                                .clipShape(RoundedRectangle(cornerRadius: 4))
//                                .padding(.bottom, 30)
//                        } else {
//                            ZStack{
//                                Color.black
//                                    .frame(width: 225, height: 100)
//                                    .clipShape(RoundedRectangle(cornerRadius: 4))
//                                    .padding(.bottom, 30)
//                            }
//                        }
//                        
//                        // CASSOFLOW Logo
//                        Image("CASSOFLOW")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 84)
//                            .padding(.bottom, 92)
//                        
//                        // 磁带孔
//                        Image("artwork-cassette-hole")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 300)
//                        
//                        // 歌曲信息
//                        HStack{
//                            // 专辑封面
//                            if let artworkData = entry.musicData.artworkData {
//                                Image(uiImage: UIImage(data: artworkData) ?? UIImage())
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 50, height: 50)
//                                    .clipShape(RoundedRectangle(cornerRadius: 2))
//                            } else {
//                                ZStack{
//                                    Color.black
//                                        .frame(width: 50, height: 50)
//                                        .clipShape(RoundedRectangle(cornerRadius: 2))
//                                    
//                                    Image("CASSOFLOW")
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fit)
//                                        .frame(width: 42)
//                                }
//                            }
//                            
//                            VStack(alignment: .leading, spacing: 0) {
//                                Text(entry.musicData.title)
//                                    .font(.headline.bold())
//                                    .lineLimit(1)
//                                
//                                Text(entry.musicData.artist)
//                                    .font(.footnote)
//                                    .lineLimit(1)
//                                    .padding(.top, 4)
//                            }
//                            
//                            Spacer()
//                        }
//                        .padding(.top, 100)
//                        .frame(width: 250)
//                    }
//                    
//                    // 控制按钮
//                    HStack(spacing: 12) {
//                        // 上一首按钮
//                        Button(intent: PreviousTrackIntent()) {
//                            Image(systemName: "backward.fill")
//                                .font(.system(size: 24))
//                        }
//                        
//                        // 播放/暂停按钮
//                        Button(intent: PlayPauseMusicIntent()) {
//                            Image(systemName: entry.musicData.isPlaying ? "pause.fill" : "play.fill")
//                                .font(.system(size: 24))
//                        }
//                        
//                        // 下一首按钮
//                        Button(intent: NextTrackIntent()) {
//                            Image(systemName: "forward.fill")
//                                .font(.system(size: 24))
//                        }
//                    }
//                    .padding()
//                    .buttonStyle(ThreeDButtonStyle(externalIsPressed: false))
//                }
//                .containerBackground(for: .widget) {
//                    Image("bg-systemLarge")
//                        .resizable()
//                        .scaledToFill()
//                }
        case .systemLarge:
            // 大尺寸Widget布局 - 显示最近添加的6张音乐专辑封面
            VStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 24) {
                    // 显示专辑封面，如果有数据则显示真实封面，否则显示默认封面
                    ForEach(0..<6, id: \.self) { index in
                        ZStack {
                            // 专辑封面显示逻辑
                            if let albumCovers = entry.musicData.recentAlbumCovers,
                               index < albumCovers.count,
                               let uiImage = UIImage(data: albumCovers[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 124)
                                    .clipShape(Rectangle())
                            } else {
                                defaultAlbumCoverView()
                                    .frame(width: 80, height: 124)
                            }
                            
                            // 磁带图片覆盖层 - 每个封面使用不同的随机磁带图片
                            Image(getRandomCassetteImage(for: "album_\(index)_\(entry.musicData.title)"))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 124)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 6, y: -2)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
                    }
                }
            }
            .containerBackground(for: .widget) {
                Image("bg-systemLarge")
                    .resizable()
                    .scaledToFill()
            }
            
        default:
                Text("Some other WidgetFamily in the future.")
            }
        }
//        .widgetURL(URL(string: "cassoflow://music-control")) // 深度链接到应用
    
    // 获取随机磁带图片的辅助函数
    private func getRandomCassetteImage(for id: String) -> String {
        // 可用的磁带图片名称数组
        let cassetteImages = [
            "package-cassette-01",
            "package-cassette-02",
            "package-cassette-03",
            "package-cassette-04",
            "package-cassette-05",
            "package-cassette-06",
            "package-cassette-07",
            "package-cassette-08",
            "package-cassette-09",
            "package-cassette-10"
        ]
        
        // 使用ID的哈希值作为随机数种子，确保每个ID都有固定的图片选择
        let hash = abs(id.hashValue)
        let index = hash % cassetteImages.count
        return cassetteImages[index]
    }
    
    // 默认专辑封面视图
    private func defaultAlbumCoverView() -> some View {
        ZStack {
            // 背景模糊效果
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 55)
//                .clipShape(Rectangle())
        }
    }
}

struct CassFlowWidget: Widget {
    let kind: String = "CassFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CassFlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("磁带播放器")
        .description("最爱复古磁带沙沙声")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    CassFlowWidget()
} timeline: {
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "示例歌曲",
        artist: "示例歌手",
        isPlaying: true,
        artworkData: nil
    ))
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "另一首歌曲",
        artist: "另一位歌手",
        isPlaying: false,
        artworkData: nil
    ))
}

#Preview(as: .systemMedium) {
    CassFlowWidget()
} timeline: {
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "这是一首很长的歌曲名称测试文字",
        artist: "这是一个很长的歌手名称测试",
        isPlaying: true,
        artworkData: nil
    ))
}

#Preview(as: .systemLarge) {
    CassFlowWidget()
} timeline: {
    MusicEntry(date: .now, musicData: SharedMusicData(
        title: "这是一首很长的歌曲名称测试文字",
        artist: "这是一个很长的歌手名称测试",
        isPlaying: true,
        artworkData: nil
    ))
}

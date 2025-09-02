import SwiftUI

/// Subsonic播放队列视图
struct SubsonicQueueView: View {
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) private var dismiss
    @State private var queueSongs: [UniversalSong] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 队列列表
                if queueSongs.isEmpty {
                    emptyQueueView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(queueSongs.enumerated()), id: \.element.id) { index, song in
                                SubsonicQueueTrackRow(
                                    index: index,
                                    song: song,
                                    isPlaying: index == currentIndex,
                                    isCurrent: index == currentIndex
                                )
                                .onTapGesture {
                                    if musicService.isHapticFeedbackEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    Task {
                                        await jumpToSong(at: index)
                                    }
                                }
                                
                                if index < queueSongs.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .onAppear {
                loadQueueInfo()
            }
            .onChange(of: musicService.currentTrackID) { _, _ in
                loadQueueInfo()
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    if !queueSongs.isEmpty {
//                        Menu {
//                            Button {
//                                Task {
//                                    await shuffleQueue()
//                                }
//                            } label: {
//                                Label("随机播放", systemImage: "shuffle")
//                            }
//                            
//                            Button {
//                                Task {
//                                    await clearQueue()
//                                }
//                            } label: {
//                                Label("清空队列", systemImage: "trash")
//                            }
//                        } label: {
//                            Image(systemName: "ellipsis")
//                                .font(.body)
//                                .foregroundColor(.primary)
//                        }
//                    }
//                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - 空队列视图
    
    private var emptyQueueView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
                .padding(.bottom, 10)
            
            Text("播放队列为空")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("队列会在播放音乐时显示")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 数据加载
    
    private func loadQueueInfo() {
        let subsonicService = musicService.getSubsonicService()
        let queueInfo = subsonicService.getQueueInfo()
        
        queueSongs = queueInfo.queue
        currentIndex = queueInfo.currentIndex
    }
    
    // MARK: - 队列操作
    
    private func jumpToSong(at index: Int) async {
        guard index < queueSongs.count else { return }
        
        let subsonicService = musicService.getSubsonicService()
        
        do {
            // 播放指定索引的歌曲
            try await subsonicService.playQueue(queueSongs, startingAt: index)
            
            // 更新当前索引
            await MainActor.run {
                currentIndex = index
            }
            
            print("🎵 Subsonic队列跳转到歌曲：\(queueSongs[index].title)")
        } catch {
            print("🎵 Subsonic队列跳转失败：\(error.localizedDescription)")
        }
    }
    
//    private func shuffleQueue() async {
//        guard !queueSongs.isEmpty else { return }
//        
//        let shuffledSongs = queueSongs.shuffled()
//        let subsonicService = musicService.getSubsonicService()
//        
//        do {
//            try await subsonicService.playQueue(shuffledSongs, startingAt: 0)
//            
//            await MainActor.run {
//                queueSongs = shuffledSongs
//                currentIndex = 0
//            }
//            
//            print("🎵 Subsonic队列已随机播放")
//        } catch {
//            print("🎵 随机播放失败：\(error.localizedDescription)")
//        }
//    }
    
//    private func clearQueue() async {
//        let subsonicService = musicService.getSubsonicService()
//        subsonicService.stop()
//        
//        await MainActor.run {
//            queueSongs.removeAll()
//            currentIndex = 0
//        }
//        
//        print("🎵 Subsonic队列已清空")
//    }
}

// MARK: - Subsonic队列歌曲行视图

struct SubsonicQueueTrackRow: View {
    let index: Int
    let song: UniversalSong
    let isPlaying: Bool
    let isCurrent: Bool
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 12) {
            // 歌曲序号或播放状态
            VStack {
                if isPlaying {
                    AudioWaveView()
                        .frame(width: 24, height: 24)
                        .opacity(musicService.isPlaying ? 1.0 : 0.6)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(isCurrent ? .yellow : .secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            // 专辑封面
            if let artworkURL = song.artworkURL {
                CachedAsyncImage(url: artworkURL) {
                    defaultArtwork
                } content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } else {
                defaultArtwork
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let albumName = song.albumName {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 歌曲时长
            Text(formattedDuration(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isCurrent ? Color.yellow.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    private var defaultArtwork: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.yellow.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.yellow)
            )
    }
    
    /// 格式化时长
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

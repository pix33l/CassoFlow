import SwiftUI
import MusicKit

/// 播放队列视图
struct QueueView: View {
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) private var dismiss
    @State private var queueEntries: [ApplicationMusicPlayer.Queue.Entry] = []
    @State private var currentEntryID: ApplicationMusicPlayer.Queue.Entry.ID?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题和统计信息
//                VStack(spacing: 8) {
//                    HStack {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("播放队列")
//                                .font(.title2.bold())
//                            Text("\(queueEntries.count)首歌曲")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                        
//                        Spacer()
//                        
//                        Button("完成") {
//                            dismiss()
//                        }
//                        .foregroundColor(.primary)
//                    }
//                    .padding(.horizontal)
//                    
//                    Divider()
//                }
//                .padding(.vertical, 8)
                
                // 队列列表
                if queueEntries.isEmpty {
                    VStack(spacing: 10) {
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(queueEntries.enumerated()), id: \.element.id) { index, entry in
                                QueueTrackRow(
                                    index: index,
                                    entry: entry,
                                    isPlaying: entry.id == currentEntryID
                                )
                                .onTapGesture {
                                    if musicService.isHapticFeedbackEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    // 跳转到指定歌曲
                                    Task {
                                        await jumpToEntry(entry)
                                    }
                                }
                                
                                if index < queueEntries.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
//                        .padding(.vertical, 8)
                    }
                }
            }
            .onAppear {
                loadQueueEntries()
            }
            .onChange(of: musicService.currentTrackID) { _, _ in
                // 当前歌曲变化时更新队列
                loadQueueEntries()
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
    
    /// 加载队列条目
    private func loadQueueEntries() {
        let player = ApplicationMusicPlayer.shared
        queueEntries = Array(player.queue.entries)
        currentEntryID = player.queue.currentEntry?.id
    }
    
    /// 跳转到指定条目
    private func jumpToEntry(_ entry: ApplicationMusicPlayer.Queue.Entry) async {
        print("🎵 跳转到歌曲：\(entry.title)")
        
        let player = ApplicationMusicPlayer.shared
        let currentEntry = player.queue.currentEntry
        
        // 如果点击的是当前正在播放的歌曲，则不需要做任何操作
        if entry.id == currentEntry?.id {
            print("🎵 已经在播放这首歌曲")
            return
        }
        
        // 获取队列中的所有条目
        let entries = Array(player.queue.entries)
        guard let targetIndex = entries.firstIndex(where: { $0.id == entry.id }) else {
            print("🎵 在队列中找不到目标歌曲")
            return
        }
        
        do {
            // 提取所有歌曲项目，转换为Track类型
            var tracks: [Track] = []
            
            for queueEntry in entries {
                switch queueEntry.item {
                case .song(let song):
                    tracks.append(.song(song))
                case .musicVideo(let musicVideo):
                    tracks.append(.musicVideo(musicVideo))
                case .none:
                    continue
                @unknown default:
                    continue
                }
            }
            
            // 确保我们有足够的歌曲项目
            guard tracks.count > targetIndex else {
                print("🎵 歌曲项目数量不足")
                return
            }
            
            // 重新排列歌曲：将目标歌曲放到第一位，其他歌曲按原顺序排列
            var reorderedTracks: [Track] = []
            
            // 首先添加目标歌曲
            reorderedTracks.append(tracks[targetIndex])
            
            // 然后添加目标歌曲之后的所有歌曲
            for i in (targetIndex + 1)..<tracks.count {
                reorderedTracks.append(tracks[i])
            }
            
            // 最后添加目标歌曲之前的所有歌曲
            for i in 0..<targetIndex {
                reorderedTracks.append(tracks[i])
            }
            
            print("🎵 重新构建队列，目标歌曲：\(entries[targetIndex].title)")
            
            // 保存当前的播放状态
            let wasPlaying = player.state.playbackStatus == .playing
            print("🎵 当前播放状态: \(wasPlaying ? "播放中" : "已暂停")")
            
            // 创建新的队列，从目标歌曲开始
            if let firstTrack = reorderedTracks.first {
                // 创建新队列，使用重新排列的tracks
                player.queue = ApplicationMusicPlayer.Queue(for: reorderedTracks, startingAt: firstTrack)
                
                // 添加短暂延迟确保队列设置完成
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
                // 如果之前在播放，则开始播放新队列
                print("🎵 开始播放新队列")
                try await player.play()
                
                print("🎵 成功跳转到歌曲：\(entry.title)")
                
                // 跳转完成后，延迟刷新队列，确保显示完整新队列
                await MainActor.run {
                    // 显示一个临时“正在切歌”状态（可选）
                    // self.isLoading = true
                }

                try await Task.sleep(nanoseconds: 700_000_000) // 延迟0.7秒（可调，保证MusicKit队列切换完成）

                await MainActor.run {
                    loadQueueEntries()
                    // self.isLoading = false
                }
            } else {
                print("🎵 无法获取目标歌曲项目")
            }
            
        } catch {
            print("🎵 跳转歌曲失败：\(error.localizedDescription)")
            
            // 如果跳转失败，尝试恢复播放状态
            let wasPlaying = player.state.playbackStatus == .playing
            if !wasPlaying {
                do {
                    try await player.play()
                    print("🎵 已恢复播放状态")
                } catch {
                    print("🎵 恢复播放状态失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 队列歌曲行视图
struct QueueTrackRow: View {
    let index: Int
    let entry: ApplicationMusicPlayer.Queue.Entry
    let isPlaying: Bool
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
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            // 专辑封面
            if let artwork = trackArtwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(entry.subtitle ?? "未知艺术家")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 歌曲时长
            Text(formattedDuration(trackDuration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isPlaying ? Color.primary.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    /// 获取歌曲封面
    private var trackArtwork: Artwork? {
        switch entry.item {
        case .song(let song):
            return song.artwork
        case .musicVideo(let musicVideo):
            return musicVideo.artwork
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /// 获取歌曲时长
    private var trackDuration: TimeInterval {
        switch entry.item {
        case .song(let song):
            return song.duration ?? 0
        case .musicVideo(let musicVideo):
            return musicVideo.duration ?? 0
        case .none:
            return 0
        @unknown default:
            return 0
        }
    }
    
    /// 格式化时长
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 预览
#Preview("播放队列 - 有歌曲") {
    let musicService = MusicService.shared
    
    // 模拟播放队列视图
    struct MockQueueView: View {
        @State private var mockEntries: [MockQueueEntry] = [
            MockQueueEntry(id: "1", title: "Love Story", artist: "Taylor Swift", duration: 235, isPlaying: false),
            MockQueueEntry(id: "2", title: "You Belong With Me", artist: "Taylor Swift", duration: 232, isPlaying: true),
            MockQueueEntry(id: "3", title: "White Horse", artist: "Taylor Swift", duration: 238, isPlaying: false),
            MockQueueEntry(id: "4", title: "The Way I Loved You", artist: "Taylor Swift", duration: 244, isPlaying: false),
            MockQueueEntry(id: "5", title: "Forever Winter", artist: "Taylor Swift", duration: 346, isPlaying: false),
            MockQueueEntry(id: "6", title: "Enchanted", artist: "Taylor Swift", duration: 350, isPlaying: false),
            MockQueueEntry(id: "7", title: "Speak Now", artist: "Taylor Swift", duration: 240, isPlaying: false),
            MockQueueEntry(id: "8", title: "Back to December", artist: "Taylor Swift", duration: 290, isPlaying: false)
        ]
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // 顶部标题和统计信息
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("播放队列")
                                    .font(.title2.bold())
                                Text("\(mockEntries.count)首歌曲")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("完成") {
                                // 关闭视图
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                    .padding(.vertical, 8)
                    
                    // 队列列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(mockEntries.enumerated()), id: \.element.id) { index, entry in
                                MockQueueTrackRow(
                                    index: index,
                                    entry: entry
                                )
                                .onTapGesture {
                                    // 模拟点击
                                    for i in 0..<mockEntries.count {
                                        mockEntries[i].isPlaying = (i == index)
                                    }
                                }
                                
                                if index < mockEntries.count - 1 {
                                    Divider()
                                        .padding(.leading, 76)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    return MockQueueView()
        .environmentObject(musicService)
}

#Preview("播放队列 - 空队列") {
    let musicService = MusicService.shared
    
    NavigationStack {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播放队列")
                            .font(.title2.bold())
                        Text("0首歌曲")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("完成") {
                        // 关闭视图
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal)
                
                Divider()
            }
            .padding(.vertical, 8)
            
            // 空状态
            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("播放队列为空")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("播放音乐后，播放队列将显示在这里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    .navigationBarHidden(true)
    .environmentObject(musicService)
}

// MARK: - 模拟数据结构
struct MockQueueEntry {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    var isPlaying: Bool
}

// MARK: - 模拟队列歌曲行视图
struct MockQueueTrackRow: View {
    let index: Int
    let entry: MockQueueEntry
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 12) {
            // 模拟专辑封面
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.secondary)
                )
            
            // 歌曲序号或播放状态
            VStack {
                if entry.isPlaying {
                    AudioWaveView()
                        .frame(width: 24, height: 24)
                        .opacity(musicService.isPlaying ? 1.0 : 0.6)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(entry.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 歌曲时长
            Text(formattedDuration(entry.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            entry.isPlaying ? Color.primary.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    /// 格式化时长
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

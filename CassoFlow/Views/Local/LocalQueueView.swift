import SwiftUI

/// 本地音乐播放队列视图
struct LocalQueueView: View {
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
                                LocalQueueTrackRow(
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !queueSongs.isEmpty {
                        Menu {
                            Button {
                                Task {
                                    await clearQueue()
                                }
                            } label: {
                                Label("清空队列", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
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
                .foregroundColor(.orange)
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
        let localService = musicService.getLocalService()
        let queueInfo = localService.getQueueInfo()
        
        queueSongs = queueInfo.queue
        currentIndex = queueInfo.currentIndex
    }
    
    // MARK: - 队列操作
    
    private func jumpToSong(at index: Int) async {
        guard index < queueSongs.count else { return }
        
        let localService = musicService.getLocalService()
        
        do {
            // 播放指定索引的歌曲
            try await localService.playQueue(queueSongs, startingAt: index)
            
            // 更新当前索引
            await MainActor.run {
                currentIndex = index
            }
            
            print("🎵 本地音乐队列跳转到歌曲：\(queueSongs[index].title)")
        } catch {
            print("🎵 本地音乐队列跳转失败：\(error.localizedDescription)")
        }
    }
    
    private func clearQueue() async {
        let localService = musicService.getLocalService()
        localService.stop()
        
        await MainActor.run {
            queueSongs.removeAll()
            currentIndex = 0
        }
        
        print("🎵 本地音乐队列已清空")
    }
}

// MARK: - 预览

struct LocalQueueView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 有歌曲的队列
            LocalQueuePreviewWithSongs()
                .previewDisplayName("有歌曲")
            
            // 空队列
            LocalQueuePreviewEmpty()
                .previewDisplayName("空队列")
        }
    }
}

// MARK: - 预览辅助视图

struct LocalQueuePreviewWithSongs: View {
    @StateObject private var musicService = MusicService.shared
    @State private var mockSongs: [MockLocalSong] = [
        MockLocalSong(id: "1", title: "Song 1", artistName: "Artist 1", albumName: "Album 1", duration: 180, isPlaying: false),
        MockLocalSong(id: "2", title: "Song 2", artistName: "Artist 2", albumName: "Album 2", duration: 210, isPlaying: true),
        MockLocalSong(id: "3", title: "Song 3", artistName: "Artist 3", albumName: "Album 3", duration: 195, isPlaying: false)
    ]
    @State private var currentIndex = 1
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(mockSongs.enumerated()), id: \.element.id) { index, song in
                            MockLocalQueueTrackRow(
                                index: index,
                                song: song,
                                isCurrent: index == currentIndex
                            )
                            .onTapGesture {
                                // 更新播放状态
                                for i in 0..<mockSongs.count {
                                    mockSongs[i].isPlaying = (i == index)
                                }
                                currentIndex = index
                            }
                            
                            if index < mockSongs.count - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("本地音乐播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("清空队列") {
                            mockSongs.removeAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 关闭操作
                    }
                }
            }
        }
        .environmentObject(musicService)
    }
}

struct LocalQueuePreviewEmpty: View {
    @StateObject private var musicService = MusicService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                    .padding(.bottom, 10)
                
                Text("播放队列为空")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text("从本地音乐播放音乐后，队列将显示在这里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    // 浏览音乐
                } label: {
                    Text("浏览音乐")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.orange)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("本地音乐播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 关闭操作
                    }
                }
            }
        }
        .environmentObject(musicService)
    }
}

// MARK: - 模拟数据

struct MockLocalSong {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let duration: TimeInterval
    var isPlaying: Bool
}

struct MockLocalQueueTrackRow: View {
    let index: Int
    let song: MockLocalSong
    let isCurrent: Bool
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 12) {
            // 歌曲序号或播放状态
            VStack {
                if song.isPlaying {
                    AudioWaveView()
                        .frame(width: 24, height: 24)
                        .opacity(musicService.isPlaying ? 1.0 : 0.6)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(isCurrent ? .orange : .secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            // 专辑封面
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.orange)
                )
            
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
            
            // 数据源标识
            Image(systemName: "desktopcomputer")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.trailing, 4)
            
            // 歌曲时长
            Text(formattedDuration(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isCurrent ? Color.orange.opacity(0.1) : Color.clear
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
import SwiftUI

struct AudioStationQueueView: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var audioStationService = AudioStationMusicService.shared
    
    @State private var currentQueue: [UniversalSong] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 当前播放歌曲信息
                CurrentTrackSection()
                
                Divider()
                
                // 播放队列
                if isLoading {
                    LoadingView()
                } else if currentQueue.isEmpty {
                    EmptyQueueView()
                } else {
                    QueueList(
                        queue: currentQueue,
                        currentIndex: currentIndex,
                        onReorder: reorderQueue
                    )
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            clearQueue()
                        } label: {
                            Label("清空队列", systemImage: "trash")
                        }
                        .disabled(currentQueue.isEmpty)
                        
                        Button {
                            shuffleQueue()
                        } label: {
                            Label("随机播放", systemImage: "shuffle")
                        }
                        .disabled(currentQueue.isEmpty)
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadQueueData()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            updateQueueInfo()
        }
    }
    
    // MARK: - 数据管理
    
    private func loadQueueData() {
        let queueInfo = audioStationService.getQueueInfo()
        
        DispatchQueue.main.async {
            currentQueue = queueInfo.queue
            currentIndex = queueInfo.currentIndex
            isLoading = false
        }
    }
    
    private func updateQueueInfo() {
        let queueInfo = audioStationService.getQueueInfo()
        
        // 只在队列发生变化时更新UI
        if currentQueue.count != queueInfo.queue.count || currentIndex != queueInfo.currentIndex {
            DispatchQueue.main.async {
                currentQueue = queueInfo.queue
                currentIndex = queueInfo.currentIndex
            }
        }
    }
    
    private func reorderQueue(from source: IndexSet, to destination: Int) {
        // Audio Station 队列重排序功能
        // 注意：这需要Audio Station API支持，可能需要额外实现
        print("队列重排序: \(source) -> \(destination)")
    }
    
    private func clearQueue() {
        Task {
            await audioStationService.stop()
            loadQueueData()
        }
    }
    
    private func shuffleQueue() {
        // 实现队列随机化
        print("随机播放队列")
    }
}

// MARK: - 子视图组件

private struct CurrentTrackSection: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var audioStationService = AudioStationMusicService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentSong = audioStationService.getCurrentSong() {
                HStack(spacing: 12) {
                    // 专辑封面
                    AsyncImage(url: currentSong.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundColor(.secondary)
                            }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // 歌曲信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentSong.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(currentSong.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if let albumName = currentSong.albumName {
                            Text(albumName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // 播放状态指示器
                    VStack {
                        Image(systemName: musicService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        Text("正在播放")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            } else {
                // 没有当前播放歌曲
                HStack {
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("没有正在播放的歌曲")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("从媒体库选择音乐开始播放")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载播放队列...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("播放队列为空")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("从媒体库添加歌曲到播放队列")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct QueueList: View {
    let queue: [UniversalSong]
    let currentIndex: Int
    let onReorder: (IndexSet, Int) -> Void
    
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var audioStationService = AudioStationMusicService.shared
    
    var body: some View {
        List {
            ForEach(Array(queue.enumerated()), id: \.element.id) { index, song in
                QueueRowView(
                    song: song,
                    index: index,
                    isCurrentSong: index == currentIndex,
                    onTap: {
                        jumpToSong(at: index)
                    }
                )
                .listRowSeparator(.hidden)
            }
            .onMove(perform: onReorder)
        }
        .listStyle(.plain)
    }
    
    private func jumpToSong(at index: Int) {
        Task {
            // 跳转到指定歌曲播放
            // 注意：这需要Audio Station服务支持跳转到指定索引
            try await audioStationService.playQueue(queue, startingAt: index)
        }
    }
}

private struct QueueRowView: View {
    let song: UniversalSong
    let index: Int
    let isCurrentSong: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号或播放指示器
            ZStack {
                if isCurrentSong {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 24)
            
            // 专辑封面
            AsyncImage(url: song.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(isCurrentSong ? .semibold : .regular)
                    .foregroundColor(isCurrentSong ? .orange : .primary)
                    .lineLimit(1)
                
                HStack {
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
            
            // 时长
            Text(formatTime(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 预览

struct AudioStationQueueView_Previews: PreviewProvider {
    static var previews: some View {
        AudioStationQueueView()
            .environmentObject(MusicService.shared)
    }
}
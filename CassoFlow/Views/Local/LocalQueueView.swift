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
                    queueListView
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
    
    // MARK: - 队列列表视图
    private var queueListView: some View {
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

import SwiftUI
import MusicKit

/// 通用的音乐详情视图，支持专辑和播放列表
struct MusicDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let containerType: MusicContainerType
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var albumArtwork: UIImage? = nil
    
    @State private var playTapped = false
    @State private var shufflePlayTapped = false
    @State private var trackTapped = false
    
    private var container: MusicContainer {
        containerType.container
    }
    
    /// 判断当前是否正在播放指定歌曲
    private func isPlaying(_ track: Track) -> Bool {
        musicService.currentTitle == track.title &&
        musicService.currentArtist == track.artistName &&
        musicService.isPlaying
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部音乐容器信息
                VStack(spacing: 16) {
                    
                    Image("artwork-cassette")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 350)
/*
                    if let image = albumArtwork {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color.gray
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
*/
                    VStack(spacing: 4) {
                        Text(container.title)
                            .font(.title2.bold())
                        
                        Text(container.artistName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let releaseDate = container.releaseDate {
                            let genreText = container.genreNames.first ?? (isPlaylist() ? "播放列表" : "未知风格")
                            Text("\(genreText) • \(releaseDate.formatted(.dateTime.year()))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            playTapped.toggle()
                            Task {
                                try await playMusic(shuffled: false)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: playTapped)
                        
                        Button {
                            shufflePlayTapped.toggle()
                            Task {
                                try await playMusic(shuffled: true)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: shufflePlayTapped)
                    }
                }
                .padding(.horizontal)
                
                // 歌曲列表
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                        
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            MusicTrackRow(
                                index: index,
                                track: track,
                                isPlaying: isPlaying(track)
                            )
                            .equatable()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                trackTapped.toggle()
                                Task {
                                    try await playTrack(track)
                                }
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: trackTapped)
                            .animation(nil, value: tracks)
                            
                            if index < tracks.count - 1 {
                                Divider()
                                    .padding(.leading, 40)
                                    .padding(.trailing, 16)
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                    }
                }
                
                // 底部信息
                if let releaseDate = container.releaseDate, !tracks.isEmpty {
                    let totalDuration = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
                    
                    InfoFooter(
                        releaseDate: releaseDate,
                        trackCount: tracks.count,
                        totalDuration: totalDuration,
                        isPlaylist: isPlaylist()
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTracks()
        }
        .task {
            await loadArtwork()
        }
    }
    
    /// 检查是否为播放列表
    private func isPlaylist() -> Bool {
        switch containerType {
        case .playlist:
            return true
        case .album:
            return false
        }
    }
    
    /// 播放音乐（专辑或播放列表）
    private func playMusic(shuffled: Bool) async throws {
        switch containerType {
        case .album(let album):
            try await musicService.playAlbum(album, shuffled: shuffled)
        case .playlist(let playlist):
            try await musicService.playPlaylist(playlist, shuffled: shuffled)
        }
    }
    
    /// 播放指定歌曲
    private func playTrack(_ track: Track) async throws {
        switch containerType {
        case .album(let album):
            try await musicService.playTrack(track, in: album)
        case .playlist(let playlist):
            // 对于播放列表，我们需要设置整个播放列表然后跳转到指定歌曲
            try await musicService.playPlaylist(playlist)
            // 这里可能需要额外的逻辑来跳转到指定歌曲
        }
    }
    
    private func loadArtwork() async {
        guard let url = container.artwork?.url(width: 300, height: 300) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                albumArtwork = UIImage(data: data)
            }
        } catch {
            print("图片加载失败: \(error)")
        }
    }
    
    private func loadTracks() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let loadedTracks = try await container.withTracks()
            
            await MainActor.run {
                tracks = loadedTracks
                
                if tracks.isEmpty {
                    errorMessage = "无法加载歌曲列表"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载详情失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - 为了保持向后兼容性，保留原始的 AlbumDetailView
struct AlbumDetailView: View {
    let album: Album
    
    var body: some View {
        MusicDetailView(containerType: .album(album))
    }
}

// MARK: - 新的播放列表详情视图
struct PlaylistDetailView: View {
    let playlist: Playlist
    
    var body: some View {
        MusicDetailView(containerType: .playlist(playlist))
    }
}

// MARK: - 优化后的通用曲目行视图
struct MusicTrackRow: View, Equatable {
    let index: Int
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            if isPlaying {
                AudioWaveView()
                    .frame(width: 24, height: 24)
            } else {
                Text("\(index + 1)")
                    .frame(width: 24, alignment: .center)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .foregroundColor(.primary)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(
                formattedDuration(track.duration ?? 0)
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            isPlaying ? Color.white.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    // Equatable实现 - 关键性能优化点
    static func == (lhs: MusicTrackRow, rhs: MusicTrackRow) -> Bool {
        lhs.index == rhs.index &&
        lhs.track.id == rhs.track.id &&
        lhs.isPlaying == rhs.isPlaying
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 底部信息栏
struct InfoFooter: View {
    let releaseDate: Date
    let trackCount: Int
    let totalDuration: TimeInterval
    let isPlaylist: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 根据类型显示不同的日期信息
            if isPlaylist {
                Text("最后更新于 \(releaseDate.formattedDateString())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("发布于 \(releaseDate.formattedDateString())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 显示分钟数（不带秒）
            Text(
                "\(trackCount)首歌曲 • \(formatMinutes(totalDuration))"
            )
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // 转换秒数为分钟格式（如"42分钟"）
    private func formatMinutes(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            // 显示小时和分钟，如"1小时22分钟"
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }
}

// 音频波形动画视图
struct AudioWaveView: View {
    @State private var animationAmounts = [0.5, 0.3, 0.7, 0.4, 0.6]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: animationAmounts[index] * 20)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animationAmounts[index]
                    )
                    .onAppear {
                        animationAmounts[index] = [0.3, 0.5, 0.7, 0.9, 0.6].randomElement()!
                    }
            }
        }
        .frame(width: 24, height: 24)
    }
}

extension Date {
    func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
}

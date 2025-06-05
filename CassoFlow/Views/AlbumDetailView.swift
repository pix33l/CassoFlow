import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let album: Album
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var albumArtwork: UIImage? = nil
    
    // 判断当前是否正在播放指定歌曲
    private func isPlaying(_ track: Track) -> Bool {
        musicService.currentTitle == track.title &&
        musicService.currentArtist == track.artistName &&
        musicService.isPlaying
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部专辑信息
                VStack(spacing: 16) {
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
                    
                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.title2.bold())
                        
                        Text(album.artistName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let releaseDate = album.releaseDate {
                            Text("\(album.genreNames.first ?? "未知风格") • \(releaseDate.formatted(.dateTime.year()))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            Task {
                                try await musicService.playAlbum(album)
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
                        
                        Button {
                            Task {
                                try await musicService.playAlbum(album, shuffled: true)
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
                            AlbumTrackRow(
                                index: index,
                                track: track,
                                isPlaying: isPlaying(track)
                            )
                            .equatable()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    try await musicService.playTrack(track, in: album)
                                }
                            }
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
                if let releaseDate = album.releaseDate, !tracks.isEmpty {
                    let totalDuration = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
                    
                    InfoFooter(
                        releaseDate: releaseDate,
                        trackCount: tracks.count,
                        totalDuration: totalDuration
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumTracks()
        }
        .task {
            await loadAlbumArtwork()
        }
    }
    
    private func loadAlbumArtwork() async {
        guard let url = album.artwork?.url(width: 300, height: 300) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            albumArtwork = UIImage(data: data)
        } catch {
            print("专辑图片加载失败: \(error)")
        }
    }
    
    private func loadAlbumTracks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detailedAlbum = try await album.with([.tracks])
            tracks = detailedAlbum.tracks ?? []
            
            if tracks.isEmpty {
                errorMessage = "无法加载歌曲列表"
            }
        } catch {
            errorMessage = "加载专辑详情失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 优化后的专辑曲目行视图
struct AlbumTrackRow: View, Equatable {
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
    static func == (lhs: AlbumTrackRow, rhs: AlbumTrackRow) -> Bool {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 使用当地日期格式
            Text("发布于 \(releaseDate.formattedDateString())")
                .font(.footnote)
                .foregroundColor(.secondary)
            
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

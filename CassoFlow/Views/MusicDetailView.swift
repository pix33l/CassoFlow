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
                    ZStack {
                        Image("artwork-cassette")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                        //磁带封面
                        if let image = albumArtwork {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 290, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 4)
//                                        .stroke(.white, lineWidth: 1))
                                .padding(.bottom, 37)
                        } else {
                            ZStack{
                                Color.black
                                    .frame(width: 290, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(.bottom, 37)
                                Image("CASSOFLOW")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120)
                                    .padding(.bottom, 130)
                            }
                        }
                        
                        Image("artwork-cassette-hole")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                    }

                    VStack(spacing: 4) {
                        Text(container.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(container.artistName)
                            .font(.title2)
                            .multilineTextAlignment(.center)
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
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
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
                        
                        Button {
                            shufflePlayTapped.toggle()
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
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
                                if musicService.isHapticFeedbackEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                Task {
                                    try await playTrack(track)
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
    
    private func loadTracks() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            print("🎵 开始加载曲目 - 容器类型: \(isPlaylist() ? "播放列表" : "专辑")")
            print("🎵 容器名称: \(container.title)")
            
            // 添加重试机制
            var retryCount = 0
            let maxRetries = 3
            
            while retryCount < maxRetries {
                do {
                    print("🎵 尝试加载曲目 (第\(retryCount + 1)次)")
                    let loadedTracks = try await container.withTracks()
                    
                    await MainActor.run {
                        tracks = loadedTracks
                        print("🎵 成功加载 \(tracks.count) 首歌曲")
                        
                        // 打印前几首歌曲的信息用于调试
                        for (index, track) in tracks.prefix(3).enumerated() {
                            print("🎵 歌曲 \(index + 1): \(track.title) - \(track.artistName) - 时长: \(track.duration ?? 0)秒")
                        }
                        
                        if tracks.isEmpty {
                            errorMessage = "无法加载歌曲列表"
                        }
                        isLoading = false
                    }
                    return // 成功后退出重试循环
                } catch {
                    print("🎵 加载曲目失败 (尝试 \(retryCount + 1)/\(maxRetries)): \(error)")
                    retryCount += 1
                    
                    // 如果是权限相关错误，不要重试
                    if let nsError = error as NSError?, nsError.code == -7013 || nsError.code == -7007 {
                        print("🎵 权限相关错误，停止重试")
                        await MainActor.run {
                            errorMessage = "访问受限: \(error.localizedDescription)"
                            isLoading = false
                        }
                        return
                    }
                    
                    // 等待后重试
                    if retryCount < maxRetries {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
                    }
                }
            }
            
            // 所有重试都失败了
            await MainActor.run {
                errorMessage = "加载详情失败: 多次重试后仍然失败"
                isLoading = false
            }
            
        } catch {
            print("🎵 loadTracks整体失败: \(error)")
            await MainActor.run {
                errorMessage = "加载详情失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadArtwork() async {
        guard let url = container.artwork?.url(width: 300, height: 300) else { 
            print("🎵 \(container.title) 没有封面URL")
            return 
        }
        
        print("🎵 开始加载封面: \(container.title) - URL: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // 检查HTTP响应
            if let httpResponse = response as? HTTPURLResponse {
                print("🎵 封面请求响应码: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("🎵 封面加载失败: HTTP \(httpResponse.statusCode)")
                    return
                }
            }
            
            guard let image = UIImage(data: data) else {
                print("🎵 无法创建UIImage from data")
                return
            }
            
            await MainActor.run {
                albumArtwork = image
                print("🎵 成功加载封面: \(container.title)")
            }
        } catch {
            print("🎵 图片加载失败: \(container.title) - \(error)")
            
            // 如果是网络错误，尝试使用更小的尺寸
            if let smallerUrl = container.artwork?.url(width: 150, height: 150) {
                print("🎵 尝试加载较小尺寸的封面...")
                do {
                    let (data, _) = try await URLSession.shared.data(from: smallerUrl)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            albumArtwork = image
                            print("🎵 成功加载小尺寸封面: \(container.title)")
                        }
                    }
                } catch {
                    print("🎵 小尺寸封面也加载失败: \(error)")
                }
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
        VStack(alignment: .center, spacing: 4) {
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
            return String(localized:"\(minutes)分钟")
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            // 显示小时和分钟，如"1小时22分钟"
            return String(localized:"\(hours)小时\(remainingMinutes)分钟")
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

// MARK: - 预览
#Preview("专辑详情 - 加载完成") {
    let musicService = MusicService.shared
    
    // 创建模拟专辑详情视图
    struct MockAlbumDetailView: View {
        @State private var tracks: [MockTrack] = [
            MockTrack(id: "1", title: "Love Story", artistName: "Taylor Swift", duration: 235),
            MockTrack(id: "2", title: "You Belong With Me", artistName: "Taylor Swift", duration: 232),
            MockTrack(id: "3", title: "White Horse", artistName: "Taylor Swift", duration: 238),
            MockTrack(id: "4", title: "The Way I Loved You", artistName: "Taylor Swift", duration: 244),
            MockTrack(id: "5", title: "Forever Winter", artistName: "Taylor Swift", duration: 346),
            MockTrack(id: "6", title: "Enchanted", artistName: "Taylor Swift", duration: 350)
        ]
        @State private var isPlaying = false
        @State private var currentTrackIndex = 0
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部专辑信息
                        VStack(spacing: 16) {
                            ZStack {
                                Image("artwork-cassette")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 360)
                                
                                ZStack{
                                    Color.black
                                        .frame(width: 290, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(.bottom, 37)
                                    Image("CASSOFLOW")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 120)
                                        .padding(.top, 20)
                                }
                                
                                Image("artwork-cassette-hole")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 360)
                            }

                            VStack(spacing: 4) {
                                Text("Fearless")
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                
                                Text("Taylor Swift")
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                
                                Text("流行音乐 • 2008")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // 播放控制按钮
                            HStack(spacing: 20) {
                                Button {
                                    // 模拟播放
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
                                    // 模拟随机播放
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
                            Divider()
                                .padding(.leading, 20)
                                .padding(.trailing, 16)
                            
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                MockTrackRow(
                                    index: index,
                                    track: track,
                                    isPlaying: isPlaying && currentTrackIndex == index
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    currentTrackIndex = index
                                    isPlaying = true
                                }
                                
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
                        
                        // 底部信息
                        VStack(alignment: .center, spacing: 4) {
                            Text("发布于 2008年11月11日")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            Text("6首歌曲 • 24分钟")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("专辑详情")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    return MockAlbumDetailView()
        .environmentObject(musicService)
}

#Preview("播放列表详情 - 加载完成") {
    let musicService = MusicService.shared
    
    // 创建模拟播放列表详情视图
    struct MockPlaylistDetailView: View {
        @State private var tracks: [MockTrack] = [
            MockTrack(id: "1", title: "Shape of You", artistName: "Ed Sheeran", duration: 233),
            MockTrack(id: "2", title: "Blinding Lights", artistName: "The Weeknd", duration: 200),
            MockTrack(id: "3", title: "稻香", artistName: "周杰伦", duration: 223),
            MockTrack(id: "4", title: "青花瓷", artistName: "周杰伦", duration: 235),
            MockTrack(id: "5", title: "Someone Like You", artistName: "Adele", duration: 285),
            MockTrack(id: "6", title: "Perfect", artistName: "Ed Sheeran", duration: 263),
            MockTrack(id: "7", title: "晴天", artistName: "周杰伦", duration: 269),
            MockTrack(id: "8", title: "Hello", artistName: "Adele", duration: 295)
        ]
        @State private var isPlaying = false
        @State private var currentTrackIndex = 2
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部播放列表信息
                        VStack(spacing: 16) {
                            ZStack {
                                Image("artwork-cassette")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 360)
                                
                                ZStack{
                                    Color.black
                                        .frame(width: 290, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(.bottom, 37)
                                    Image("CASSOFLOW")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 120)
                                        .padding(.top, 20)
                                }
                                
                                Image("artwork-cassette-hole")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 360)
                            }

                            VStack(spacing: 4) {
                                Text("我的最爱")
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                
                                Text("精选歌单")
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                
                                Text("播放列表 • 2024")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // 播放控制按钮
                            HStack(spacing: 20) {
                                Button {
                                    // 模拟播放
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
                                    // 模拟随机播放
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
                            Divider()
                                .padding(.leading, 20)
                                .padding(.trailing, 16)
                            
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                MockTrackRow(
                                    index: index,
                                    track: track,
                                    isPlaying: isPlaying && currentTrackIndex == index
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    currentTrackIndex = index
                                    isPlaying = true
                                }
                                
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
                        
                        // 底部信息
                        VStack(alignment: .center, spacing: 4) {
                            Text("最后更新于 今天")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            Text("8首歌曲 • 34分钟")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("播放列表详情")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    return MockPlaylistDetailView()
        .environmentObject(musicService)
}

#Preview("加载状态") {
    let musicService = MusicService.shared
    
    NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部信息（可见）
                VStack(spacing: 16) {
                    ZStack {
                        Image("artwork-cassette")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                        
                        ZStack{
                            Color.black
                                .frame(width: 290, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.bottom, 37)
                            Image("CASSOFLOW")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120)
                                .padding(.bottom, 130)
                        }
                        
                        Image("artwork-cassette-hole")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                    }

                    VStack(spacing: 4) {
                        Text("加载中...")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("请稍候")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮（禁用状态）
                    HStack(spacing: 20) {
                        Button {
                            // 禁用
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                        }
                        .disabled(true)
                        
                        Button {
                            // 禁用
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                        }
                        .disabled(true)
                    }
                }
                .padding(.horizontal)
                
                // 加载状态
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(musicService)
}

#Preview("错误状态") {
    let musicService = MusicService.shared
    
    NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部信息（可见）
                VStack(spacing: 16) {
                    ZStack {
                        Image("artwork-cassette")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                        
                        ZStack{
                            Color.black
                                .frame(width: 290, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.bottom, 37)
                            Image("CASSOFLOW")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120)
                                .padding(.top, 20)
                        }
                        
                        Image("artwork-cassette-hole")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360)
                    }

                    VStack(spacing: 4) {
                        Text("加载失败")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("发生错误")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮（禁用状态）
                    HStack(spacing: 20) {
                        Button {
                            // 禁用
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                        }
                        .disabled(true)
                        
                        Button {
                            // 禁用
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                        }
                        .disabled(true)
                    }
                }
                .padding(.horizontal)
                
                // 错误信息
                Text("加载详情失败: 网络连接超时")
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(musicService)
}

// MARK: - 模拟数据结构
struct MockTrack {
    let id: String
    let title: String
    let artistName: String
    let duration: TimeInterval
}

// MARK: - 模拟歌曲行视图
struct MockTrackRow: View {
    let index: Int
    let track: MockTrack
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            if isPlaying {
                // 简化的音频波形
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 2, height: 12)
                    }
                }
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
            
            Text(formattedDuration(track.duration))
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
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

import MusicKit
import SwiftUI

class MusicPlayerService: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTapeTheme: TapeTheme = .defaultTheme
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var musicCatalog: [Track] = []
    @Published var currentTheme: TapeTheme = .defaultTheme
    
    private var systemPlayer = SystemMusicPlayer.shared
    private var playerStateObserver: Task<Void, Never>?
    
    init() {
        setupMusicSubscription()
    }
    
    deinit {
        playerStateObserver?.cancel()
    }
    
    // 1. 音乐授权处理
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            authorizationStatus = status
            if status == .authorized {
                Task { await fetchMusicCatalog() }
            }
        }
    }
    
    // 2. 获取音乐库
    func fetchMusicCatalog() async {
        guard authorizationStatus == .authorized else { return }
        
        do {
            var request = MusicCatalogSearchRequest(term: "", types: [Song.self])
            request.limit = 50
            let response = try await request.response()
            
            // 使用同步方式处理前50首歌曲
            var tracks = [Track]()
            for song in response.songs.prefix(50) {
                let artwork = await loadArtwork(for: song)
                let track = Track(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artwork: artwork
                )
                tracks.append(track)
            }
            
            await MainActor.run {
                musicCatalog = tracks
            }
        } catch {
            print("获取音乐库失败: \(error.localizedDescription)")
        }
    }
    
    // 修改获取封面的方法
    private func loadArtwork(for song: Song) async -> UIImage? {
        guard let artwork = song.artwork,
              let artworkURL = artwork.url(width: 300, height: 300) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL)
            return UIImage(data: data)
        } catch {
            print("加载封面失败: \(error)")
            return nil
        }
    }
    
    // 3. 播放控制
    func play(track: Track? = nil) async {
        guard authorizationStatus == .authorized else { return }
        
        if let track = track {
            do {
                // 修复Song.with调用方式
                let song = try await MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.id))
                    .response()
                    .items
                    .first
                
                if let song = song {
                    systemPlayer.queue = [song]
                }
            } catch {
                print("加载歌曲失败: \(error.localizedDescription)")
                return
            }
        }
        
        do {
            try await systemPlayer.play()
            await MainActor.run {
                isPlaying = true
                if let track = track {
                    currentTrack = track
                }
            }
        } catch {
            print("播放失败: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        systemPlayer.pause()
        isPlaying = false
    }
    
    func skipToNext() async {
        do {
            try await systemPlayer.skipToNextEntry()
            await updateCurrentTrack()
        } catch {
            print("跳转下一首失败: \(error.localizedDescription)")
        }
    }
    
    func skipToPrevious() async {
        do {
            try await systemPlayer.skipToPreviousEntry()
            await updateCurrentTrack()
        } catch {
            print("跳转上一首失败: \(error.localizedDescription)")
        }
    }
    
    // 修改更新当前曲目的方法
    private func updateCurrentTrack() async {
        guard let currentEntry = systemPlayer.queue.currentEntry else {
            return
        }
        
        if case let .song(song) = currentEntry.item {
            let artwork = await loadArtwork(for: song)
            
            await MainActor.run {
                currentTrack = Track(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artwork: artwork
                )
            }
        }
    }
    
    // 修改状态监听方法
    private func setupMusicSubscription() {
        playerStateObserver = Task {
            for await _ in systemPlayer.state.objectWillChange.values {
                await MainActor.run {
                    isPlaying = (systemPlayer.state.playbackStatus == .playing)
                }
            }
        }
    }
    
    // 切换磁带主题
    func changeTapeTheme(_ theme: TapeTheme) {
        currentTapeTheme = theme
    }
}

// 音乐模型
struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let artwork: UIImage?
}

// 磁带主题枚举
enum TapeTheme: String, CaseIterable {
    case defaultTheme = "默认磁带"
    case vintageRed = "复古红"
    case neonBlue = "霓虹蓝"
    
    var isLocked: Bool {
        self != .defaultTheme
    }
}

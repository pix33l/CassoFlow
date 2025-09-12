import SwiftUI

/// 本地音乐专用音乐详情视图 - 专辑
struct LocalMusicDetailView: View {
  @EnvironmentObject private var musicService: MusicService
  let album: UniversalAlbum
  @State private var detailedAlbum: UniversalAlbum?
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  @State private var playTapped = false
  @State private var shufflePlayTapped = false
  @State private var trackTapped = false
  
  // 🔑 删除相关状态（只保留整个专辑删除）
  @State private var showingDeleteAlbumAlert = false
  @State private var isDeletingAlbum = false
  @Environment(\.dismiss) var dismiss

  /// 判断当前是否正在播放指定歌曲
  private func isPlaying(_ song: UniversalSong) -> Bool {
      // 使用元数据匹配
      let titleMatch = musicService.currentTitle.trimmingCharacters(in: .whitespaces).lowercased() ==
                      song.title.trimmingCharacters(in: .whitespaces).lowercased()
      let artistMatch = musicService.currentArtist.trimmingCharacters(in: .whitespaces).lowercased() ==
                       song.artistName.trimmingCharacters(in: .whitespaces).lowercased()
      
      return titleMatch && artistMatch && musicService.currentDataSource == .local
  }
  
  var body: some View {
      ScrollView {
          LazyVStack(spacing: 20) {
              // 顶部专辑信息
              VStack(spacing: 16) {
                  ZStack {
                      Image("artwork-cassette")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 360)
                      
                      if let localAlbum = album.originalData as? LocalAlbumItem,
                         let artworkData = localAlbum.artworkData,
                         let image = UIImage(data: artworkData) {
                          Image(uiImage: image)
                              .resizable()
                              .aspectRatio(contentMode: .fill)
                              .frame(width: 270, height: 120)
                              .blur(radius: 8)
                              .overlay(Color.black.opacity(0.3))
                              .clipShape(RoundedRectangle(cornerRadius: 4))
                              .padding(.bottom, 37)
                      } else {
                          // 背景封面
                          defaultBackground
                      }
                      
                      // CassoFlow Logo
                      Image("CASSOFLOW")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 100)
                          .padding(.bottom, 110)
                      
                      // 磁带孔洞
                      Image("artwork-cassette-hole")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 360)
                      
                      // 专辑信息
                      HStack {
                          
                          if let localAlbum = album.originalData as? LocalAlbumItem,
                             let artworkData = localAlbum.artworkData,
                             let image = UIImage(data: artworkData) {
                              Image(uiImage: image)
                                  .resizable()
                                  .aspectRatio(contentMode: .fill)
                                  .frame(width: 60, height: 60)
                                  .clipShape(RoundedRectangle(cornerRadius: 2))
                          } else {
                              // 小封面
                              defaultSmallCover
                          }
                          
                          VStack(alignment: .leading, spacing: 0) {
                              Text(album.title)
                                  .font(.headline.bold())
                                  .lineLimit(1)
                              
                              Text(album.artistName)
                                  .font(.footnote)
                                  .lineLimit(1)
                                  .padding(.top, 4)
                              
                              // 修复：改进风格和年份信息的显示逻辑
                              HStack(spacing: 0) {
                                  if let genre = album.genre, !genre.isEmpty {
                                      Text(genre)
                                      
                                      if album.year != nil {
                                          Text(" • ")
                                      }
                                  }
                                  
                                  if let year = album.year {
                                      Text("\(String(year))")
                                  }
                                  
                                  // 如果风格和年份都没有，显示默认文本
                                  if album.genre?.isEmpty != false && album.year == nil {
                                      Text("本地专辑")
                                  }
                              }
                              .font(.footnote)
                          }
                          .foregroundColor(.black)
                          
                          Spacer()
                      }
                      .padding(.top, 120)
                      .frame(width: 300)
                  }
                  
                  // 播放控制按钮
                  HStack(spacing: 20) {
                      Button {
                          playTapped.toggle()
                          if musicService.isHapticFeedbackEnabled {
                              let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                              impactFeedback.impactOccurred()
                          }
                          Task {
                              try await playAlbum(shuffled: false)
                          }
                      } label: {
                          HStack {
                              Image(systemName: "play.fill")
                              Text("播放")
                                  .lineLimit(1)
                          }
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.secondary.opacity(0.2))
                          .foregroundColor(.primary)
                          .cornerRadius(8)
                      }
                      .disabled(isLoading || isDeletingAlbum)
                      
                      Button {
                          shufflePlayTapped.toggle()
                          if musicService.isHapticFeedbackEnabled {
                              let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                              impactFeedback.impactOccurred()
                          }
                          Task {
                              try await playAlbum(shuffled: true)
                          }
                      } label: {
                          HStack {
                              Image(systemName: "shuffle")
                              Text("随机播放")
                                  .lineLimit(1)
                          }
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.secondary.opacity(0.2))
                          .foregroundColor(.primary)
                          .cornerRadius(8)
                      }
                      .disabled(isLoading || isDeletingAlbum)
                  }
              }
              .padding(.horizontal)
              
              // 歌曲列表
              VStack(alignment: .leading, spacing: 0) {
                  if isLoading {
                      ProgressView("正在加载歌曲...")
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 20)
                  } else if let error = errorMessage {
                      VStack(spacing: 16) {
                          Image(systemName: "exclamationmark.triangle.fill")
                              .font(.title2)
                              .foregroundColor(.yellow)
                          
                          Text(error)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                          
                          Button("重试") {
                              Task {
                                  await loadDetailedAlbum(forceRefresh: true)
                              }
                          }
                          .buttonStyle(.borderedProminent)
                          .tint(.yellow)
                          .foregroundColor(.black)
                      }
                      .padding(.vertical, 40)
                  } else if let detailed = detailedAlbum, !detailed.songs.isEmpty {

                      Divider()
                          .padding(.leading, 20)
                          .padding(.trailing, 16)
                      
                      LazyVStack(spacing: 0) {
                          ForEach(Array(detailed.songs.enumerated()), id: \.element.id) { index, song in
                              LocalTrackRow(
                                  index: index,
                                  song: song,
                                  isPlaying: isPlaying(song),
                                  onDelete: {
                                      await refreshAlbumAfterSongDeletion()
                                  },
                                  onTap: {
                                      trackTapped.toggle()
                                      if musicService.isHapticFeedbackEnabled {
                                          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                          impactFeedback.impactOccurred()
                                      }
                                      Task {
                                          try await playSong(song, from: detailed.songs, startingAt: index)
                                      }
                                  }
                              )
                              
                              if index < detailed.songs.count - 1 {
                                  Divider()
                                      .padding(.leading, 40)
                                      .padding(.trailing, 16)
                              }
                          }
                      }
                      
                      Divider()
                          .padding(.leading, 20)
                          .padding(.trailing, 16)
                  } else {
                      VStack(spacing: 12) {
                          Image(systemName: "music.note")
                              .font(.title2)
                              .foregroundColor(.secondary)
                          
                          Text("此专辑暂无歌曲")
                              .foregroundColor(.secondary)
                      }
                      .padding(.vertical, 20)
                  }
              }
              
              // 底部信息
              if let detailed = detailedAlbum, !detailed.songs.isEmpty {
                  LocalInfoFooter(
                      year: album.year,
                      trackCount: detailed.songs.count,
                      totalDuration: detailed.songs.reduce(0) { $0 + $1.duration },
                      isPlaylist: false
                  )
              }
          }
          .padding(.vertical)
      }
      .navigationTitle(album.title)
      .navigationBarTitleDisplayMode(.inline)
      // 🔑 修改：导航栏更多操作菜单按钮
      .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
              Menu {
                  Button(role: .destructive) {
                      if musicService.isHapticFeedbackEnabled {
                          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                          impactFeedback.impactOccurred()
                      }
                      showingDeleteAlbumAlert = true
                  } label: {
                      Label("删除专辑", systemImage: "trash")
                  }
                  .disabled(isDeletingAlbum)
              } label: {
                  if isDeletingAlbum {
                      ProgressView()
                          .scaleEffect(0.8)
                          .frame(width: 20, height: 20)
                  } else {
                      Image(systemName: "ellipsis")
                          .font(.headline)
                          .foregroundColor(.primary)
                  }
              }
              .menuStyle(.button)
              .menuIndicator(.hidden)
              .disabled(isDeletingAlbum)
          }
      }
      .alert("删除专辑", isPresented: $showingDeleteAlbumAlert) {
          Button("取消", role: .cancel) { }
          Button("删除", role: .destructive) {
              Task {
                  await deleteAlbum()
              }
          }
      } message: {
          if let detailed = detailedAlbum {
              Text("确定要删除专辑《\(detailed.title)》及其所有 \(detailed.songs.count) 首歌曲吗？此操作不可撤销。")
          }
      }
      .task {
          await loadDetailedAlbum(forceRefresh: false)
      }
  }
  
  // MARK: - 默认视图
  
  private var defaultBackground: some View {
      ZStack {
          Color.black
          Image("CASSOFLOW")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 75)
      }
      .frame(width: 270, height: 120)
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .padding(.bottom, 37)
  }
  
  private var defaultSmallCover: some View {
      ZStack {
          Color.black
          Image("CASSOFLOW")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 30)
      }
      .frame(width: 60, height: 60)
      .clipShape(RoundedRectangle(cornerRadius: 2))
  }
  
  // MARK: - 数据加载（本地音乐直接加载，不使用缓存）
  
  /// 加载详细专辑信息（本地音乐直接从LocalMusicService获取）
  private func loadDetailedAlbum(forceRefresh: Bool) async {
      await MainActor.run {
          isLoading = true
          errorMessage = nil
      }
      
      do {
          // 🔑 本地音乐直接从LocalMusicService获取，不使用缓存
          let localService = musicService.getLocalService()
          let detailed = try await localService.getAlbum(id: album.id)
          
          await MainActor.run {
              detailedAlbum = detailed
              isLoading = false
              
              if detailed.songs.isEmpty {
                  errorMessage = "此专辑没有歌曲"
              }
          }
      } catch {
          await MainActor.run {
              errorMessage = "加载专辑详情失败：\(error.localizedDescription)"
              isLoading = false
          }
      }
  }
  
  // MARK: - 播放控制
  
  private func playAlbum(shuffled: Bool) async throws {
      guard let detailed = detailedAlbum, !detailed.songs.isEmpty else { return }
      
      let songs = shuffled ? detailed.songs.shuffled() : detailed.songs
      try await musicService.playUniversalSongs(songs)
  }
  
  private func playSong(_ song: UniversalSong, from songs: [UniversalSong], startingAt index: Int) async throws {
      try await musicService.playUniversalSongs(songs, startingAt: index)
  }
  
  // 🔑 新增：删除整张专辑
  private func deleteAlbum() async {
      guard let detailed = detailedAlbum else { return }
      
      await MainActor.run {
          isDeletingAlbum = true
      }
      
      do {
          let localService = musicService.getLocalService()
          try await localService.deleteAlbum(detailed)
          
          await MainActor.run {
              // 🔑 清除本地音乐库缓存，确保列表页面能够刷新
              LocalLibraryDataManager.clearSharedCache()
              
              // 🔑 发送通知，通知本地音乐库视图刷新数据
              NotificationCenter.default.post(name: .localMusicLibraryDidChange, object: nil, userInfo: nil)
              
              if musicService.isHapticFeedbackEnabled {
                  let notificationFeedback = UINotificationFeedbackGenerator()
                  notificationFeedback.notificationOccurred(.success)
              }
              
              // 删除成功后返回上级页面
              dismiss()
          }
          
      } catch {
          await MainActor.run {
              isDeletingAlbum = false
              
              if musicService.isHapticFeedbackEnabled {
                  let notificationFeedback = UINotificationFeedbackGenerator()
                  notificationFeedback.notificationOccurred(.error)
              }
          }
          
          print("❌ 删除专辑失败: \(error)")
      }
  }
  
  // 🔑 修改：歌曲删除后刷新专辑
  private func refreshAlbumAfterSongDeletion() async {
      // 🔑 重新扫描本地音乐，确保数据是最新的
      let localService = musicService.getLocalService()
      await localService.scanLocalMusic()
      
      // 重新加载专辑详情   
      await loadDetailedAlbum(forceRefresh: true)
  }
}

// MARK: - 本地播放列表详情视图

struct LocalPlaylistDetailView: View {
  @EnvironmentObject private var musicService: MusicService
  let playlist: UniversalPlaylist
  @State private var detailedPlaylist: UniversalPlaylist?
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  @State private var playTapped = false
  @State private var shufflePlayTapped = false
  @State private var trackTapped = false
  
  /// 判断当前是否正在播放指定歌曲
  private func isPlaying(_ song: UniversalSong) -> Bool {
      let titleMatch = musicService.currentTitle.trimmingCharacters(in: .whitespaces).lowercased() ==
                      song.title.trimmingCharacters(in: .whitespaces).lowercased()
      let artistMatch = musicService.currentArtist.trimmingCharacters(in: .whitespaces).lowercased() ==
                       song.artistName.trimmingCharacters(in: .whitespaces).lowercased()
      
      return titleMatch && artistMatch && musicService.currentDataSource == .local
  }
  
  var body: some View {
      ScrollView {
          LazyVStack(spacing: 20) {
              // 顶部播放列表信息
              VStack(spacing: 16) {
                  ZStack {
                      Image("artwork-cassette")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 360)
                      
                      // 背景封面
                      defaultBackground
                      
                      // CassoFlow Logo
                      Image("CASSOFLOW")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 100)
                          .padding(.bottom, 110)
                      
                      // 磁带孔洞
                      Image("artwork-cassette-hole")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 360)
                      
                      // 播放列表信息
                      HStack {
                          // 小封面
                          defaultSmallCover
                          
                          VStack(alignment: .leading, spacing: 0) {
                              Text(playlist.name)
                                  .font(.headline.bold())
                                  .lineLimit(1)
                              
                              if let curatorName = playlist.curatorName {
                                  Text(curatorName)
                                      .font(.footnote)
                                      .lineLimit(1)
                                      .padding(.top, 4);
                              }
                              
                              Text("播放列表")
                                  .font(.footnote)
                                  .foregroundColor(.secondary)
                          }
                          
                          Spacer()
                      }
                      .padding(.top, 120)
                      .frame(width: 300)
                  }
                  
                  // 播放控制按钮
                  HStack(spacing: 20) {
                      Button {
                          playTapped.toggle()
                          if musicService.isHapticFeedbackEnabled {
                              let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                              impactFeedback.impactOccurred()
                          }
                          Task {
                              try await playPlaylist(shuffled: false)
                          }
                      } label: {
                          HStack {
                              Image(systemName: "play.fill")
                              Text("播放")
                                  .lineLimit(1)
                          }
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.secondary.opacity(0.2))
                          .foregroundColor(.primary)
                          .cornerRadius(8)
                      }
                      .disabled(isLoading)
                      
                      Button {
                          shufflePlayTapped.toggle()
                          if musicService.isHapticFeedbackEnabled {
                              let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                              impactFeedback.impactOccurred()
                          }
                          Task {
                              try await playPlaylist(shuffled: true)
                          }
                      } label: {
                          HStack {
                              Image(systemName: "shuffle")
                              Text("随机播放")
                                  .lineLimit(1)
                          }
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.secondary.opacity(0.2))
                          .foregroundColor(.primary)
                          .cornerRadius(8)
                      }
                      .disabled(isLoading)
                  }
              }
              .padding(.horizontal)
              
              // 歌曲列表
              VStack(alignment: .leading, spacing: 0) {
                  if isLoading {
                      ProgressView("正在加载歌曲...")
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 20)
                  } else if let error = errorMessage {
                      VStack(spacing: 16) {
                          Image(systemName: "exclamationmark.triangle.fill")
                              .font(.title2)
                              .foregroundColor(.yellow)
                          
                          Text(error)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                          
                          Button("重试") {
                              Task {
                                  await loadDetailedPlaylist()
                              }
                          }
                          .buttonStyle(.borderedProminent)
                          .tint(.yellow)
                          .foregroundColor(.black)
                      }
                      .padding(.vertical, 40)
                  } else if let detailed = detailedPlaylist, !detailed.songs.isEmpty {
                      Divider()
                          .padding(.leading, 20)
                          .padding(.trailing, 16)
                      
                      LazyVStack(spacing: 0) {
                          ForEach(Array(detailed.songs.enumerated()), id: \.element.id) { index, song in
                              LocalTrackRow(
                                  index: index,
                                  song: song,
                                  isPlaying: isPlaying(song),
                                  onDelete: {
                                      await refreshPlaylistAfterSongDeletion()
                                  },
                                  onTap: {
                                      trackTapped.toggle()
                                      if musicService.isHapticFeedbackEnabled {
                                          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                          impactFeedback.impactOccurred()
                                      }
                                      Task {
                                          try await playSong(song, from: detailed.songs, startingAt: index)
                                      }
                                  }
                              )
                              
                              if index < detailed.songs.count - 1 {
                                  Divider()
                                      .padding(.leading, 40)
                                      .padding(.trailing, 16)
                              }
                          }
                      }
                      
                      Divider()
                          .padding(.leading, 20)
                          .padding(.trailing, 16)
                  } else {
                      VStack(spacing: 12) {
                          Image(systemName: "music.note.list")
                              .font(.title2)
                              .foregroundColor(.secondary)
                          
                          Text("此播放列表暂无歌曲")
                              .foregroundColor(.secondary)
                      }
                      .padding(.vertical, 20)
                  }
              }
              
              // 底部信息
              if let detailed = detailedPlaylist, !detailed.songs.isEmpty {
                  LocalInfoFooter(
                      year: nil,
                      trackCount: detailed.songs.count,
                      totalDuration: detailed.songs.reduce(0) { $0 + $1.duration },
                      isPlaylist: true
                  )
              }
          }
          .padding(.vertical)
      }
      .navigationTitle(playlist.name)
      .navigationBarTitleDisplayMode(.inline)
      .task {
          await loadDetailedPlaylist()
      }
  }
  
  // MARK: - 默认视图
  
  private var defaultBackground: some View {
      ZStack {
          Color.black
          Image("CASSOFLOW")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 75)
      }
      .frame(width: 270, height: 120)
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .padding(.bottom, 37)
  }
  
  private var defaultSmallCover: some View {
      ZStack {
          Color.black
          Image("CASSOFLOW")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 30)
      }
      .frame(width: 60, height: 60)
      .clipShape(RoundedRectangle(cornerRadius: 2))
  }
  
  // MARK: - 数据加载
  
  private func loadDetailedPlaylist() async {
      await MainActor.run {
          isLoading = true
          errorMessage = nil
      }
      
      do {
          let coordinator = musicService.getCoordinator()
          let detailed = try await coordinator.getPlaylist(id: playlist.id)
          
          await MainActor.run {
              detailedPlaylist = detailed
              isLoading = false
              
              if detailed.songs.isEmpty {
                  errorMessage = "此播放列表没有歌曲"
              }
          }
      } catch {
          await MainActor.run {
              errorMessage = "加载播放列表详情失败：\(error.localizedDescription)"
              isLoading = false
          }
      }
  }
  
  // MARK: - 播放控制
  
  private func playPlaylist(shuffled: Bool) async throws {
      guard let detailed = detailedPlaylist, !detailed.songs.isEmpty else { return }
      
      let songs = shuffled ? detailed.songs.shuffled() : detailed.songs
      try await musicService.playUniversalSongs(songs)
  }
  
  private func playSong(_ song: UniversalSong, from songs: [UniversalSong], startingAt index: Int) async throws {
      try await musicService.playUniversalSongs(songs, startingAt: index)
  }
  
  // 🔑 新增：歌曲删除后刷新播放列表
  private func refreshPlaylistAfterSongDeletion() async {
      // 🔑 重新扫描本地音乐，确保数据是最新的
      let localService = musicService.getLocalService()
      await localService.scanLocalMusic()
      
      // 重新加载播放列表详情   
      await loadDetailedPlaylist()
  }
}

// MARK: - 本地艺术家详情视图

struct LocalArtistDetailView: View {
  @EnvironmentObject private var musicService: MusicService
  let artist: UniversalArtist
  @State private var detailedArtist: UniversalArtist?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @StateObject private var preferences = LocalLibraryPreferences() // 添加偏好设置
  
  var body: some View {
      ScrollView {
          LazyVStack(spacing: 20) {
              // 顶部艺术家信息
              VStack(spacing: 16) {
                  // 艺术家头像
                  ZStack {
                      Circle()
                          .fill(Color.yellow.opacity(0.2))
                          .frame(width: 120, height: 120)
                      
                      Image(systemName: "person.fill")
                          .font(.system(size: 60))
                          .foregroundColor(.yellow)
                  }
                  
                  VStack(spacing: 8) {
                      Text(artist.name)
                          .font(.largeTitle.bold())
                      
                      Text("\(artist.albumCount) 张专辑")
                          .font(.headline)
                          .foregroundColor(.secondary)
                  }
              }
              .padding(.horizontal)
              
              // 专辑列表
              VStack(alignment: .leading, spacing: 0) {
                  if isLoading {
                      ProgressView("正在加载专辑...")
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 20)
                  } else if let error = errorMessage {
                      VStack(spacing: 16) {
                          Image(systemName: "exclamationmark.triangle.fill")
                              .font(.title2)
                              .foregroundColor(.yellow)
                          
                          Text(error)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                          
                          Button("重试") {
                              Task {
                                  await loadDetailedArtist()
                              }
                          }
                          .buttonStyle(.borderedProminent)
                          .tint(.yellow)
                          .foregroundColor(.black)
                      }
                      .padding(.vertical, 40)
                  } else if let detailed = detailedArtist, !detailed.albums.isEmpty {
                      Text("专辑")
                          .font(.headline)
                          .padding(.horizontal)
                          .padding(.bottom, 8)
                      
                      // 专辑内容
                      if preferences.isGridMode {
                          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 20) {
                              ForEach(detailed.albums, id: \.id) { album in
                                  NavigationLink(destination: LocalMusicDetailView(album: album).environmentObject(musicService)) {
                                      LocalGridAlbumCell(album: album)
                                  }
                                  .buttonStyle(PlainButtonStyle())
                              }
                          }
                          .padding(.horizontal)
                      } else {
                          LazyVGrid(columns: [GridItem(.adaptive(minimum: 360))], spacing: 12) {
                              ForEach(detailed.albums, id: \.id) { album in
                                  NavigationLink(destination: LocalMusicDetailView(album: album).environmentObject(musicService)) {
                                      LocalListAlbumCell(album: album)
                                  }
                                  .buttonStyle(PlainButtonStyle())
                              }
                          }
                          .padding(.horizontal)
                      }
                  } else {
                      VStack(spacing: 12) {
                          Image(systemName: "opticaldisc")
                              .font(.title2)
                              .foregroundColor(.secondary)
                          
                          Text("此艺术家暂无专辑")
                              .foregroundColor(.secondary)
                      }
                      .padding(.vertical, 20)
                  }
              }
          }
          .padding(.vertical)
      }
      .navigationTitle(artist.name)
      .navigationBarTitleDisplayMode(.inline)
      .task {
          await loadDetailedArtist()
      }
  }
  
  // MARK: - 数据加载
  
  private func loadDetailedArtist() async {
      await MainActor.run {
          isLoading = true
          errorMessage = nil
      }
      
      do {
          let coordinator = musicService.getCoordinator()
          let detailed = try await coordinator.getArtist(id: artist.id)
          
          await MainActor.run {
              detailedArtist = detailed
              isLoading = false
              
              if detailed.albums.isEmpty {
                  errorMessage = "此艺术家没有专辑"
              }
          }
      } catch {
          await MainActor.run {
              errorMessage = "加载艺术家详情失败：\(error.localizedDescription)"
              isLoading = false
          }
      }
  }
}

// MARK: - 本地底部信息栏

struct LocalInfoFooter: View {
  let year: Int?
  let trackCount: Int
  let totalDuration: TimeInterval
  let isPlaylist: Bool
  
  var body: some View {
      VStack(alignment: .center, spacing: 4) {
          if let year = year, !isPlaylist {
              Text("发布于 \(String(year)) 年")
                  .font(.footnote)
                  .foregroundColor(.secondary)
          } else if isPlaylist {
              Text("本地播放列表")
                  .font(.footnote)
                  .foregroundColor(.secondary)
          }
          
          Text("\(trackCount)首歌曲 • \(formatMinutes(totalDuration))")
              .font(.footnote)
              .foregroundColor(.secondary)
      }
      .padding(.horizontal)
      .padding(.top, 16)
  }
  
  private func formatMinutes(_ duration: TimeInterval) -> String {
      let minutes = Int(duration) / 60
      
      if minutes < 60 {
          return String(localized: "\(minutes)分钟")
      } else {
          let hours = minutes / 60
          let remainingMinutes = minutes % 60
          return String(localized: "\(hours)小时\(remainingMinutes)分钟")
      }
  }
}

// MARK: - 预览

struct LocalMusicDetailView_Previews: PreviewProvider {
  static var previews: some View {
      let mockAlbum = UniversalAlbum(
          id: "mock-1",
          title: "本地专辑示例",
          artistName: "本地艺术家",
          year: 2024,
          genre: "摇滚",
          songCount: 10,
          duration: 2400,
          artworkURL: nil,
          songs: [],
          source: .local,
          originalData: "mock"
      )
      
      NavigationView {
          LocalMusicDetailView(album: mockAlbum)
              .environmentObject(MusicService.shared)
      }
  }
}

//
//  PlaylistDetailView.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/6/1.
//

/*import SwiftUI
import MusicKit

struct PlaylistDetailView: View {
    
    @EnvironmentObject private var musicService: MusicService
    let playlist: Playlist
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部专辑信息
                VStack(spacing: 16) {
                    AsyncImage(url: playlist.artwork?.url(width: 300, height: 300)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(spacing: 4) {
                        Text(playlist.title)
                            .font(.title2.bold())
                        
                        Text(playlist.artistName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let releaseDate = playlist.releaseDate {
                            Text("\(playlist.genreNames.first ?? "未知风格") • \(releaseDate.formatted(.dateTime.year()))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            Task {
                                try await musicService.playPlaylist(playlist)
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
                                try await musicService.playPlaylist(playlist, shuffled: true)
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
                VStack(alignment: .leading, spacing: 8) {
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
                            HStack {
                                // 替换序号为播放状态指示器
                                if isPlaying(track) {
                                    AudioWaveView()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Text("\(index + 1)")
                                        .frame(width: 24, alignment: .center)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .foregroundColor(isPlaying(track) ? .blue : .primary)
                                    Text(track.artistName)
                                        .font(.caption)
                                        .foregroundColor(isPlaying(track) ? .blue.opacity(0.8) : .secondary)
                                }
                                
                                Spacer()
                                
                                Text(formattedDuration(track.duration ?? 0))
                                    .font(.caption)
                                    .foregroundColor(isPlaying(track) ? .blue : .secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    try await musicService.playTrack(track, in: album)
                                }
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
                }
                
                // 底部信息
                if let releaseDate = album.releaseDate, !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发表于 \(releaseDate.formatted(.dateTime.year().month().day()))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        let totalDuration = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
                        Text("\(tracks.count) 首歌曲 • \(formattedDuration(totalDuration))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumTracks()
    }
}

#Preview {
    PlaylistDetailView()
}
*/

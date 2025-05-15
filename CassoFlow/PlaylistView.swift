import SwiftUI
import MusicKit

struct PlaylistView: View {
    @EnvironmentObject var musicPlayer: MusicPlayerService
    
    var body: some View {
        // 你的播放列表视图实现
        Text("播放列表视图")
    }
}

#Preview {
    PlaylistView()
        .environmentObject(MusicPlayerService())
}

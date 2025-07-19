import SwiftUI

struct CoverStyleSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        List {
            Section {
                ForEach(CoverStyle.allCases, id: \.self) { style in
                    CoverStyleRow(
                        style: style,
                        isSelected: musicService.currentCoverStyle == style
                    ) {
                        // 触觉反馈
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // 设置新的封面样式
                        musicService.setCoverStyle(style)
                    }
                }
            }
//            header: {
//                Text("选择磁带封面样式")
//            }
            footer: {
                Text("更改封面样式会影响专辑和歌单的封面展示方式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("封面样式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CoverStyleRow: View {
    let style: CoverStyle
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: style.iconName)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 标题
                    Text(style.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // 描述
                    Text(style.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 选中状态指示器
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CoverStyleSettingsView()
        .environmentObject(MusicService.shared)
}

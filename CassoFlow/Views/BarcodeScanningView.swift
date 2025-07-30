import SwiftUI
import MusicKit

/// 条形码扫描视图，用于识别一维条形码
struct BarcodeScanningView: UIViewControllerRepresentable {
    
    // MARK: - 生命周期
    
    init(detectedBarcode: Binding<String>, onAlbumFound: @escaping (Album) -> Void, onDismiss: @escaping () -> Void) {
        self._detectedBarcode = detectedBarcode
        self.onAlbumFound = onAlbumFound
        self.onDismiss = onDismiss
    }
    
    // MARK: - 属性
    
    @Binding var detectedBarcode: String
    let onAlbumFound: (Album) -> Void
    let onDismiss: () -> Void
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIViewController {
        let scanningVC = BarcodeScanningViewController(
            detectedBarcode: $detectedBarcode,
            onAlbumFound: onAlbumFound,
            onDismiss: onDismiss
        )
        
        let navigationController = UINavigationController(rootViewController: scanningVC)
        navigationController.modalPresentationStyle = .fullScreen
        
        return navigationController
    }
    
    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        // 底层视图控制器不需要任何更新
    }
}
import SwiftUI
import AVFoundation
import MusicKit

/// 条形码扫描视图，用于识别一维条形码
struct BarcodeScannerView: View {
    @Binding var detectedBarcode: String
    let onAlbumFound: (Album) -> Void
    let onDismiss: () -> Void
    
    @State private var isProcessingBarcode = false
    @State private var cameraPermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var showingLoadingIndicator = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAnimating = false // 简单的动画状态控制
    
    // MARK: - 生命周期
    
    init(detectedBarcode: Binding<String>, onAlbumFound: @escaping (Album) -> Void, onDismiss: @escaping () -> Void) {
        self._detectedBarcode = detectedBarcode
        self.onAlbumFound = onAlbumFound
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 摄像头预览层
                if cameraPermissionGranted {
                    CameraPreviewView(
                        isProcessingBarcode: $isProcessingBarcode,
                        detectedBarcode: $detectedBarcode,
                        onBarcodeDetected: handleDetectedBarcode
                    )
                    .ignoresSafeArea(.all) // 忽略所有安全区域，填满整个屏幕
                } else {
                    Color.black
                        .ignoresSafeArea(.all)
                }
                
                ZStack {
                // 半透明黑色背景遮罩 - 直接在顶层
                    Color.black.opacity(0.5)
                        .ignoresSafeArea(.all)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .frame(width: 300, height: 180)
                        .blendMode(.destinationOut) // 创建透明区域
                    
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 300, height: 180)
                        .overlay(
                            // 扫描线动画
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.green.opacity(0.0),
                                            Color.green.opacity(0.8)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 40)
                                .offset(y: isAnimating ? 60 : -60)
                                .opacity(isAnimating ? 0.3 : 1.0)
                                .animation(
                                    Animation.linear(duration: 2.0)
                                        .repeatForever(autoreverses: false),
                                    value: isAnimating
                                )
                                .onAppear {
                                    isAnimating = true
                                }
                        )
                    Text("请将条形码放在白色框内")
                        .foregroundColor(.white)
                        .font(.body)
                        .padding(.top, 230)
                }
                .compositingGroup() // 确保混合模式正确工作
                
                // 加载指示器
                if showingLoadingIndicator {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("正在搜索专辑...")
                            .foregroundColor(.white)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("扫描专辑条形码")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                checkCameraPermission()
            }
            .alert("需要摄像头权限", isPresented: $showingPermissionAlert) {
                Button("设置") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("取消", role: .cancel) {
                    onDismiss()
                }
            } message: {
                Text("扫描专辑条形码需要使用摄像头，请在设置中允许应用访问摄像头。")
            }
            .alert("搜索失败", isPresented: $showingError) {
                Button("重试") {
                    isProcessingBarcode = false
                }
                Button("取消", role: .cancel) {
                    onDismiss()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionGranted = granted
                    if !granted {
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            showingPermissionAlert = true
        }
    }
    
    private func handleDetectedBarcode(_ barcode: String) {
        guard !isProcessingBarcode else { return }
        
        isProcessingBarcode = true
        detectedBarcode = barcode
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            await searchAlbumByBarcode(barcode)
        }
    }
    
    @MainActor
    private func searchAlbumByBarcode(_ barcode: String) async {
        showingLoadingIndicator = true
        
        do {
            let albumsRequest = MusicCatalogResourceRequest<Album>(
                matching: \.upc,
                equalTo: barcode
            )
            
            let albumsResponse = try await albumsRequest.response()
            
            showingLoadingIndicator = false
            
            if let firstAlbum = albumsResponse.items.first {
                onAlbumFound(firstAlbum)
                onDismiss()
            } else {
                errorMessage = String(localized:"未能找到条形码为 \(barcode) 的专辑，请确认条形码正确或尝试其他专辑。")
                showingError = true
            }
        } catch {
            showingLoadingIndicator = false
            errorMessage = String(localized:"搜索专辑时发生错误：\(error.localizedDescription)")
            showingError = true
        }
    }
}

/// 摄像头预览视图
struct CameraPreviewView: UIViewRepresentable {
    @Binding var isProcessingBarcode: Bool
    @Binding var detectedBarcode: String
    let onBarcodeDetected: (String) -> Void
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if !isProcessingBarcode && !uiView.isRunning {
            uiView.startRunning()
        } else if isProcessingBarcode && uiView.isRunning {
            uiView.stopRunning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
        
        func didDetectBarcode(_ barcode: String) {
            parent.onBarcodeDetected(barcode)
        }
    }
}

/// 摄像头预览UI视图协议
protocol CameraPreviewDelegate: AnyObject {
    func didDetectBarcode(_ barcode: String)
}

/// 摄像头预览UI视图实现
class CameraPreviewUIView: UIView {
    weak var delegate: CameraPreviewDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCaptureSession()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCaptureSession()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private func setupCaptureSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        
        let captureSession = AVCaptureSession()
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard
            let videoCaptureDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
            captureSession.canAddInput(videoInput),
            captureSession.canAddOutput(metadataOutput)
        else { return }
        
        self.captureSession = captureSession
        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    func startRunning() {
        guard let captureSession = captureSession, !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
    }
    
    func stopRunning() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        captureSession.stopRunning()
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension CameraPreviewUIView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard
            let metadataObject = metadataObjects.first,
            let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
            let barcode = readableObject.stringValue
        else { return }
        
        delegate?.didDetectBarcode(barcode)
    }
}

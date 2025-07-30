import AVFoundation
import SwiftUI
import UIKit
import MusicKit

/// 条形码扫描视图控制器，用于识别一维条形码
/// 使用 AVCaptureSession 和 AVCaptureVideoPreviewLayer 实现
class BarcodeScanningViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    // MARK: - 生命周期
    
    init(detectedBarcode: Binding<String>, onAlbumFound: @escaping (Album) -> Void, onDismiss: @escaping () -> Void) {
        self._detectedBarcode = detectedBarcode
        self.onAlbumFound = onAlbumFound
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }
    
    // MARK: - 属性
    
    /// 条形码扫描视图检测到的条形码字符串
    @Binding var detectedBarcode: String
    
    /// 找到专辑时的回调
    let onAlbumFound: (Album) -> Void
    
    /// 关闭视图时的回调
    let onDismiss: () -> Void
    
    /// 用于启用相机的捕获会话
    private var captureSession: AVCaptureSession?
    
    /// 捕获会话的预览内容
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// 正在处理条形码
    private var isProcessingBarcode = false
    
    // MARK: - 视图生命周期
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 设置导航栏
        title = "扫描专辑条形码"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissView)
        )
        
        // 添加扫描指导框
        addScanningGuideView()
    }
    
    private func addScanningGuideView() {
        // 创建扫描指导框
        let guideView = UIView()
        guideView.backgroundColor = UIColor.clear
        guideView.layer.borderColor = UIColor.white.cgColor
        guideView.layer.borderWidth = 2.0
        guideView.layer.cornerRadius = 8.0
        guideView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(guideView)
        
        // 添加指导文本
        let instructionLabel = UILabel()
        instructionLabel.text = "将专辑条形码放在框内"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(instructionLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            guideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guideView.widthAnchor.constraint(equalToConstant: 280),
            guideView.heightAnchor.constraint(equalToConstant: 100),
            
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: guideView.bottomAnchor, constant: 20)
        ])
    }
    
    private func setupCaptureSession() {
        // 设置捕获设备
        let captureSession = AVCaptureSession()
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard
            let videoCaptureDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
            captureSession.canAddInput(videoInput),
            captureSession.canAddOutput(metadataOutput)
        else {
            showScanningUnsupportedAlert()
            return
        }
        
        // 配置捕获会话
        self.captureSession = captureSession
        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]
        
        // 配置预览层
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = previewLayer
        
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        
        // 启动捕获会话
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
    }
    
    private func showScanningUnsupportedAlert() {
        let alertController = UIAlertController(
            title: "不支持扫描",
            message: "您的设备不支持扫描功能，请使用带有摄像头的设备。",
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "确定", style: .default) { _ in
            self.onDismiss()
        }
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }
    
    @objc private func dismissView() {
        onDismiss()
    }
    
    /// 当视图出现时恢复当前捕获会话
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let captureSession = self.captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                captureSession.startRunning()
            }
        }
    }
    
    /// 当视图消失时暂停当前捕获会话
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let captureSession = self.captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    /// 运行捕获时隐藏状态栏
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    /// 强制此视图为竖屏方向
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: - 捕获元数据输出对象委托
    
    /// 捕获条形码字符串（如果当前捕获会话中有的话）
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessingBarcode else { return }
        
        // 检查是否有可用的条形码
        guard
            let previewLayer = self.previewLayer,
            let metadataObject = metadataObjects.first,
            let readableObject = previewLayer.transformedMetadataObject(for: metadataObject) as? AVMetadataMachineReadableCodeObject,
            let detectedBarcode = readableObject.stringValue
        else { return }
        
        isProcessingBarcode = true
        self.captureSession?.stopRunning()
        
        // 提供触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 显示识别到的条形码作为 UI 反馈
        showBarcodeDetectedFeedback(for: detectedBarcode, with: readableObject)
        
        // 记住识别到的条形码字符串
        self.detectedBarcode = detectedBarcode
        
        // 处理检测到的条形码
        handleDetectedBarcode(detectedBarcode)
    }
    
    // MARK: - 显示检测到的条形码
    
    /// 显示条形码检测反馈
    private func showBarcodeDetectedFeedback(for barcode: String, with readableObject: AVMetadataMachineReadableCodeObject) {
        // 高亮显示识别到的条形码
        if self.previewLayer != nil {
            var barcodeCorners = readableObject.corners
            if !barcodeCorners.isEmpty {
                let barcodePath = UIBezierPath()
                let firstCorner = barcodeCorners.removeFirst()
                barcodePath.move(to: firstCorner)
                for corner in barcodeCorners {
                    barcodePath.addLine(to: corner)
                }
                barcodePath.close()
                
//                addAnimatedBarcodeShape(with: barcodePath, to: previewLayer)
            }
        }
        
        // 显示条形码标签
        showBarcodeLabel(for: barcode)
    }
    
//    /// 高亮显示识别到的条形码
//    private func addAnimatedBarcodeShape(with barcodePath: UIBezierPath, to parentLayer: CALayer) {
//        let barcodeShapeLayer = CAShapeLayer()
//        barcodeShapeLayer.path = barcodePath.cgPath
//        barcodeShapeLayer.strokeColor = UIColor.systemGreen.cgColor
//        barcodeShapeLayer.lineWidth = 3.0
//        barcodeShapeLayer.lineJoin = .round
//        barcodeShapeLayer.lineCap = .round
//        
//        let barcodeBounds = barcodePath.bounds
//        barcodeShapeLayer.bounds = barcodeBounds
//        barcodeShapeLayer.position = CGPoint(x: barcodeBounds.midX, y: barcodeBounds.midY)
//        barcodeShapeLayer.masksToBounds = true
//        parentLayer.addSublayer(barcodeShapeLayer)
//        
//        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
//        opacityAnimation.autoreverses = true
//        opacityAnimation.duration = 0.3
//        opacityAnimation.repeatCount = 3
//        opacityAnimation.toValue = 0.0
//        barcodeShapeLayer.add(opacityAnimation, forKey: opacityAnimation.keyPath)
//    }
    
    /// 显示识别到的条形码字符串
    private func showBarcodeLabel(for detectedBarcode: String) {
        let fontSize = 18.0
        let cornerRadius = 8.0
        
        let label = UILabel()
        label.text = "条形码: \(detectedBarcode)"
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.sizeToFit()
        
        let labelContainer = UIView()
        labelContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        labelContainer.layer.cornerRadius = cornerRadius
        labelContainer.bounds = CGRect(origin: .zero, size: label.bounds.insetBy(dx: -cornerRadius * 2, dy: -cornerRadius).size)
        label.center = CGPoint(x: labelContainer.bounds.midX, y: labelContainer.bounds.midY)
        labelContainer.addSubview(label)
        
        let parentViewBounds = view.bounds
        let verticalOffset = parentViewBounds.minY + (parentViewBounds.height * 0.8)
        labelContainer.center = CGPoint(x: parentViewBounds.midX, y: verticalOffset)
        
        labelContainer.alpha = 0
        view.addSubview(labelContainer)
        
        UIView.animate(withDuration: 0.3) {
            labelContainer.alpha = 1
        }
        
        // 2秒后移除标签
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.3) {
                labelContainer.alpha = 0
            } completion: { _ in
                labelContainer.removeFromSuperview()
            }
        }
    }
    
    // MARK: - 处理检测到的条形码
    
    /// 处理检测到的条形码并查找对应专辑
    private func handleDetectedBarcode(_ detectedBarcode: String) {
        Task {
            await searchAlbumByBarcode(detectedBarcode)
        }
    }
    
    @MainActor
    private func searchAlbumByBarcode(_ barcode: String) async {
        // 显示加载指示器
        showLoadingIndicator()
        
        do {
            // 通过条形码搜索专辑
            let albumsRequest = MusicCatalogResourceRequest<Album>(
                matching: \.upc,
                equalTo: barcode
            )
            
            let albumsResponse = try await albumsRequest.response()
            
            hideLoadingIndicator()
            
            if let firstAlbum = albumsResponse.items.first {
                // 找到专辑，调用回调
                onAlbumFound(firstAlbum)
                onDismiss()
            } else {
                // 未找到专辑
                showAlbumNotFoundAlert(for: barcode)
            }
        } catch {
            hideLoadingIndicator()
            showErrorAlert(error: error)
        }
    }
       
    private var loadingView: UIView?
    
    private func showLoadingIndicator() {
        let loadingView = UIView()
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        let label = UILabel()
        label.text = "正在搜索专辑..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(label)
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            
            label.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
        ])
        
        self.loadingView = loadingView
    }
    
    private func hideLoadingIndicator() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
    
    private func showAlbumNotFoundAlert(for barcode: String) {
        let alertController = UIAlertController(
            title: "未找到专辑",
            message: "未能找到条形码为 \(barcode) 的专辑。请确认条形码正确或尝试其他专辑。",
            preferredStyle: .alert
        )
        
        let retryAction = UIAlertAction(title: "重试", style: .default) { _ in
            self.isProcessingBarcode = false
            if let captureSession = self.captureSession {
                DispatchQueue.global(qos: .background).async {
                    captureSession.startRunning()
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            self.onDismiss()
        }
        
        alertController.addAction(retryAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
    
    private func showErrorAlert(error: Error) {
        let alertController = UIAlertController(
            title: "搜索失败",
            message: "搜索专辑时发生错误：\(error.localizedDescription)",
            preferredStyle: .alert
        )
        
        let retryAction = UIAlertAction(title: "重试", style: .default) { _ in
            self.isProcessingBarcode = false
            if let captureSession = self.captureSession {
                DispatchQueue.global(qos: .background).async {
                    captureSession.startRunning()
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            self.onDismiss()
        }
        
        alertController.addAction(retryAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
}

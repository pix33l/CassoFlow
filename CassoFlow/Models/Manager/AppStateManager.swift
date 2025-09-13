import Foundation
import UIKit

/// 统一的应用状态管理器
class AppStateManager {
    static let shared = AppStateManager()
    
    // 应用状态
    @Published private(set) var isAppInBackground = false
    @Published private(set) var isAppActive = true
    
    // 统一的后台更新定时器
    private var backgroundUpdateTimer: Timer?
    private var lastBackgroundUpdateTime: Date?
    
    // 统一的更新间隔
    private let backgroundUpdateInterval: TimeInterval = 5.0
    
    // 状态变化回调注册
    private var stateChangeHandlers: [UUID: (AppState) -> Void] = [:]
    
    private init() {
        setupAppStateNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopBackgroundUpdateTimer()
    }
    
    // MARK: - 公共方法
    
    /// 注册状态变化回调
    func registerStateChangeHandler(_ handler: @escaping (AppState) -> Void) -> UUID {
        let id = UUID()
        stateChangeHandlers[id] = handler
        return id
    }
    
    /// 注销状态变化回调
    func unregisterStateChangeHandler(_ id: UUID) {
        stateChangeHandlers.removeValue(forKey: id)
    }
    
    // MARK: - 私有方法
    
    private func setupAppStateNotifications() {
        // 应用变为活跃
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
        
        // 应用即将失去活跃
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        // 应用进入后台
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppEnterBackground()
        }
        
        // 应用回到前台
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
        
        // 应用即将终止
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillTerminate()
        }
    }
    
    private func handleAppDidBecomeActive() {
        isAppActive = true
        print("📱 AppStateManager: 应用变为活跃")
        
        // 🔑 新增：确保音频会话在前台时保持活跃
        let _ = AudioSessionManager.shared.ensureForegroundAudioSession()
        
        // 通知所有注册的服务
        notifyStateChange(.didBecomeActive)
    }
    
    private func handleAppWillResignActive() {
        isAppActive = false
        print("📱 AppStateManager: 应用即将失去活跃")
        
        // 通知相关服务准备进入后台
        notifyStateChange(.willResignActive)
    }
    
    private func handleAppEnterBackground() {
        isAppInBackground = true
        print("📱 AppStateManager: 应用进入后台")
        
        // 启动统一的后台更新定时器
        startBackgroundUpdateTimer()
        
        // 通知相关服务进入后台
        notifyStateChange(.didEnterBackground)
    }
    
    private func handleAppWillEnterForeground() {
        isAppInBackground = false
        print("📱 AppStateManager: 应用回到前台")
        
        // 停止后台更新定时器
        stopBackgroundUpdateTimer()
        
        // 通知相关服务回到前台
        notifyStateChange(.willEnterForeground)
        
        // 延迟通知状态恢复完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.notifyStateChange(.didEnterForegroundComplete)
        }
    }
    
    private func handleAppWillTerminate() {
        print("📱 AppStateManager: 应用即将终止")
        
        // 停止所有定时器
        stopBackgroundUpdateTimer()
        
        // 通知相关服务应用即将终止
        notifyStateChange(.willTerminate)
    }
    
    // MARK: - 后台更新定时器
    
    private func startBackgroundUpdateTimer() {
        guard backgroundUpdateTimer == nil else { return }
        
        backgroundUpdateTimer = Timer.scheduledTimer(withTimeInterval: backgroundUpdateInterval, repeats: true) { [weak self] _ in
            self?.handleBackgroundUpdate()
        }
        
        print("⏰ AppStateManager: 启动后台更新定时器")
    }
    
    private func stopBackgroundUpdateTimer() {
        backgroundUpdateTimer?.invalidate()
        backgroundUpdateTimer = nil
        print("⏰ AppStateManager: 停止后台更新定时器")
    }
    
    private func handleBackgroundUpdate() {
        lastBackgroundUpdateTime = Date()
        
        // 🔑 关键修复：在后台状态更新前，先确保锁屏信息有效
        if NowPlayingManager.shared.hasActiveDelegate && NowPlayingManager.shared.isPlaying {
            print("🔄 AppStateManager: 后台状态更新前刷新锁屏信息")
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
        
        // 通知相关服务进行后台更新
        notifyStateChange(.backgroundUpdate)
        
        print("🔄 AppStateManager: 后台状态更新")
        
        // 🔑 关键修复：在后台状态更新后，再次确保锁屏信息有效
        if NowPlayingManager.shared.hasActiveDelegate && NowPlayingManager.shared.isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔄 AppStateManager: 后台状态更新后刷新锁屏信息")
                NowPlayingManager.shared.updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - 状态通知
    
    private func notifyStateChange(_ state: AppState) {
        // 通知所有注册的处理器
        for handler in stateChangeHandlers.values {
            handler(state)
        }
    }
}

// MARK: - 应用状态枚举
enum AppState {
    case didBecomeActive           // 应用变为活跃
    case willResignActive          // 应用即将失去活跃
    case didEnterBackground        // 应用进入后台
    case willEnterForeground       // 应用回到前台
    case didEnterForegroundComplete // 应用回到前台完成
    case backgroundUpdate          // 后台更新
    case willTerminate            // 应用即将终止
}
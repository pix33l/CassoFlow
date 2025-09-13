import Foundation

/// 后台Timer统一管理器 - 解决双Timer资源浪费问题
class BackgroundTimerManager {
    static let shared = BackgroundTimerManager()
    
    // MARK: - 属性
    private var timer: Timer?
    private var updateInterval: TimeInterval = 4.0 // 优化为4秒间隔
    private var subscribers: [WeakWrapper] = []
    private var isRunning = false
    
    // MARK: - 私有初始化
    private init() {}
    
    // MARK: - 公共方法
    
    /// 启动后台Timer
    func start() {
        guard !isRunning else {
            print("🔍 BackgroundTimerManager: Timer已在运行")
            return
        }
        
        print("🔍 BackgroundTimerManager: 启动后台Timer，间隔: \(updateInterval)秒")
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.notifySubscribers()
        }
        
        isRunning = true
    }
    
    /// 停止后台Timer
    func stop() {
        guard isRunning else {
            print("🔍 BackgroundTimerManager: Timer未运行")
            return
        }
        
        print("🔍 BackgroundTimerManager: 停止后台Timer")
        
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    /// 订阅Timer更新
    func subscribe(_ subscriber: BackgroundTimerSubscriber) {
        // 避免重复订阅
        subscribers.removeAll { $0.object === subscriber || $0.object == nil }
        subscribers.append(WeakWrapper(subscriber))
        print("🔍 BackgroundTimerManager: 新增订阅者，当前订阅数: \(subscribers.count)")
    }
    
    /// 取消订阅
    func unsubscribe(_ subscriber: BackgroundTimerSubscriber) {
        subscribers.removeAll { $0.object === subscriber || $0.object == nil }
        print("🔍 BackgroundTimerManager: 移除订阅者，当前订阅数: \(subscribers.count)")
    }
    
    /// 设置更新间隔（可选）
    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = interval
        print("🔍 BackgroundTimerManager: 更新间隔设置为 \(interval)秒")
        
        // 如果Timer正在运行，重启以应用新间隔
        if isRunning {
            stop()
            start()
        }
    }
    
    // MARK: - 私有方法
    
    /// 通知所有订阅者
    private func notifySubscribers() {
        // 清理无效订阅者
        subscribers.removeAll { $0.object == nil }
        
        print("🔍 BackgroundTimerManager: 通知 \(subscribers.count) 个订阅者")
        
        // 通知所有有效订阅者
        subscribers.forEach { wrapper in
            wrapper.object?.onBackgroundTimerUpdate()
        }
    }
}

// MARK: - 弱引用包装器
private class WeakWrapper {
    weak var object: BackgroundTimerSubscriber?
    
    init(_ object: BackgroundTimerSubscriber) {
        self.object = object
    }
}

// MARK: - 后台Timer订阅者协议
protocol BackgroundTimerSubscriber: AnyObject {
    /// 后台Timer更新回调
    func onBackgroundTimerUpdate()
}

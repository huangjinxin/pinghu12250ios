//
//  OfflineManager.swift
//  pinghu12250
//
//  离线模式管理器 - 检测网络状态，协调离线/在线模式
//

import Foundation
import Network
import Combine

/// 离线模式管理器 - 单例
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    // MARK: - 网络监控

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - 状态

    @Published var isOnline: Bool = true
    @Published var isOfflineMode: Bool = false  // 用户手动开启的离线模式
    @Published var connectionType: ConnectionType = .unknown

    // MARK: - 缓存服务

    let cacheService = CacheService.shared

    // MARK: - 初始化

    private init() {
        startNetworkMonitoring()
        loadOfflineModePreference()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func loadOfflineModePreference() {
        isOfflineMode = UserDefaults.standard.bool(forKey: "isOfflineMode")
    }

    // MARK: - 模式切换

    /// 切换离线模式
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        UserDefaults.standard.set(isOfflineMode, forKey: "isOfflineMode")
    }

    /// 设置离线模式
    func setOfflineMode(_ enabled: Bool) {
        isOfflineMode = enabled
        UserDefaults.standard.set(enabled, forKey: "isOfflineMode")
    }

    /// 是否应该使用离线数据
    var shouldUseOfflineData: Bool {
        !isOnline || isOfflineMode
    }

    /// 是否可以进行网络请求
    var canMakeNetworkRequest: Bool {
        isOnline && !isOfflineMode
    }

    // MARK: - 下载管理

    /// 下载教材以供离线使用
    func downloadTextbookForOffline(textbookId: String, pdfUrl: String) async throws {
        _ = try await cacheService.downloadPDF(textbookId: textbookId, pdfUrl: pdfUrl)
    }

    /// 检查教材是否可离线使用
    func isTextbookAvailableOffline(textbookId: String) -> Bool {
        cacheService.isPDFCached(textbookId: textbookId)
    }

    /// 检查EPUB是否可离线使用
    func isEPUBAvailableOffline(textbookId: String) -> Bool {
        cacheService.isEPUBCached(textbookId: textbookId)
    }

    /// 检查教材是否可离线使用（统一方法）
    func isContentAvailableOffline(textbookId: String, isEpub: Bool) -> Bool {
        if isEpub {
            return cacheService.isEPUBCached(textbookId: textbookId)
        } else {
            return cacheService.isPDFCached(textbookId: textbookId)
        }
    }

    /// 删除离线教材
    func removeOfflineTextbook(textbookId: String) {
        cacheService.deleteCachedPDF(textbookId: textbookId)
    }

    /// 删除离线EPUB
    func removeOfflineEPUB(textbookId: String) {
        cacheService.deleteCachedEPUB(textbookId: textbookId)
    }

    /// 获取所有已下载的教材ID
    var offlineTextbookIds: Set<String> {
        cacheService.cachedTextbookIds
    }

    /// 获取所有已下载的EPUB ID
    var offlineEpubIds: Set<String> {
        cacheService.cachedEpubIds
    }

    // MARK: - 诗词离线管理

    /// 缓存诗词供离线使用
    func cachePoetryForOffline<T: Encodable>(poetryId: String, poetry: T) throws {
        try cacheService.cachePoetry(poetryId: poetryId, data: poetry)
    }

    /// 获取离线诗词
    func getOfflinePoetry<T: Decodable>(poetryId: String, type: T.Type) -> T? {
        cacheService.getCachedPoetry(poetryId: poetryId, type: type)
    }

    /// 检查诗词是否可离线使用
    func isPoetryAvailableOffline(poetryId: String) -> Bool {
        cacheService.isPoetryCached(poetryId: poetryId)
    }

    // MARK: - 缓存统计

    /// 获取缓存大小描述
    var cacheSizeDescription: String {
        cacheService.formattedCacheSize()
    }

    /// 清除所有离线数据
    func clearAllOfflineData() {
        cacheService.clearAllCache()
    }
}

// MARK: - 连接类型

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown

    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "蜂窝网络"
        case .ethernet: return "以太网"
        case .unknown: return "未知"
        }
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown: return "questionmark.circle"
        }
    }
}

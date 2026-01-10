//
//  PDFPageCache.swift
//  pinghu12250
//
//  PDF 页面缓存池 - 提升翻页流畅度
//  优化：添加并发控制，防止快速翻页时任务堆积
//

import Foundation
@preconcurrency import PDFKit
import UIKit
import Combine

// MARK: - PDF 渲染协调器（并发控制）

/// PDF 渲染协调器，限制同时渲染的任务数量
actor PDFRenderCoordinator {
    static let shared = PDFRenderCoordinator()

    // 最多同时渲染 2 页
    private let semaphore = AsyncSemaphore(value: 2)
    // 当前活跃的渲染任务
    private var activeTasks: [Int: Task<UIImage?, Never>] = [:]
    // 是否已取消所有任务
    private var isCancelled = false

    private init() {}

    /// 取消所有正在进行的渲染任务
    func cancelAll() {
        isCancelled = true
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        // 重置取消状态（延迟，确保任务有机会响应取消）
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            isCancelled = false
        }
    }

    /// 取消指定页面的渲染任务
    func cancel(page: Int) {
        activeTasks[page]?.cancel()
        activeTasks.removeValue(forKey: page)
    }

    /// 渲染指定页面（带并发控制）
    func render(
        page: PDFPage,
        pageIndex: Int,
        size: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        // 检查是否已取消
        guard !isCancelled else { return nil }

        // 如果已有该页的渲染任务，直接返回
        if let existingTask = activeTasks[pageIndex] {
            return await existingTask.value
        }

        // 创建渲染任务
        let task = Task<UIImage?, Never> {
            // 等待信号量
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }

            // 再次检查是否取消
            guard !Task.isCancelled else { return nil }

            // 执行渲染（在后台线程）
            // 先获取 page 的边界，避免后续在闭包中访问 page
            let pageRect = page.bounds(for: .mediaBox)
            return await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = Self.renderPageSyncWithRect(pageRect: pageRect, page: page, size: size, scale: scale)
                    continuation.resume(returning: image)
                }
            }
        }

        activeTasks[pageIndex] = task
        let result = await task.value
        activeTasks.removeValue(forKey: pageIndex)

        return result
    }

    /// 同步渲染页面（在后台线程调用）- 使用预先获取的边界
    private static func renderPageSyncWithRect(pageRect: CGRect, page: PDFPage, size: CGSize, scale: CGFloat) -> UIImage? {
        // 计算适配尺寸
        let fitScale = min(size.width / pageRect.width, size.height / pageRect.height) * scale
        let renderSize = CGSize(
            width: pageRect.width * fitScale,
            height: pageRect.height * fitScale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)

        return renderer.image { context in
            // 白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            // 翻转坐标系
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: fitScale, y: -fitScale)

            // 绘制页面
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    /// 同步渲染页面（在后台线程调用）
    private static func renderPageSync(page: PDFPage, size: CGSize, scale: CGFloat) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)

        // 计算适配尺寸
        let fitScale = min(size.width / pageRect.width, size.height / pageRect.height) * scale
        let renderSize = CGSize(
            width: pageRect.width * fitScale,
            height: pageRect.height * fitScale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)

        return renderer.image { context in
            // 白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            // 翻转坐标系
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: fitScale, y: -fitScale)

            // 绘制页面
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    /// 当前活跃任务数
    var activeTaskCount: Int {
        activeTasks.count
    }
}

// MARK: - PDF 页面缓存管理器

/// PDF页面渲染缓存，预渲染前后页面提升翻页流畅度
@MainActor
final class PDFPageCache: ObservableObject {
    // 单例
    static let shared = PDFPageCache()

    // 缓存配置
    private let cacheSize = 5  // 缓存页数：当前页 + 前后各2页
    private let renderScale: CGFloat = 2.0  // 渲染倍率

    // 缓存存储
    private var cache = NSCache<NSNumber, UIImage>()
    private var currentDocument: PDFDocument?

    // 预加载状态
    @Published var preloadProgress: [Int: Double] = [:]

    // 预加载开关（内存降级时关闭）
    @Published private(set) var isPreloadEnabled: Bool = true

    // 当前预加载任务（用于取消）
    private var preloadTask: Task<Void, Never>?

    // 上次预加载的页面范围
    private var lastPreloadRange: ClosedRange<Int>?

    private init() {
        cache.countLimit = cacheSize
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB 限制
    }

    // MARK: - 预加载控制

    /// 设置预加载开关（内存降级时调用）
    func setPreloadEnabled(_ enabled: Bool) {
        guard isPreloadEnabled != enabled else { return }

        isPreloadEnabled = enabled

        if !enabled {
            // 禁用时取消所有预加载任务
            preloadTask?.cancel()
            preloadTask = nil
            #if DEBUG
            print("[PDFPageCache] 预加载已禁用")
            #endif
        } else {
            #if DEBUG
            print("[PDFPageCache] 预加载已启用")
            #endif
        }
    }

    // MARK: - 公共方法

    /// 设置当前文档
    func setDocument(_ document: PDFDocument?) {
        if currentDocument !== document {
            // 取消所有进行中的渲染
            preloadTask?.cancel()
            Task { await PDFRenderCoordinator.shared.cancelAll() }

            cache.removeAllObjects()
            preloadProgress.removeAll()
            lastPreloadRange = nil
            currentDocument = document
        }
    }

    /// 获取页面渲染图（优先从缓存）
    func getPageImage(at pageIndex: Int, size: CGSize) -> UIImage? {
        // 检查缓存
        if let cached = cache.object(forKey: NSNumber(value: pageIndex)) {
            return cached
        }

        // 同步渲染（仅当缓存未命中时）
        guard let document = currentDocument,
              let page = document.page(at: pageIndex) else {
            return nil
        }

        let image = renderPageSync(page, size: size)
        if let image = image {
            cache.setObject(image, forKey: NSNumber(value: pageIndex))
        }
        return image
    }

    /// 异步获取页面图片
    func getPageImageAsync(at pageIndex: Int, size: CGSize) async -> UIImage? {
        // 检查缓存
        if let cached = cache.object(forKey: NSNumber(value: pageIndex)) {
            return cached
        }

        guard let document = currentDocument,
              let page = document.page(at: pageIndex) else {
            return nil
        }

        // 使用协调器渲染
        let image = await PDFRenderCoordinator.shared.render(
            page: page,
            pageIndex: pageIndex,
            size: size,
            scale: renderScale
        )

        if let image = image {
            cache.setObject(image, forKey: NSNumber(value: pageIndex))
        }

        return image
    }

    /// 预加载指定页码附近的页面
    func preloadPages(around currentPage: Int, totalPages: Int, size: CGSize) {
        // 检查预加载开关
        guard isPreloadEnabled else { return }

        guard let document = currentDocument else { return }

        // 计算需要预加载的页面范围
        let startPage = max(0, currentPage - 2)
        let endPage = min(totalPages - 1, currentPage + 2)
        let newRange = startPage...endPage

        // 如果范围没变，不需要重新预加载
        if lastPreloadRange == newRange {
            return
        }

        // 取消之前的预加载任务
        preloadTask?.cancel()

        // 更新范围记录
        lastPreloadRange = newRange

        // 创建新的预加载任务
        preloadTask = Task { [weak self] in
            guard let self = self else { return }

            // 按距离当前页的远近排序（优先加载当前页附近的）
            let sortedPages = (startPage...endPage).sorted {
                abs($0 - currentPage) < abs($1 - currentPage)
            }

            for pageIndex in sortedPages {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                // 跳过已缓存的
                if cache.object(forKey: NSNumber(value: pageIndex)) != nil {
                    await MainActor.run {
                        self.preloadProgress[pageIndex] = 1.0
                    }
                    continue
                }

                guard let page = document.page(at: pageIndex) else { continue }

                // 使用协调器渲染（自动限制并发）
                let image = await PDFRenderCoordinator.shared.render(
                    page: page,
                    pageIndex: pageIndex,
                    size: size,
                    scale: renderScale
                )

                // 再次检查是否取消
                guard !Task.isCancelled else { return }

                if let image = image {
                    await MainActor.run {
                        self.cache.setObject(image, forKey: NSNumber(value: pageIndex))
                        self.preloadProgress[pageIndex] = 1.0
                    }
                }
            }
        }
    }

    /// 清空缓存
    func clearCache() {
        preloadTask?.cancel()
        Task { await PDFRenderCoordinator.shared.cancelAll() }

        cache.removeAllObjects()
        preloadProgress.removeAll()
        lastPreloadRange = nil
    }

    // MARK: - 私有方法

    /// 同步渲染单页为图片（用于首次显示）
    private func renderPageSync(_ page: PDFPage, size: CGSize) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)

        let scale = min(size.width / pageRect.width, size.height / pageRect.height) * renderScale
        let renderSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

// MARK: - PDF 缓存视图包装器

import SwiftUI

/// 使用缓存的PDF页面视图
struct CachedPDFPageView: View {
    let pageIndex: Int
    let document: PDFDocument
    let size: CGSize

    @State private var pageImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image = pageImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                // 加载占位
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadPage()
        }
        .onChange(of: pageIndex) {
            loadPage()
        }
    }

    private func loadPage() {
        Task { @MainActor in
            isLoading = true
            let cache = PDFPageCache.shared
            cache.setDocument(document)

            // 使用异步方法获取图片
            if let image = await cache.getPageImageAsync(at: pageIndex, size: size) {
                pageImage = image
                isLoading = false
            } else if let image = cache.getPageImage(at: pageIndex, size: size) {
                // 降级到同步方法
                pageImage = image
                isLoading = false
            }

            // 预加载附近页面
            cache.preloadPages(
                around: pageIndex,
                totalPages: document.pageCount,
                size: size
            )
        }
    }
}

// MARK: - 低分辨率快速预览

/// 低分辨率PDF页面预览（用于快速翻页时的过渡）
@MainActor
final class LowResPageCache {
    static let shared = LowResPageCache()

    private var cache = NSCache<NSNumber, UIImage>()
    private let previewScale: CGFloat = 0.5  // 低分辨率预览

    private init() {
        cache.countLimit = 10
    }

    /// 获取低分辨率预览
    func getLowResPreview(for page: PDFPage, pageIndex: Int) -> UIImage? {
        if let cached = cache.object(forKey: NSNumber(value: pageIndex)) {
            return cached
        }

        let pageRect = page.bounds(for: .mediaBox)
        let previewSize = CGSize(
            width: pageRect.width * previewScale,
            height: pageRect.height * previewScale
        )

        let renderer = UIGraphicsImageRenderer(size: previewSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: previewSize))

            context.cgContext.translateBy(x: 0, y: previewSize.height)
            context.cgContext.scaleBy(x: previewScale, y: -previewScale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        cache.setObject(image, forKey: NSNumber(value: pageIndex))
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

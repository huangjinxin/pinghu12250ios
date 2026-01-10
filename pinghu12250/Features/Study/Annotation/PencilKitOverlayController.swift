//
//  PencilKitOverlayController.swift
//  pinghu12250
//
//  PencilKit 手写控制器 - 负责 PKCanvasView 的管理与笔画提交
//
//  架构说明（Apple 官方推荐级）：
//  - PKCanvasView 作为临时绘制层，覆盖在 PDFView 上方
//  - 触摸类型完全隔离（不使用 require(toFail:)）：
//    - PDFView.scrollView 的手势：allowedTouchTypes = [.direct]（只响应手指）
//    - PKCanvasView：drawingPolicy = .pencilOnly（只响应 Pencil）
//  - 两者完全独立，互不干扰，无状态依赖
//  - 抬笔后自动提交笔画到 PDFAnnotation.ink
//  - 线宽缩放补偿：adjustedLineWidth = rawLineWidth / scaleFactor
//

import UIKit
import PDFKit
import PencilKit
import Combine

// MARK: - PencilKit Overlay Controller

@available(iOS 16.0, *)
@MainActor
final class PencilKitOverlayController: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var hasUncommittedStrokes = false

    // MARK: - Public Properties

    /// PKCanvasView 画布
    /// - drawingPolicy = .pencilOnly：只响应 Apple Pencil
    /// - 手指触摸会穿透到底层 PDFView（因为 PDFView.scrollView 设置了只接收手指）
    let canvasView: PKCanvasView

    weak var pdfView: PDFView?
    weak var annotationManager: InkAnnotationManager?

    // 当前工具设置
    var currentColor: UIColor = .systemBlue {
        didSet { updateTool() }
    }
    var currentLineWidth: CGFloat = 3.0 {
        didSet { updateTool() }
    }
    var currentToolType: InkToolType = .pen {
        didSet { updateTool() }
    }

    // MARK: - Private Properties

    private let coordinateConverter = AnnotationCoordinateConverter()
    private var commitWorkItem: DispatchWorkItem?
    private let commitDelay: TimeInterval = 0.3  // 抬笔后延迟提交

    private var currentPageIndex: Int = 0
    private var touchIsolationConfigured = false  // 触摸隔离是否已配置

    // MARK: - Init

    override init() {
        canvasView = PKCanvasView()
        super.init()

        setupCanvasView()
    }

    // MARK: - Setup

    private func setupCanvasView() {
        // 透明背景，不遮挡 PDFView
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // 【核心】仅响应 Apple Pencil 绘制
        canvasView.drawingPolicy = .pencilOnly

        // 禁用画布自身的滚动
        canvasView.isScrollEnabled = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false

        // 设置代理
        canvasView.delegate = self

        // 设置默认工具
        updateTool()

        #if DEBUG
        print("[PencilKitOverlay] PKCanvasView initialized - drawingPolicy=pencilOnly")
        #endif
    }

    // MARK: - Touch Type Isolation (Apple 官方推荐方案)

    /// 配置触摸类型隔离（一次性配置，幂等）
    ///
    /// 原理：
    /// - PDFView.scrollView 的手势设置 allowedTouchTypes = [.direct]（只响应手指）
    /// - PKCanvasView 的 drawingPolicy = .pencilOnly（只响应 Pencil）
    /// - 两者完全隔离，不需要 require(toFail:)，不会有状态冲突
    ///
    /// 优点：
    /// - 状态简单，无循环依赖
    /// - 反复进入/退出批注模式不会影响手势配置
    /// - 接近 iOS Preview.app 的体验
    func configureTouchTypeIsolation(pdfView: PDFView) {
        guard !touchIsolationConfigured else {
            #if DEBUG
            print("[PencilKitOverlay] Touch isolation already configured, skipping")
            #endif
            return
        }

        // 找到 PDFView 内部的 scrollView
        guard let scrollView = findScrollView(in: pdfView) else {
            #if DEBUG
            print("[PencilKitOverlay] Warning: Could not find PDFView's scrollView")
            #endif
            return
        }

        // 【关键】设置 scrollView 的手势只接收手指触摸（不接收 Pencil）
        let fingerTouchType = UITouch.TouchType.direct.rawValue as NSNumber

        var configuredCount = 0
        for gesture in scrollView.gestureRecognizers ?? [] {
            // 只修改 pan 和 pinch 手势，保留其他手势（如 tap）的默认行为
            if gesture is UIPanGestureRecognizer || gesture is UIPinchGestureRecognizer {
                gesture.allowedTouchTypes = [fingerTouchType]
                configuredCount += 1
                #if DEBUG
                print("[PencilKitOverlay] \(type(of: gesture)) restricted to finger-only")
                #endif
            }
        }

        touchIsolationConfigured = true

        #if DEBUG
        print("[PencilKitOverlay] Touch isolation configured: \(configuredCount) gestures restricted to finger")
        print("[PencilKitOverlay] Result: Pencil → PKCanvasView (draw), Finger → PDFView (scroll/zoom)")
        #endif
    }

    /// 递归查找 PDFView 内部的 scrollView
    private func findScrollView(in view: UIView) -> UIScrollView? {
        // 优先检查直接子视图
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                return scrollView
            }
        }
        // 递归检查
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Tool Management

    private func updateTool() {
        switch currentToolType {
        case .eraser:
            // 使用对象橡皮擦（擦除整条笔画）
            canvasView.tool = PKEraserTool(.bitmap)

        case .pen, .pencil, .highlighter:
            let inkType = pencilKitInkType(for: currentToolType)
            let ink = PKInkingTool(inkType, color: currentColor, width: currentLineWidth)
            canvasView.tool = ink
        }

        #if DEBUG
        print("[PencilKitOverlay] Tool updated: \(currentToolType), color: \(currentColor), width: \(currentLineWidth)")
        #endif
    }

    private func pencilKitInkType(for toolType: InkToolType) -> PKInkingTool.InkType {
        switch toolType {
        case .pen:
            return .pen
        case .pencil:
            return .pencil
        case .highlighter:
            return .marker  // PencilKit 的 marker 对应我们的 highlighter
        case .eraser:
            return .pen  // 不会用到
        }
    }

    // MARK: - Page Management

    /// 更新当前页面索引
    func updateCurrentPage(_ pageIndex: Int) {
        if currentPageIndex != pageIndex {
            // 切换页面时先提交当前页面的笔画
            commitImmediately()
            currentPageIndex = pageIndex
        }
    }

    /// 获取当前页面
    func getCurrentPage() -> PDFPage? {
        guard let document = pdfView?.document else { return nil }
        return document.page(at: currentPageIndex)
    }

    // MARK: - Commit Strokes

    /// 延迟提交（抬笔后触发）
    private func scheduleCommit() {
        // 取消之前的延迟任务
        commitWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.commitStrokes()
        }
        commitWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + commitDelay, execute: workItem)
    }

    /// 立即提交（切换页面、退出批注模式时调用）
    func commitImmediately() {
        commitWorkItem?.cancel()
        commitWorkItem = nil
        commitStrokes()
    }

    /// 提交所有笔画到 PDFAnnotation
    private func commitStrokes() {
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return }

        guard let pdfView = pdfView,
              let page = getCurrentPage(),
              let annotationManager = annotationManager else {
            #if DEBUG
            print("[PencilKitOverlay] Cannot commit: missing pdfView, page, or annotationManager")
            #endif
            return
        }

        #if DEBUG
        print("[PencilKitOverlay] Committing \(drawing.strokes.count) strokes to page \(currentPageIndex + 1)")
        #endif

        // 遍历所有笔画
        for stroke in drawing.strokes {
            // 跳过橡皮擦笔画（橡皮擦由 PencilKit 自动处理）
            if stroke.ink.inkType == .pen || stroke.ink.inkType == .pencil || stroke.ink.inkType == .marker {
                commitSingleStroke(stroke, to: page, pdfView: pdfView, annotationManager: annotationManager)
            }
        }

        // 清空画布
        canvasView.drawing = PKDrawing()
        hasUncommittedStrokes = false

        #if DEBUG
        print("[PencilKitOverlay] Strokes committed and canvas cleared")
        #endif
    }

    /// 提交单个笔画
    private func commitSingleStroke(
        _ stroke: PKStroke,
        to page: PDFPage,
        pdfView: PDFView,
        annotationManager: InkAnnotationManager
    ) {
        // 1. 提取笔画的控制点
        let canvasPoints = extractPoints(from: stroke)
        guard !canvasPoints.isEmpty else { return }

        // 2. 转换坐标: Canvas → PDFPage
        let pagePoints = coordinateConverter.convertToPageCoordinates(
            points: canvasPoints,
            from: canvasView,
            pdfView: pdfView,
            page: page
        )

        guard !pagePoints.isEmpty else {
            #if DEBUG
            print("[PencilKitOverlay] Warning: coordinate conversion resulted in empty points")
            #endif
            return
        }

        // 3. 获取笔画属性
        let strokeColor = stroke.ink.color
        let rawLineWidth = stroke.path.first?.size.width ?? currentLineWidth
        let toolType = inkToolType(from: stroke.ink.inkType)

        // 4. 线宽缩放补偿
        // 原理：PKCanvasView 中的线宽是屏幕像素坐标，需要转换为 PDF 页面坐标
        // 当 scaleFactor = 2.0（放大2倍）时，屏幕上 6pt 的线条在 PDF 中应该是 3pt
        // 这样保证在任何缩放级别下书写，提交后的批注视觉粗细一致
        let scaleFactor = pdfView.scaleFactor
        let adjustedLineWidth = rawLineWidth / scaleFactor

        #if DEBUG
        print("[PencilKitOverlay] LineWidth compensation: raw=\(rawLineWidth), scale=\(scaleFactor), adjusted=\(adjustedLineWidth)")
        #endif

        // 5. 创建 PDFAnnotation.ink（使用补偿后的线宽）
        annotationManager.addInkAnnotationFromPencilKit(
            pagePoints: pagePoints,
            to: page,
            pageIndex: currentPageIndex,
            color: strokeColor,
            lineWidth: adjustedLineWidth,
            toolType: toolType
        )
    }

    /// 从 PKStroke 提取点
    private func extractPoints(from stroke: PKStroke) -> [CGPoint] {
        var points: [CGPoint] = []
        let path = stroke.path

        // PKStrokePath 是一个可迭代的序列
        // 每个点包含 location, timeOffset, size, opacity, force, azimuth, altitude
        for point in path {
            points.append(point.location)
        }

        // 如果点太少，进行插值以获得更平滑的路径
        if points.count < 2 {
            return points
        }

        return points
    }

    /// 从 PKInkType 转换为 InkToolType
    private func inkToolType(from inkType: PKInkingTool.InkType) -> InkToolType {
        switch inkType {
        case .pen:
            return .pen
        case .pencil:
            return .pencil
        case .marker:
            return .highlighter  // PencilKit 的 marker 对应我们的 highlighter
        default:
            return .pen
        }
    }

    // MARK: - Canvas State

    /// 清空画布（不提交）
    func clearCanvas() {
        commitWorkItem?.cancel()
        commitWorkItem = nil
        canvasView.drawing = PKDrawing()
        hasUncommittedStrokes = false
    }

    /// 检查是否有未提交的笔画
    var hasStrokes: Bool {
        !canvasView.drawing.strokes.isEmpty
    }

    // MARK: - Annotation Mode

    /// 进入批注模式
    /// - 显示画布
    /// - 激活 Pencil 响应
    func enterAnnotationMode() {
        canvasView.isHidden = false
        canvasView.becomeFirstResponder()

        #if DEBUG
        print("[PencilKitOverlay] Entered annotation mode - canvas visible, firstResponder active")
        #endif
    }

    /// 退出批注模式
    /// - 提交未完成的笔画
    /// - 隐藏画布
    func exitAnnotationMode() {
        // 先提交未提交的笔画
        commitImmediately()

        canvasView.resignFirstResponder()
        canvasView.isHidden = true

        #if DEBUG
        print("[PencilKitOverlay] Exited annotation mode - canvas hidden")
        #endif
    }
}

// MARK: - PKCanvasViewDelegate

@available(iOS 16.0, *)
extension PencilKitOverlayController: PKCanvasViewDelegate {

    nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        Task { @MainActor in
            let hasStrokes = !canvasView.drawing.strokes.isEmpty
            self.hasUncommittedStrokes = hasStrokes

            if hasStrokes {
                // 有新笔画，安排延迟提交
                self.scheduleCommit()
            }

            #if DEBUG
            print("[PencilKitOverlay] Drawing changed, strokes count: \(canvasView.drawing.strokes.count)")
            #endif
        }
    }

    nonisolated func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        Task { @MainActor in
            // 开始绘制时取消延迟提交
            self.commitWorkItem?.cancel()

            #if DEBUG
            print("[PencilKitOverlay] Begin using tool")
            #endif
        }
    }

    nonisolated func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        Task { @MainActor in
            // 结束绘制时安排提交
            if !canvasView.drawing.strokes.isEmpty {
                self.scheduleCommit()
            }

            #if DEBUG
            print("[PencilKitOverlay] End using tool")
            #endif
        }
    }
}

// MARK: - Annotation Coordinate Converter

@available(iOS 16.0, *)
final class AnnotationCoordinateConverter {

    /// 将 PKCanvasView 坐标转换为 PDFPage 坐标
    func convertToPageCoordinates(
        points: [CGPoint],
        from canvasView: PKCanvasView,
        pdfView: PDFView,
        page: PDFPage
    ) -> [CGPoint] {

        return points.compactMap { canvasPoint in
            // 1. Canvas 坐标 → PDFView 坐标
            let pdfViewPoint = canvasView.convert(canvasPoint, to: pdfView)

            // 2. PDFView 坐标 → PDFPage 坐标
            // PDFKit 的 convert 方法自动处理：
            // - 缩放因子
            // - 滚动偏移
            // - Y 轴翻转（UIKit 向下为正 → PDF 向上为正）
            let pagePoint = pdfView.convert(pdfViewPoint, to: page)

            return pagePoint
        }
    }

    /// 计算路径的边界框（在 PDF 页面坐标系中）
    func calculateBounds(for points: [CGPoint], lineWidth: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return .zero
        }

        let padding = lineWidth / 2 + 2  // 额外边距确保笔画不被裁剪

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }

    /// 将绝对坐标转换为 bounds 内的局部坐标
    func convertToLocalCoordinates(points: [CGPoint], bounds: CGRect) -> [CGPoint] {
        return points.map { point in
            CGPoint(
                x: point.x - bounds.origin.x,
                y: point.y - bounds.origin.y
            )
        }
    }
}

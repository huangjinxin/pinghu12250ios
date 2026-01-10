//
//  InkAnnotationManager.swift
//  pinghu12250
//
//  Ink 批注管理器 - 负责 PDFAnnotation.ink 的生命周期
//
//  架构说明（PencilKit 版本）：
//  - 输入采集：PencilKitOverlayController 使用 PKCanvasView
//  - 坐标转换：AnnotationCoordinateConverter 处理 Canvas → PDFPage
//  - 本类职责：创建/管理 PDFAnnotation、undo/redo、XFDF 存储
//

import Foundation
import PDFKit
import UIKit
import Combine

// MARK: - Annotation Action for Undo/Redo

enum InkAnnotationAction {
    case add
    case remove
}

struct InkAnnotationRecord {
    let action: InkAnnotationAction
    let annotation: PDFAnnotation
    let pageIndex: Int
}

// MARK: - Ink Annotation Manager

@MainActor
final class InkAnnotationManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var annotationCounts: [Int: Int] = [:]  // pageIndex: count
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    // MARK: - Dependencies

    private let xfdfService = XFDFAnnotationService.shared
    private weak var pdfDocument: PDFDocument?
    private weak var pdfView: PDFView?

    private var userId: String = ""
    private var textbookId: String = ""

    // MARK: - Undo/Redo Stacks

    private var undoStack: [InkAnnotationRecord] = []
    private var redoStack: [InkAnnotationRecord] = []
    private let maxUndoSteps = 20

    // 跟踪本会话中添加的批注（解决 PDFKit 自定义 key 延迟读取问题）
    private var sessionAnnotations: Set<ObjectIdentifier> = []

    // MARK: - Init

    init() {}

    // MARK: - Setup

    func setup(
        document: PDFDocument,
        pdfView: PDFView?,
        userId: String,
        textbookId: String
    ) {
        self.pdfDocument = document
        self.pdfView = pdfView
        self.userId = userId
        self.textbookId = textbookId

        // 清空撤销栈
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()

        // 清空会话跟踪（重要：避免旧引用影响新会话）
        sessionAnnotations.removeAll()

        // 更新计数
        updateAllAnnotationCounts()
    }

    /// 更新 PDFView 引用（在视图创建后调用）
    func updatePDFView(_ pdfView: PDFView?) {
        self.pdfView = pdfView
    }

    // MARK: - Add Annotation (PencilKit 版本 - 推荐)

    /// 从 PencilKit 笔画创建 PDFAnnotation.ink
    /// - Parameters:
    ///   - pagePoints: 已转换为 PDF 页面坐标系的点（绝对坐标）
    ///   - page: 目标 PDFPage
    ///   - pageIndex: 页面索引
    ///   - color: 笔画颜色
    ///   - lineWidth: 线宽
    ///   - toolType: 工具类型
    @discardableResult
    func addInkAnnotationFromPencilKit(
        pagePoints: [CGPoint],
        to page: PDFPage,
        pageIndex: Int,
        color: UIColor,
        lineWidth: CGFloat,
        toolType: InkToolType
    ) -> PDFAnnotation? {
        guard pagePoints.count >= 2 else {
            #if DEBUG
            print("[InkAnnotationManager] Skipping annotation with less than 2 points")
            #endif
            return nil
        }

        // 1. 计算边界框（在 PDF 页面坐标系中）
        let bounds = calculateBounds(for: pagePoints, lineWidth: lineWidth)
        guard bounds.width > 0 && bounds.height > 0 else {
            #if DEBUG
            print("[InkAnnotationManager] Skipping annotation with zero bounds")
            #endif
            return nil
        }

        // 2. 创建 PDFAnnotation.ink
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)

        // 3. 设置颜色和透明度
        let alpha = toolType.defaultAlpha
        annotation.color = color.withAlphaComponent(alpha)

        // 4. 设置线宽
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border

        // 5. 创建路径（使用 bounds 内的局部坐标）
        // 【关键】PDFAnnotation.ink 的路径点必须是相对于 bounds.origin 的局部坐标
        let localPoints = pagePoints.map { point in
            CGPoint(
                x: point.x - bounds.origin.x,
                y: point.y - bounds.origin.y
            )
        }

        let path = UIBezierPath()
        path.move(to: localPoints[0])
        for point in localPoints.dropFirst() {
            path.addLine(to: point)
        }
        annotation.add(path)

        // 6. 设置元数据（用于识别和导出）
        let annotationId = UUID().uuidString
        let now = Date()
        annotation.setValue(annotationId, forAnnotationKey: .name)
        annotation.setValue(XFDFAnnotationService.appIdentifier, forAnnotationKey: PDFAnnotationKey(rawValue: "title"))
        annotation.setValue(toolType.rawValue, forAnnotationKey: PDFAnnotationKey(rawValue: "toolType"))
        annotation.setValue(now, forAnnotationKey: PDFAnnotationKey(rawValue: "createdAt"))
        annotation.setValue(now, forAnnotationKey: PDFAnnotationKey(rawValue: "modifiedAt"))

        // 7. 添加到页面
        // 【重要】使用 PencilKit 后，PKCanvasView 清空时 PDFKit 自动渲染批注
        // 不再需要强制刷新 hack
        page.addAnnotation(annotation)

        // 8. 跟踪本会话添加的批注
        sessionAnnotations.insert(ObjectIdentifier(annotation))

        // 9. 记录撤销
        pushUndo(action: .add, annotation: annotation, pageIndex: pageIndex)

        // 10. 更新状态
        hasUnsavedChanges = true
        updateAnnotationCount(for: pageIndex)

        #if DEBUG
        let inkCount = page.annotations.filter { $0.type == "Ink" }.count
        print("[InkAnnotationManager] Added PencilKit annotation: \(annotationId), page \(pageIndex + 1), points: \(pagePoints.count), total ink: \(inkCount)")
        #endif

        return annotation
    }

    /// 计算路径的边界框
    private func calculateBounds(for points: [CGPoint], lineWidth: CGFloat) -> CGRect {
        guard !points.isEmpty else { return .zero }

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

    // MARK: - Add Annotation (旧版本 - 保留兼容)

    /// 添加 ink 批注到页面（旧接口，用于 XFDF 回放）
    @discardableResult
    func addInkAnnotation(
        points: [CGPoint],
        to page: PDFPage,
        pageIndex: Int,
        color: UIColor,
        lineWidth: CGFloat,
        toolType: InkToolType
    ) -> PDFAnnotation? {
        guard !points.isEmpty else { return nil }

        // 1. 计算边界
        let bounds = xfdfService.calculateBounds(for: points, lineWidth: lineWidth)

        // 2. 创建 PDFAnnotation.ink
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)

        // 3. 设置颜色和透明度
        let alpha = toolType.defaultAlpha
        annotation.color = color.withAlphaComponent(alpha)

        // 4. 设置线宽
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border

        // 5. 创建路径
        let path = UIBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        annotation.add(path)

        // 6. 设置元数据（用于识别和导出）
        let annotationId = UUID().uuidString
        let now = Date()
        annotation.setValue(annotationId, forAnnotationKey: .name)
        annotation.setValue(XFDFAnnotationService.appIdentifier, forAnnotationKey: PDFAnnotationKey(rawValue: "title"))
        annotation.setValue(toolType.rawValue, forAnnotationKey: PDFAnnotationKey(rawValue: "toolType"))
        annotation.setValue(now, forAnnotationKey: PDFAnnotationKey(rawValue: "createdAt"))
        annotation.setValue(now, forAnnotationKey: PDFAnnotationKey(rawValue: "modifiedAt"))

        // 7. 添加到页面
        page.addAnnotation(annotation)

        // 8. 跟踪本会话添加的批注
        sessionAnnotations.insert(ObjectIdentifier(annotation))

        // 9. 记录撤销
        pushUndo(action: .add, annotation: annotation, pageIndex: pageIndex)

        // 10. 更新状态
        hasUnsavedChanges = true
        updateAnnotationCount(for: pageIndex)

        #if DEBUG
        print("[InkAnnotationManager] Added annotation: \(annotationId), page \(pageIndex + 1), points: \(points.count)")
        #endif

        return annotation
    }

    // MARK: - Remove Annotation

    /// 移除批注
    func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage, pageIndex: Int) {
        page.removeAnnotation(annotation)

        // 从会话跟踪中移除
        sessionAnnotations.remove(ObjectIdentifier(annotation))

        // 记录撤销
        pushUndo(action: .remove, annotation: annotation, pageIndex: pageIndex)

        // 更新状态
        hasUnsavedChanges = true
        updateAnnotationCount(for: pageIndex)

        #if DEBUG
        let annotationId = annotation.value(forAnnotationKey: .name) as? String ?? "unknown"
        print("[InkAnnotationManager] Removed annotation: \(annotationId), page \(pageIndex + 1)")
        #endif
    }

    // MARK: - Eraser (手动碰撞检测 - 保留用于非 PencilKit 场景)

    /// 橡皮擦：查找并移除命中的批注
    func eraseAtPoint(
        _ point: CGPoint,
        on page: PDFPage,
        pageIndex: Int,
        radius: CGFloat
    ) -> Bool {
        let appAnnotations = getAppAnnotations(from: page)

        for annotation in appAnnotations {
            if isPointNearAnnotation(point, annotation: annotation, radius: radius) {
                removeAnnotation(annotation, from: page, pageIndex: pageIndex)
                return true  // 一次只擦除一个
            }
        }

        return false
    }

    /// 检查点是否在批注路径附近
    private func isPointNearAnnotation(_ point: CGPoint, annotation: PDFAnnotation, radius: CGFloat) -> Bool {
        // 首先检查边界框
        let expandedBounds = annotation.bounds.insetBy(dx: -radius, dy: -radius)
        guard expandedBounds.contains(point) else {
            return false
        }

        // 检查路径
        guard let paths = annotation.paths else {
            // 如果没有路径，只检查边界框
            return true
        }

        for path in paths {
            let points = extractPoints(from: path)
            for i in 0..<points.count {
                // 检查点到点的距离
                let pathPoint = points[i]
                let distance = hypot(point.x - pathPoint.x, point.y - pathPoint.y)
                if distance <= radius {
                    return true
                }

                // 检查点到线段的距离（如果有下一个点）
                if i < points.count - 1 {
                    let nextPoint = points[i + 1]
                    let distanceToSegment = distanceFromPointToLineSegment(
                        point: point,
                        lineStart: pathPoint,
                        lineEnd: nextPoint
                    )
                    if distanceToSegment <= radius {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// 计算点到线段的距离
    private func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        if dx == 0 && dy == 0 {
            // 线段退化为点
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)))

        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy

        return hypot(point.x - projectionX, point.y - projectionY)
    }

    /// 从 UIBezierPath 提取点
    private func extractPoints(from path: UIBezierPath) -> [CGPoint] {
        var points: [CGPoint] = []

        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        return points
    }

    // MARK: - Undo/Redo

    private func pushUndo(action: InkAnnotationAction, annotation: PDFAnnotation, pageIndex: Int) {
        let record = InkAnnotationRecord(action: action, annotation: annotation, pageIndex: pageIndex)
        undoStack.append(record)

        // 限制栈大小
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }

        // 新操作清空重做栈
        redoStack.removeAll()

        updateUndoRedoState()
    }

    func undo() {
        guard let document = pdfDocument,
              let record = undoStack.popLast(),
              let page = document.page(at: record.pageIndex) else {
            return
        }

        switch record.action {
        case .add:
            // 撤销添加 = 移除
            page.removeAnnotation(record.annotation)
            sessionAnnotations.remove(ObjectIdentifier(record.annotation))
            redoStack.append(InkAnnotationRecord(action: .add, annotation: record.annotation, pageIndex: record.pageIndex))

        case .remove:
            // 撤销移除 = 添加回来
            page.addAnnotation(record.annotation)
            sessionAnnotations.insert(ObjectIdentifier(record.annotation))
            redoStack.append(InkAnnotationRecord(action: .remove, annotation: record.annotation, pageIndex: record.pageIndex))
        }

        hasUnsavedChanges = true
        updateAnnotationCount(for: record.pageIndex)
        updateUndoRedoState()

        #if DEBUG
        print("[InkAnnotationManager] Undo: \(record.action), page \(record.pageIndex + 1)")
        #endif
    }

    func redo() {
        guard let document = pdfDocument,
              let record = redoStack.popLast(),
              let page = document.page(at: record.pageIndex) else {
            return
        }

        switch record.action {
        case .add:
            // 重做添加 = 添加
            page.addAnnotation(record.annotation)
            sessionAnnotations.insert(ObjectIdentifier(record.annotation))
            undoStack.append(InkAnnotationRecord(action: .add, annotation: record.annotation, pageIndex: record.pageIndex))

        case .remove:
            // 重做移除 = 移除
            page.removeAnnotation(record.annotation)
            sessionAnnotations.remove(ObjectIdentifier(record.annotation))
            undoStack.append(InkAnnotationRecord(action: .remove, annotation: record.annotation, pageIndex: record.pageIndex))
        }

        hasUnsavedChanges = true
        updateAnnotationCount(for: record.pageIndex)
        updateUndoRedoState()

        #if DEBUG
        print("[InkAnnotationManager] Redo: \(record.action), page \(record.pageIndex + 1)")
        #endif
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - Clear Page Annotations

    /// 清除指定页面的所有本 App 批注
    func clearPageAnnotations(pageIndex: Int) {
        guard let document = pdfDocument,
              let page = document.page(at: pageIndex) else {
            return
        }

        let appAnnotations = getAppAnnotations(from: page)

        for annotation in appAnnotations {
            page.removeAnnotation(annotation)
            sessionAnnotations.remove(ObjectIdentifier(annotation))
            pushUndo(action: .remove, annotation: annotation, pageIndex: pageIndex)
        }

        hasUnsavedChanges = true
        updateAnnotationCount(for: pageIndex)

        #if DEBUG
        print("[InkAnnotationManager] Cleared \(appAnnotations.count) annotations on page \(pageIndex + 1)")
        #endif
    }

    // MARK: - Query

    /// 获取页面上本 App 的批注
    func getAppAnnotations(from page: PDFPage) -> [PDFAnnotation] {
        page.annotations.filter { annotation in
            guard annotation.type == "Ink" else { return false }

            // 优先检查会话跟踪（解决 PDFKit 自定义 key 延迟读取问题）
            if sessionAnnotations.contains(ObjectIdentifier(annotation)) {
                return true
            }

            // 再检查 XFDF 服务标识
            return xfdfService.isAppAnnotation(annotation)
        }
    }

    /// 获取指定页面的批注数量
    func getAnnotationCount(for pageIndex: Int) -> Int {
        guard let document = pdfDocument,
              let page = document.page(at: pageIndex) else {
            return 0
        }
        return getAppAnnotations(from: page).count
    }

    /// 获取所有有批注的页码
    func getAnnotatedPageIndices() -> [Int] {
        guard let document = pdfDocument else { return [] }

        var indices: [Int] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                if !getAppAnnotations(from: page).isEmpty {
                    indices.append(i)
                }
            }
        }
        return indices
    }

    // MARK: - Save/Load

    /// 保存到 XFDF
    func saveToXFDF() {
        guard let document = pdfDocument,
              !userId.isEmpty,
              !textbookId.isEmpty else {
            #if DEBUG
            print("[InkAnnotationManager] Cannot save: missing document or identifiers")
            #endif
            return
        }

        let xfdf = xfdfService.generateXFDF(
            from: document,
            pdfFilename: "\(textbookId).pdf",
            filterAppAnnotations: true
        )

        do {
            try xfdfService.saveXFDF(xfdf, userId: userId, textbookId: textbookId)
            hasUnsavedChanges = false

            #if DEBUG
            print("[InkAnnotationManager] Saved XFDF for textbook: \(textbookId)")
            #endif
        } catch {
            #if DEBUG
            print("[InkAnnotationManager] Failed to save XFDF: \(error)")
            #endif
        }
    }

    /// 从 XFDF 加载
    func loadFromXFDF() {
        guard let document = pdfDocument,
              !userId.isEmpty,
              !textbookId.isEmpty else {
            return
        }

        guard let xfdfContent = xfdfService.loadXFDF(userId: userId, textbookId: textbookId) else {
            #if DEBUG
            print("[InkAnnotationManager] No XFDF file found for textbook: \(textbookId)")
            #endif
            return
        }

        // 先清除现有的 App 批注
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let existing = getAppAnnotations(from: page)
                for annotation in existing {
                    page.removeAnnotation(annotation)
                }
            }
        }

        // 清空会话跟踪
        sessionAnnotations.removeAll()

        // 解析并应用 XFDF
        let parsedAnnotations = xfdfService.parseXFDF(xfdfContent)
        xfdfService.applyAnnotations(parsedAnnotations, to: document)

        // 更新计数
        updateAllAnnotationCounts()

        // 重置撤销栈
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()

        hasUnsavedChanges = false

        #if DEBUG
        print("[InkAnnotationManager] Loaded \(parsedAnnotations.count) annotations from XFDF")
        #endif
    }

    /// 获取 XFDF 内容用于同步
    func getXFDFContent() -> String? {
        guard let document = pdfDocument else { return nil }

        return xfdfService.generateXFDF(
            from: document,
            pdfFilename: "\(textbookId).pdf",
            filterAppAnnotations: true
        )
    }

    // MARK: - Annotation Count Updates

    private func updateAnnotationCount(for pageIndex: Int) {
        annotationCounts[pageIndex] = getAnnotationCount(for: pageIndex)
    }

    private func updateAllAnnotationCounts() {
        guard let document = pdfDocument else { return }

        annotationCounts.removeAll()
        for i in 0..<document.pageCount {
            let count = getAnnotationCount(for: i)
            if count > 0 {
                annotationCounts[i] = count
            }
        }
    }
}

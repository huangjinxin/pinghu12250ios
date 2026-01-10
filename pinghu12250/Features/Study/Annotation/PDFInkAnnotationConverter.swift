//
//  PDFInkAnnotationConverter.swift
//  pinghu12250
//
//  PKDrawing -> PDFAnnotation (ink) 转换器
//  将 PencilKit 笔画转换为 PDFKit 原生批注
//
//  坐标转换原则：
//  - Canvas 坐标系：原点左上，Y 向下
//  - PDF 坐标系：原点左下，Y 向上（使用 mediaBox）
//  - canvasBounds 参数是 canvas 在 PDFView 中的 frame（已缩放）
//  - 转换时需要考虑缩放比例
//

import Foundation
import PDFKit
import PencilKit
import UIKit

/// PDF Ink 批注转换器
/// 负责 PKDrawing <-> PDFAnnotation 的双向转换
@available(iOS 16.0, *)
final class PDFInkAnnotationConverter {

    // MARK: - 单例

    static let shared = PDFInkAnnotationConverter()
    private init() {}

    // MARK: - 批注标识

    /// 自定义批注 key，用于标识由本应用创建的批注
    static let annotationKey = "com.pinghu12250.inkAnnotation"
    static let pageIndexKey = "com.pinghu12250.pageIndex"
    static let createdAtKey = "com.pinghu12250.createdAt"

    // MARK: - PKDrawing -> PDFAnnotation

    /// 将 PKDrawing 的所有笔画转换为 PDFAnnotation 并添加到页面
    /// - Parameters:
    ///   - drawing: PencilKit 绘图
    ///   - page: 目标 PDF 页面
    ///   - pageIndex: 页面索引（用于笔记跳转）
    ///   - canvasBounds: PKCanvasView 在 PDFView 中的 frame（已缩放后的尺寸）
    /// - Returns: 添加的批注数组
    ///
    /// 坐标转换说明：
    /// 1. Canvas 坐标系：(0,0) 在左上角，Y 向下
    /// 2. PDF 坐标系：(0,0) 在左下角，Y 向上
    /// 3. canvasBounds.size 是缩放后的 canvas 尺寸
    /// 4. pageRect.size 是 PDF 页面的原始尺寸（mediaBox）
    @discardableResult
    func convertAndAddAnnotations(
        from drawing: PKDrawing,
        to page: PDFPage,
        pageIndex: Int,
        canvasBounds: CGRect
    ) -> [PDFAnnotation] {
        let strokes = drawing.strokes
        guard !strokes.isEmpty else { return [] }

        let pageRect = page.bounds(for: .mediaBox)
        var annotations: [PDFAnnotation] = []

        #if DEBUG
        print("[InkConverter] 开始转换 \(strokes.count) 个笔画")
        print("[InkConverter] Canvas bounds: \(canvasBounds), Page rect: \(pageRect)")
        #endif

        for stroke in strokes {
            if let annotation = createInkAnnotation(
                from: stroke,
                pageRect: pageRect,
                canvasBounds: canvasBounds,
                pageIndex: pageIndex
            ) {
                page.addAnnotation(annotation)
                annotations.append(annotation)
            }
        }

        return annotations
    }

    /// 将单个 PKStroke 转换为 PDFAnnotation (ink)
    /// 坐标转换是核心逻辑，确保批注与 PDF 页面精确对齐
    private func createInkAnnotation(
        from stroke: PKStroke,
        pageRect: CGRect,
        canvasBounds: CGRect,
        pageIndex: Int
    ) -> PDFAnnotation? {
        // 获取笔画路径
        let path = stroke.path
        guard path.count > 0 else { return nil }

        // 计算缩放比例
        // canvasBounds 是 canvas 在屏幕上的实际尺寸（已缩放）
        // pageRect 是 PDF 页面的原始尺寸
        // 需要将 canvas 坐标转换为 PDF 坐标
        let scaleX = pageRect.width / canvasBounds.width
        let scaleY = pageRect.height / canvasBounds.height

        #if DEBUG
        // print("[InkConverter] Scale: (\(scaleX), \(scaleY))")
        #endif

        // 提取路径点并转换坐标
        var pdfPoints: [[CGPoint]] = []
        var currentPath: [CGPoint] = []

        for i in 0..<path.count {
            let point = path[i]

            // 转换坐标：Canvas 坐标 -> PDF 坐标
            // 1. 缩放 X 坐标
            let pdfX = point.location.x * scaleX

            // 2. 缩放并翻转 Y 坐标（PDF Y 轴向上）
            let pdfY = pageRect.height - (point.location.y * scaleY)

            currentPath.append(CGPoint(x: pdfX, y: pdfY))
        }

        if !currentPath.isEmpty {
            pdfPoints.append(currentPath)
        }

        guard !pdfPoints.isEmpty else { return nil }

        // 计算批注边界
        let allPoints = pdfPoints.flatMap { $0 }
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 0
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 0

        // 根据笔画类型设置线宽
        let lineWidth: CGFloat
        switch stroke.ink.inkType {
        case .marker:
            lineWidth = 8.0 * scaleX  // 荧光笔更粗
        case .pencil:
            lineWidth = 2.0 * scaleX  // 铅笔较细
        default:
            lineWidth = 3.0 * scaleX  // 钢笔默认宽度
        }

        // 扩展边界以容纳线宽
        let padding = lineWidth * 2
        let annotationBounds = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + padding * 2,
            height: (maxY - minY) + padding * 2
        )

        // 创建 ink 批注
        let annotation = PDFAnnotation(bounds: annotationBounds, forType: .ink, withProperties: nil)

        // 设置颜色
        let inkColor = stroke.ink.color
        annotation.color = inkColor.withAlphaComponent(inkColor.cgColor.alpha)

        // 设置线宽（使用缩放后的值，确保在 PDF 中显示一致）
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = lineWidth

        // 添加路径
        for pathPoints in pdfPoints {
            // 创建 UIBezierPath
            let bezierPath = UIBezierPath()
            if let first = pathPoints.first {
                bezierPath.move(to: first)
                for point in pathPoints.dropFirst() {
                    bezierPath.addLine(to: point)
                }
            }
            annotation.add(bezierPath)
        }

        // 添加自定义属性用于标识和管理
        annotation.setValue(Self.annotationKey, forAnnotationKey: .name)
        annotation.setValue(pageIndex, forAnnotationKey: PDFAnnotationKey(rawValue: Self.pageIndexKey))
        annotation.setValue(Date().timeIntervalSince1970, forAnnotationKey: PDFAnnotationKey(rawValue: Self.createdAtKey))

        return annotation
    }

    // MARK: - 获取页面批注

    /// 获取页面上由本应用创建的所有 ink 批注
    func getAppAnnotations(from page: PDFPage) -> [PDFAnnotation] {
        return page.annotations.filter { annotation in
            annotation.type == "Ink" &&
            annotation.value(forAnnotationKey: .name) as? String == Self.annotationKey
        }
    }

    /// 清除页面上由本应用创建的所有批注
    func clearAppAnnotations(from page: PDFPage) {
        let appAnnotations = getAppAnnotations(from: page)
        for annotation in appAnnotations {
            page.removeAnnotation(annotation)
        }
    }

    /// 检查页面是否有本应用创建的批注
    func hasAppAnnotations(on page: PDFPage) -> Bool {
        return !getAppAnnotations(from: page).isEmpty
    }

    // MARK: - 批注导出

    /// 将页面批注导出为图片（用于笔记缩略图）
    func exportAnnotationsAsImage(from page: PDFPage, scale: CGFloat = 1.0) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scaledRect = CGRect(
            x: 0,
            y: 0,
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: scaledRect.size)
        return renderer.image { context in
            // 白色背景
            UIColor.white.setFill()
            context.fill(scaledRect)

            // 绘制 PDF 页面
            context.cgContext.translateBy(x: 0, y: scaledRect.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

// MARK: - PDFAnnotation 扩展

extension PDFAnnotation {
    /// 是否为本应用创建的批注
    var isAppAnnotation: Bool {
        return value(forAnnotationKey: .name) as? String == PDFInkAnnotationConverter.annotationKey
    }

    /// 获取批注创建时的页码索引
    var appPageIndex: Int? {
        return value(forAnnotationKey: PDFAnnotationKey(rawValue: PDFInkAnnotationConverter.pageIndexKey)) as? Int
    }

    /// 获取批注创建时间
    var appCreatedAt: Date? {
        guard let timestamp = value(forAnnotationKey: PDFAnnotationKey(rawValue: PDFInkAnnotationConverter.createdAtKey)) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

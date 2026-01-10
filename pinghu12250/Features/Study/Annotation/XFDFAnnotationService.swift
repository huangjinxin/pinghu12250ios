//
//  XFDFAnnotationService.swift
//  pinghu12250
//
//  XFDF 批注服务 - Adobe/Apple 标准格式读写
//  支持多用户独立存储和跨设备同步
//

import Foundation
import PDFKit
import UIKit

// MARK: - XFDF 解析结果

struct XFDFParsedAnnotation {
    let id: String
    let pageIndex: Int
    let paths: [[CGPoint]]
    let color: UIColor
    let lineWidth: CGFloat
    let opacity: CGFloat
    let createdAt: Date
    let modifiedAt: Date
    let toolType: String  // pen, pencil, highlighter
}

// MARK: - XFDF Annotation Service

final class XFDFAnnotationService {

    static let shared = XFDFAnnotationService()

    private let fileManager = FileManager.default

    // App 标识，用于过滤自己创建的批注
    static let appIdentifier = "com.pinghu12250.annotation"

    private init() {}

    // MARK: - File Paths

    private var annotationsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("annotations", isDirectory: true)
    }

    func userDirectory(userId: String) -> URL {
        annotationsDirectory.appendingPathComponent(userId, isDirectory: true)
    }

    func xfdfURL(userId: String, textbookId: String) -> URL {
        userDirectory(userId: userId).appendingPathComponent("\(textbookId).xfdf")
    }

    // MARK: - Generate XFDF

    /// 从 PDFDocument 中的批注生成 XFDF 字符串
    func generateXFDF(
        from document: PDFDocument,
        pdfFilename: String,
        filterAppAnnotations: Bool = true
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
          <pdf-info href="\(escapeXML(pdfFilename))"/>
          <annots>

        """

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            let annotations = page.annotations.filter { annotation in
                guard annotation.type == "Ink" else { return false }
                if filterAppAnnotations {
                    return isAppAnnotation(annotation)
                }
                return true
            }

            for annotation in annotations {
                xml += generateInkAnnotationXML(annotation, pageIndex: pageIndex)
            }
        }

        xml += """
          </annots>
        </xfdf>
        """

        return xml
    }

    /// 生成单个 ink 批注的 XFDF XML
    private func generateInkAnnotationXML(_ annotation: PDFAnnotation, pageIndex: Int) -> String {
        let bounds = annotation.bounds
        let annotationColor = annotation.color
        let color = colorToHex(annotationColor)
        let lineWidth = annotation.border?.lineWidth ?? 2.0
        let opacity = annotationColor.cgColor.alpha

        // 获取批注 ID
        let annotationId = annotation.value(forAnnotationKey: .name) as? String ?? UUID().uuidString

        // 获取工具类型
        let toolType = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "toolType")) as? String ?? "pen"

        // 获取创建/修改时间
        let createdAt = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "createdAt")) as? Date ?? Date()
        let modifiedAt = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "modifiedAt")) as? Date ?? Date()

        let dateFormatter = ISO8601DateFormatter()

        var xml = """
            <ink
              page="\(pageIndex)"
              rect="\(bounds.origin.x),\(bounds.origin.y),\(bounds.maxX),\(bounds.maxY)"
              color="\(color)"
              width="\(lineWidth)"
              opacity="\(opacity)"
              name="\(escapeXML(annotationId))"
              creationdate="\(dateFormatter.string(from: createdAt))"
              date="\(dateFormatter.string(from: modifiedAt))"
              subject="\(toolType)"
              title="\(XFDFAnnotationService.appIdentifier)">
              <inklist>

        """

        // 获取路径数据
        let paths = extractPaths(from: annotation)
        for path in paths {
            let gestureString = path.map { "\($0.x),\($0.y)" }.joined(separator: ";")
            xml += "        <gesture>\(gestureString)</gesture>\n"
        }

        xml += """
              </inklist>
            </ink>

        """

        return xml
    }

    /// 从 PDFAnnotation 提取路径点
    private func extractPaths(from annotation: PDFAnnotation) -> [[CGPoint]] {
        var paths: [[CGPoint]] = []

        // PDFAnnotation.paths 返回 UIBezierPath 数组
        if let annotationPaths = annotation.paths {
            for path in annotationPaths {
                let points = extractPoints(from: path)
                if !points.isEmpty {
                    paths.append(points)
                }
            }
        }

        return paths
    }

    /// 从 UIBezierPath 提取点
    private func extractPoints(from path: UIBezierPath) -> [CGPoint] {
        var points: [CGPoint] = []

        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        return points
    }

    // MARK: - Parse XFDF

    /// 解析 XFDF 字符串，返回批注数据
    func parseXFDF(_ content: String) -> [XFDFParsedAnnotation] {
        let parser = XFDFParser()
        return parser.parse(content)
    }

    /// 将解析的批注应用到 PDFDocument
    func applyAnnotations(
        _ parsedAnnotations: [XFDFParsedAnnotation],
        to document: PDFDocument
    ) {
        for parsed in parsedAnnotations {
            guard parsed.pageIndex < document.pageCount,
                  let page = document.page(at: parsed.pageIndex) else {
                continue
            }

            // 创建 PDFAnnotation
            let annotation = createInkAnnotation(from: parsed)
            page.addAnnotation(annotation)
        }
    }

    /// 从解析数据创建 PDFAnnotation.ink
    func createInkAnnotation(from parsed: XFDFParsedAnnotation) -> PDFAnnotation {
        // 计算边界
        var allPoints: [CGPoint] = []
        for path in parsed.paths {
            allPoints.append(contentsOf: path)
        }
        let bounds = calculateBounds(for: allPoints, lineWidth: parsed.lineWidth)

        // 创建批注
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = parsed.color.withAlphaComponent(parsed.opacity)

        let border = PDFBorder()
        border.lineWidth = parsed.lineWidth
        annotation.border = border

        // 添加路径
        for pathPoints in parsed.paths {
            guard !pathPoints.isEmpty else { continue }

            let path = UIBezierPath()
            path.move(to: pathPoints[0])
            for point in pathPoints.dropFirst() {
                path.addLine(to: point)
            }
            annotation.add(path)
        }

        // 设置元数据
        annotation.setValue(parsed.id, forAnnotationKey: .name)
        annotation.setValue(XFDFAnnotationService.appIdentifier, forAnnotationKey: PDFAnnotationKey(rawValue: "title"))
        annotation.setValue(parsed.toolType, forAnnotationKey: PDFAnnotationKey(rawValue: "toolType"))
        annotation.setValue(parsed.createdAt, forAnnotationKey: PDFAnnotationKey(rawValue: "createdAt"))
        annotation.setValue(parsed.modifiedAt, forAnnotationKey: PDFAnnotationKey(rawValue: "modifiedAt"))

        return annotation
    }

    // MARK: - File Operations

    /// 保存 XFDF 到文件
    func saveXFDF(_ content: String, userId: String, textbookId: String) throws {
        let directory = userDirectory(userId: userId)

        // 确保目录存在
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let url = xfdfURL(userId: userId, textbookId: textbookId)
        try content.write(to: url, atomically: true, encoding: .utf8)

        #if DEBUG
        print("[XFDFService] Saved XFDF to: \(url.path)")
        #endif
    }

    /// 加载 XFDF 文件
    func loadXFDF(userId: String, textbookId: String) -> String? {
        let url = xfdfURL(userId: userId, textbookId: textbookId)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 检查 XFDF 文件是否存在
    func xfdfExists(userId: String, textbookId: String) -> Bool {
        let url = xfdfURL(userId: userId, textbookId: textbookId)
        return fileManager.fileExists(atPath: url.path)
    }

    /// 删除 XFDF 文件
    func deleteXFDF(userId: String, textbookId: String) throws {
        let url = xfdfURL(userId: userId, textbookId: textbookId)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// 列出用户的所有 XFDF 文件
    func listXFDFFiles(userId: String) -> [String] {
        let directory = userDirectory(userId: userId)

        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return contents
            .filter { $0.hasSuffix(".xfdf") }
            .map { String($0.dropLast(5)) }  // 移除 .xfdf 后缀
    }

    // MARK: - Helper Methods

    /// 检查是否为本 App 创建的批注
    func isAppAnnotation(_ annotation: PDFAnnotation) -> Bool {
        // 检查 title 标识（主要方式）
        if let title = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "title")) as? String,
           title == XFDFAnnotationService.appIdentifier {
            return true
        }

        // 备选检查：如果有 toolType 标识，也认为是本 App 创建的批注
        // 这解决了刚添加的批注可能无法立即读取 title 的问题
        if let toolType = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "toolType")) as? String,
           !toolType.isEmpty {
            return true
        }

        return false
    }

    /// 计算点集的边界框
    func calculateBounds(for points: [CGPoint], lineWidth: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return .zero
        }

        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        // 扩展边界以包含线宽
        let padding = lineWidth / 2 + 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }

    /// UIColor 转 Hex 字符串
    private func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// Hex 字符串转 UIColor
    func hexToColor(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        return UIColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    /// XML 转义
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - XFDF Parser

private class XFDFParser: NSObject, XMLParserDelegate {

    private var annotations: [XFDFParsedAnnotation] = []
    private var currentAnnotation: PartialAnnotation?
    private var currentGesture: String = ""
    private var isInGesture = false

    private struct PartialAnnotation {
        var id: String = UUID().uuidString
        var pageIndex: Int = 0
        var paths: [[CGPoint]] = []
        var color: UIColor = .black
        var lineWidth: CGFloat = 2.0
        var opacity: CGFloat = 1.0
        var createdAt: Date = Date()
        var modifiedAt: Date = Date()
        var toolType: String = "pen"
    }

    func parse(_ content: String) -> [XFDFParsedAnnotation] {
        annotations = []

        guard let data = content.data(using: .utf8) else {
            return []
        }

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return annotations
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName.lowercased() {
        case "ink":
            var partial = PartialAnnotation()

            if let pageStr = attributeDict["page"], let page = Int(pageStr) {
                partial.pageIndex = page
            }

            if let colorStr = attributeDict["color"] {
                partial.color = XFDFAnnotationService.shared.hexToColor(colorStr)
            }

            if let widthStr = attributeDict["width"], let width = Double(widthStr) {
                partial.lineWidth = CGFloat(width)
            }

            if let opacityStr = attributeDict["opacity"], let opacity = Double(opacityStr) {
                partial.opacity = CGFloat(opacity)
            }

            if let name = attributeDict["name"] {
                partial.id = name
            }

            if let subject = attributeDict["subject"] {
                partial.toolType = subject
            }

            let dateFormatter = ISO8601DateFormatter()

            if let creationDate = attributeDict["creationdate"],
               let date = dateFormatter.date(from: creationDate) {
                partial.createdAt = date
            }

            if let modDate = attributeDict["date"],
               let date = dateFormatter.date(from: modDate) {
                partial.modifiedAt = date
            }

            currentAnnotation = partial

        case "gesture":
            isInGesture = true
            currentGesture = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInGesture {
            currentGesture += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName.lowercased() {
        case "ink":
            if let partial = currentAnnotation {
                let annotation = XFDFParsedAnnotation(
                    id: partial.id,
                    pageIndex: partial.pageIndex,
                    paths: partial.paths,
                    color: partial.color,
                    lineWidth: partial.lineWidth,
                    opacity: partial.opacity,
                    createdAt: partial.createdAt,
                    modifiedAt: partial.modifiedAt,
                    toolType: partial.toolType
                )
                annotations.append(annotation)
            }
            currentAnnotation = nil

        case "gesture":
            if var partial = currentAnnotation {
                let points = parseGestureString(currentGesture)
                if !points.isEmpty {
                    partial.paths.append(points)
                    currentAnnotation = partial
                }
            }
            isInGesture = false
            currentGesture = ""

        default:
            break
        }
    }

    /// 解析 gesture 字符串 "x1,y1;x2,y2;..."
    private func parseGestureString(_ string: String) -> [CGPoint] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var points: [CGPoint] = []

        let pairs = trimmed.split(separator: ";")
        for pair in pairs {
            let coords = pair.split(separator: ",")
            if coords.count >= 2,
               let x = Double(coords[0].trimmingCharacters(in: .whitespaces)),
               let y = Double(coords[1].trimmingCharacters(in: .whitespaces)) {
                points.append(CGPoint(x: x, y: y))
            }
        }

        return points
    }
}

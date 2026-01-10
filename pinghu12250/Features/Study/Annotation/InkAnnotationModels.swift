//
//  InkAnnotationModels.swift
//  pinghu12250
//
//  批注数据模型 - JSON 存储结构
//  坐标使用 PDF 原生坐标系 (mediaBox)
//

import Foundation
import UIKit
import PDFKit

// MARK: - 批注工具类型

enum InkToolType: String, Codable, CaseIterable, Identifiable {
    case pen = "pen"
    case pencil = "pencil"
    case highlighter = "highlighter"
    case eraser = "eraser"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen: return "画笔"
        case .pencil: return "铅笔"
        case .highlighter: return "荧光笔"
        case .eraser: return "橡皮擦"
        }
    }

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        }
    }

    var defaultAlpha: CGFloat {
        switch self {
        case .pen: return 1.0
        case .pencil: return 0.8  // 铅笔略透明
        case .highlighter: return 0.3
        case .eraser: return 1.0
        }
    }
}

// MARK: - 预设颜色

struct InkColorPreset: Identifiable, Equatable {
    let id: String
    let color: UIColor
    let name: String

    static let presets: [InkColorPreset] = [
        InkColorPreset(id: "black", color: .black, name: "黑色"),
        InkColorPreset(id: "blue", color: .systemBlue, name: "蓝色"),
        InkColorPreset(id: "red", color: .systemRed, name: "红色"),
        InkColorPreset(id: "green", color: .systemGreen, name: "绿色"),
        InkColorPreset(id: "orange", color: .systemOrange, name: "橙色"),
    ]

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    static func from(hex: String) -> UIColor {
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
}

// MARK: - 线宽预设

enum InkLineWidth: CGFloat, CaseIterable, Identifiable {
    case thin = 2
    case medium = 4
    case thick = 6

    var id: CGFloat { rawValue }

    var displayName: String {
        switch self {
        case .thin: return "细"
        case .medium: return "中"
        case .thick: return "粗"
        }
    }
}

// MARK: - 橡皮擦大小 (PDF pt)

enum EraserSize: CGFloat, CaseIterable, Identifiable {
    case small = 10
    case medium = 20
    case large = 40

    var id: CGFloat { rawValue }

    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }
}

// MARK: - 单条批注数据

struct InkStrokeData: Codable, Identifiable {
    let id: String
    let pageIndex: Int
    let pageFingerprint: PageFingerprint
    let tool: String  // InkToolType.rawValue
    let colorHex: String
    let lineWidth: CGFloat
    let alpha: CGFloat
    let points: [[CGFloat]]  // [[x, y], [x, y], ...]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        pageIndex: Int,
        pageFingerprint: PageFingerprint,
        tool: InkToolType,
        color: UIColor,
        lineWidth: CGFloat,
        alpha: CGFloat,
        points: [CGPoint],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.pageFingerprint = pageFingerprint
        self.tool = tool.rawValue
        self.colorHex = InkColorPreset(id: "", color: color, name: "").hexString
        self.lineWidth = lineWidth
        self.alpha = alpha
        self.points = points.map { [$0.x, $0.y] }
        self.createdAt = createdAt
    }

    /// 转换为 CGPoint 数组
    var cgPoints: [CGPoint] {
        points.compactMap { arr in
            guard arr.count >= 2 else { return nil }
            return CGPoint(x: arr[0], y: arr[1])
        }
    }

    /// 转换为 UIColor
    var uiColor: UIColor {
        InkColorPreset.from(hex: colorHex).withAlphaComponent(alpha)
    }

    /// 工具类型
    var toolType: InkToolType {
        InkToolType(rawValue: tool) ?? .pen
    }
}

// MARK: - 页面指纹（用于校验页面匹配）

struct PageFingerprint: Codable, Equatable {
    let mediaBoxX: CGFloat
    let mediaBoxY: CGFloat
    let mediaBoxWidth: CGFloat
    let mediaBoxHeight: CGFloat
    let rotation: Int

    init(from page: PDFPage) {
        let mediaBox = page.bounds(for: .mediaBox)
        self.mediaBoxX = mediaBox.origin.x
        self.mediaBoxY = mediaBox.origin.y
        self.mediaBoxWidth = mediaBox.width
        self.mediaBoxHeight = mediaBox.height
        self.rotation = page.rotation
    }

    /// 检查是否与当前页面匹配
    func matches(_ page: PDFPage) -> Bool {
        let mediaBox = page.bounds(for: .mediaBox)
        let tolerance: CGFloat = 0.1

        return abs(mediaBox.origin.x - mediaBoxX) < tolerance &&
               abs(mediaBox.origin.y - mediaBoxY) < tolerance &&
               abs(mediaBox.width - mediaBoxWidth) < tolerance &&
               abs(mediaBox.height - mediaBoxHeight) < tolerance &&
               page.rotation == rotation
    }
}

// MARK: - 用户批注文档

struct UserAnnotationDocument: Codable {
    let userId: String
    let textbookId: String
    var annotations: [InkStrokeData]
    var updatedAt: Date

    init(userId: String, textbookId: String) {
        self.userId = userId
        self.textbookId = textbookId
        self.annotations = []
        self.updatedAt = Date()
    }

    /// 获取指定页面的批注
    func annotations(for pageIndex: Int) -> [InkStrokeData] {
        annotations.filter { $0.pageIndex == pageIndex }
    }

    /// 添加批注
    mutating func addAnnotation(_ stroke: InkStrokeData) {
        annotations.append(stroke)
        updatedAt = Date()
    }

    /// 移除批注
    mutating func removeAnnotation(id: String) {
        annotations.removeAll { $0.id == id }
        updatedAt = Date()
    }

    /// 移除指定页面的所有批注
    mutating func removeAnnotations(for pageIndex: Int) {
        annotations.removeAll { $0.pageIndex == pageIndex }
        updatedAt = Date()
    }

    /// 标记为已更新
    mutating func markUpdated() {
        updatedAt = Date()
    }
}

// MARK: - 撤销/重做栈

struct UndoRedoStack<T> {
    private var undoStack: [T] = []
    private var redoStack: [T] = []
    private let maxSize: Int

    init(maxSize: Int = 5) {
        self.maxSize = maxSize
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func push(_ item: T) {
        undoStack.append(item)
        if undoStack.count > maxSize {
            undoStack.removeFirst()
        }
        // 新操作时清空重做栈
        redoStack.removeAll()
    }

    mutating func undo() -> T? {
        guard let item = undoStack.popLast() else { return nil }
        redoStack.append(item)
        return item
    }

    mutating func redo() -> T? {
        guard let item = redoStack.popLast() else { return nil }
        undoStack.append(item)
        return item
    }

    mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

//
//  StrokeModels.swift
//  pinghu12250
//
//  笔画数据模型 - 与Web端完全兼容
//  用于书写练习和AI评价
//

import Foundation
import SwiftUI

// MARK: - 笔画数据 (与Web useStrokeData.js 一致)

/// 笔画数据版本
let STROKE_DATA_VERSION = 2

/// 笔画数据结构
struct StrokeData: Codable {
    var version: Int = STROKE_DATA_VERSION
    var canvas: CanvasSize
    var strokes: [Stroke]
    var preview: String?  // base64 预览图

    // 书写练习特有字段
    var character: String?
    var originalNoteId: String?
    var gridType: String?

    struct CanvasSize: Codable {
        let width: CGFloat
        let height: CGFloat
        let dpr: CGFloat

        init(width: CGFloat, height: CGFloat, dpr: CGFloat = 1) {
            self.width = width
            self.height = height
            self.dpr = dpr
        }
    }

    struct Stroke: Codable {
        let id: String
        let color: String
        let lineWidth: CGFloat
        var points: [Point]

        init(id: String, color: String, lineWidth: CGFloat, points: [Point]) {
            self.id = id
            self.color = color
            self.lineWidth = lineWidth
            self.points = points
        }
    }

    struct Point: Codable {
        let x: CGFloat
        let y: CGFloat
        let t: Int64    // 时间戳(毫秒)
        let p: CGFloat? // 压力值(可选)

        init(x: CGFloat, y: CGFloat, t: Int64, p: CGFloat? = nil) {
            // 保留2位小数，与Web一致
            self.x = (x * 100).rounded() / 100
            self.y = (y * 100).rounded() / 100
            self.t = t
            self.p = p
        }
    }

    /// 空数据
    static func empty(canvasSize: CGSize = CGSize(width: 300, height: 300)) -> StrokeData {
        StrokeData(
            canvas: CanvasSize(
                width: canvasSize.width,
                height: canvasSize.height,
                dpr: UIScreen.main.scale
            ),
            strokes: []
        )
    }

    /// 是否有笔画内容
    var hasContent: Bool {
        !strokes.isEmpty
    }

    /// 导出为JSON字符串
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从JSON字符串解析
    static func fromJSON(_ json: String) -> StrokeData? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StrokeData.self, from: data)
    }
}

// MARK: - 笔画指标 (与Web useStrokeMetrics.js 一致)

/// AI评价需要的笔画指标
struct StrokeMetrics: Codable {
    let totalStrokes: Int
    let strokes: [StrokeMetric]
    let totalLength: Int
    let totalDuration: Int
    let overallDuration: Int
    let avgStrokeSpeed: Int
    let pauseCount: Int
    let maxPauseDuration: Int
    let avgPauseDuration: Int
    let stabilityScore: Int
    let canvasSize: CanvasSizeInt

    struct StrokeMetric: Codable {
        let index: Int
        let startPoint: PointInt
        let endPoint: PointInt
        let length: Int
        let duration: Int
        let avgSpeed: Int
        let jitterScore: Int
        let pointCount: Int
    }

    struct PointInt: Codable {
        let x: Int
        let y: Int
    }

    struct CanvasSizeInt: Codable {
        let width: Int
        let height: Int
    }
}

// MARK: - AI书写评价结果

/// 书写评价结果
struct WritingEvaluation: Codable, Identifiable {
    let id: String
    let noteId: String
    let userId: String
    let overallScore: Int
    let scoreLevel: String  // excellent/good/needsWork
    let dimensionsDict: [String: DimensionScore]?
    let suggestions: [String]?
    let encouragement: String?
    let modelId: String?
    let promptVersion: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, noteId, userId, overallScore, scoreLevel
        case dimensionsDict = "dimensions"
        case suggestions, encouragement, modelId, promptVersion, createdAt
    }

    struct DimensionScore: Codable {
        let score: Int
        let comment: String?
    }

    /// 维度数组（方便UI遍历）
    var dimensions: [WritingDimension]? {
        guard let dict = dimensionsDict else { return nil }
        return dict.map { key, value in
            WritingDimension(
                name: key,
                score: value.score,
                comment: value.comment
            )
        }.sorted { $0.displayOrder < $1.displayOrder }
    }

    /// 等级文本
    var levelText: String {
        switch scoreLevel {
        case "excellent": return "优秀"
        case "good": return "良好"
        case "needsWork": return "继续加油"
        default: return ""
        }
    }

    /// 等级颜色
    var levelColor: Color {
        switch scoreLevel {
        case "excellent": return .green
        case "good": return .blue
        case "needsWork": return .orange
        default: return .gray
        }
    }
}

/// 维度评分（用于UI展示）
struct WritingDimension: Identifiable {
    let name: String
    let score: Int
    let comment: String?

    var id: String { name }

    /// 维度显示名称
    var displayName: String {
        switch name {
        case "similarity": return "相似度"
        case "strokeOrderCorrect", "strokeOrder": return "笔顺"
        case "structure": return "结构"
        case "rhythm": return "节奏"
        case "stability": return "稳定性"
        default: return name
        }
    }

    /// 排序顺序
    var displayOrder: Int {
        switch name {
        case "strokeOrder", "strokeOrderCorrect": return 0
        case "structure": return 1
        case "rhythm": return 2
        case "stability": return 3
        case "similarity": return 4
        default: return 99
        }
    }
}

// MARK: - API响应类型

/// 评价状态响应
struct WritingEvaluationStatusResponse: Codable {
    let success: Bool
    let data: StatusData

    struct StatusData: Codable {
        let hasEvaluation: Bool
        let canAnalyze: Bool
        let canReanalyzeAt: String?
        let remainingHours: Int?
    }
}

/// 评价结果响应
struct WritingEvaluationResponse: Codable {
    let success: Bool
    let data: WritingEvaluation?
    let error: String?
}

/// 分析请求
struct WritingAnalyzeRequest: Encodable {
    let noteId: String
    let character: String
    let metrics: StrokeMetrics
    let renderedImage: String?
}

// MARK: - 格子类型

enum GridType: String, CaseIterable {
    case mi = "mi"      // 米字格
    case tian = "tian"  // 田字格

    var displayName: String {
        switch self {
        case .mi: return "米字格"
        case .tian: return "田字格"
        }
    }
}

// MARK: - UIColor扩展

extension UIColor {
    /// 转换为十六进制字符串
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    /// 从十六进制字符串创建
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

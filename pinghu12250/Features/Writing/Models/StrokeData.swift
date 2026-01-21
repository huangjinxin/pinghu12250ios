//
//  StrokeData.swift
//  pinghu12250
//
//  笔画数据结构 - 与Web端JSON格式兼容
//

import Foundation
import PencilKit
import UIKit

// MARK: - 笔画数据V2（与Web兼容）

struct StrokeDataV2: Codable {
    let version: Int
    let canvas: CanvasInfo
    var strokes: [StrokeInfo]

    init(canvas: CanvasInfo, strokes: [StrokeInfo]) {
        self.version = 2
        self.canvas = canvas
        self.strokes = strokes
    }

    struct CanvasInfo: Codable {
        let width: CGFloat
        let height: CGFloat
    }
}

struct StrokeInfo: Codable {
    let id: String
    let color: String
    let lineWidth: CGFloat
    var points: [StrokePoint]
}

struct StrokePoint: Codable {
    let x: CGFloat
    let y: CGFloat
    let t: TimeInterval
    let p: CGFloat  // pressure
}

// MARK: - PencilKit 转换

extension StrokeDataV2 {
    /// 从PKDrawing转换
    static func from(drawing: PKDrawing, canvasSize: CGSize) -> StrokeDataV2 {
        let strokes = drawing.strokes.map { pkStroke -> StrokeInfo in
            let color = pkStroke.ink.color.hexString
            let points = pkStroke.path.enumerated().map { index, point -> StrokePoint in
                StrokePoint(
                    x: point.location.x,
                    y: point.location.y,
                    t: TimeInterval(index) * 0.016,  // 约60fps
                    p: point.force > 0 ? point.force : 0.5
                )
            }
            return StrokeInfo(
                id: UUID().uuidString,
                color: color,
                lineWidth: pkStroke.path.first?.size.width ?? 3,
                points: points
            )
        }
        return StrokeDataV2(
            canvas: CanvasInfo(width: canvasSize.width, height: canvasSize.height),
            strokes: strokes
        )
    }

    /// 转换为JSON字符串
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从JSON字符串解析
    static func from(json: String) -> StrokeDataV2? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StrokeDataV2.self, from: data)
    }
}

//
//  WritingEvaluationService.swift
//  pinghu12250
//
//  AI书写评价服务
//  调用后端API进行书写分析和评价
//

import Foundation
import SwiftUI

/// AI书写评价服务
class WritingEvaluationService {

    static let shared = WritingEvaluationService()

    private init() {}

    // MARK: - API方法

    /// 获取评价状态（是否可分析，剩余冷却时间）
    /// - Parameter noteId: 笔记ID
    /// - Returns: 状态信息
    func getStatus(noteId: String) async throws -> WritingEvaluationStatusResponse.StatusData {
        let response: WritingEvaluationStatusResponse = try await APIService.shared.get(
            "\(APIConfig.Endpoints.writingEvaluation)/\(noteId)/status"
        )
        return response.data
    }

    /// 获取评价结果
    /// - Parameter noteId: 笔记ID
    /// - Returns: 评价结果（如果存在）
    func getEvaluation(noteId: String) async throws -> WritingEvaluation? {
        let response: WritingEvaluationResponse = try await APIService.shared.get(
            "\(APIConfig.Endpoints.writingEvaluation)/\(noteId)"
        )
        return response.data
    }

    /// 发起AI分析
    /// - Parameters:
    ///   - noteId: 笔记ID
    ///   - character: 练习的字符
    ///   - strokeData: 笔画数据
    ///   - renderedImage: 渲染后的预览图（base64）
    /// - Returns: 评价结果
    func analyze(
        noteId: String,
        character: String,
        strokeData: StrokeData,
        renderedImage: String?
    ) async throws -> WritingEvaluation {
        // 计算指标
        guard let metrics = StrokeMetricsService.calculateMetrics(strokeData) else {
            throw WritingEvaluationError.invalidStrokeData
        }

        let request = WritingAnalyzeRequest(
            noteId: noteId,
            character: character,
            metrics: metrics,
            renderedImage: renderedImage
        )

        let response: WritingEvaluationResponse = try await APIService.shared.post(
            "\(APIConfig.Endpoints.writingEvaluation)/analyze",
            body: request
        )

        if let evaluation = response.data {
            return evaluation
        } else {
            throw WritingEvaluationError.analysisFailed(response.error ?? "未知错误")
        }
    }

    // MARK: - 预览图生成

    /// 从笔画数据生成预览图
    /// - Parameters:
    ///   - strokeData: 笔画数据
    ///   - size: 目标尺寸
    ///   - backgroundColor: 背景颜色
    /// - Returns: base64图片字符串
    func generatePreviewImage(
        strokeData: StrokeData,
        size: CGSize = CGSize(width: 400, height: 400),
        backgroundColor: UIColor = .white
    ) -> String? {
        guard !strokeData.strokes.isEmpty else { return nil }

        // 计算缩放比例
        let canvasWidth = strokeData.canvas.width
        let canvasHeight = strokeData.canvas.height
        let scaleX = size.width / canvasWidth
        let scaleY = size.height / canvasHeight
        let scale = min(scaleX, scaleY, 1)

        let targetWidth = canvasWidth * scale
        let targetHeight = canvasHeight * scale

        // 创建图形上下文
        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetWidth, height: targetHeight), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // 填充背景
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // 绘制笔画
        for stroke in strokeData.strokes {
            guard stroke.points.count >= 2 else { continue }

            context.beginPath()
            context.setStrokeColor(UIColor(hex: stroke.color)?.cgColor ?? UIColor.black.cgColor)
            context.setLineWidth(stroke.lineWidth * scale)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let firstPoint = stroke.points[0]
            context.move(to: CGPoint(x: firstPoint.x * scale, y: firstPoint.y * scale))

            for i in 1..<stroke.points.count {
                let point = stroke.points[i]
                context.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
            }

            context.strokePath()
        }

        // 获取图片
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // 转换为base64
        guard let pngData = image?.pngData() else { return nil }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
}

// MARK: - 错误类型

enum WritingEvaluationError: LocalizedError {
    case invalidStrokeData
    case analysisFailed(String)
    case cooldownActive(Int)

    var errorDescription: String? {
        switch self {
        case .invalidStrokeData:
            return "无法解析笔画数据"
        case .analysisFailed(let message):
            return "AI分析失败: \(message)"
        case .cooldownActive(let hours):
            return "请在\(hours)小时后重试"
        }
    }
}

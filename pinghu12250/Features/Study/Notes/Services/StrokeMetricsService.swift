//
//  StrokeMetricsService.swift
//  pinghu12250
//
//  笔画指标计算服务 - 与Web useStrokeMetrics.js 完全一致
//  用于计算AI评价需要的各项指标
//

import Foundation

/// 笔画指标计算服务
class StrokeMetricsService {

    // MARK: - 主方法

    /// 计算完整的笔画指标（用于AI评价）
    /// - Parameter strokeData: 笔画数据
    /// - Returns: 计算后的指标
    static func calculateMetrics(_ strokeData: StrokeData) -> StrokeMetrics? {
        guard !strokeData.strokes.isEmpty else { return nil }

        var strokeMetrics: [StrokeMetrics.StrokeMetric] = []
        var totalLength: CGFloat = 0
        var totalDuration: Int64 = 0
        var firstPointTime: Int64 = Int64.max
        var lastPointTime: Int64 = 0

        // 计算每笔的指标
        for (index, stroke) in strokeData.strokes.enumerated() {
            guard stroke.points.count >= 2 else { continue }

            let startPoint = stroke.points.first!
            let endPoint = stroke.points.last!
            let duration = endPoint.t - startPoint.t
            let length = calculateStrokeLength(stroke.points)
            let jitterScore = calculateJitter(stroke.points)

            // 更新全局时间范围
            if startPoint.t < firstPointTime { firstPointTime = startPoint.t }
            if endPoint.t > lastPointTime { lastPointTime = endPoint.t }

            totalLength += length
            totalDuration += duration

            strokeMetrics.append(StrokeMetrics.StrokeMetric(
                index: index + 1,
                startPoint: StrokeMetrics.PointInt(x: Int(startPoint.x), y: Int(startPoint.y)),
                endPoint: StrokeMetrics.PointInt(x: Int(endPoint.x), y: Int(endPoint.y)),
                length: Int(length),
                duration: Int(duration),
                avgSpeed: duration > 0 ? Int(length / CGFloat(duration) * 1000) : 0,
                jitterScore: jitterScore,
                pointCount: stroke.points.count
            ))
        }

        // 计算停顿
        let pauses = calculatePauses(strokeData.strokes)
        let pauseCount = pauses.count
        let maxPauseDuration = pauses.max() ?? 0
        let avgPauseDuration = pauses.isEmpty ? 0 : pauses.reduce(0, +) / pauses.count

        // 计算整体稳定性分数（所有笔画jitter分数的加权平均）
        let totalJitter = strokeMetrics.reduce(0) { $0 + $1.jitterScore * $1.length }
        let overallStability = totalLength > 0 ? Int(CGFloat(totalJitter) / totalLength) : 0

        // 计算整体时长（从第一笔开始到最后一笔结束）
        let overallDuration = lastPointTime - firstPointTime

        return StrokeMetrics(
            totalStrokes: strokeData.strokes.count,
            strokes: strokeMetrics,
            totalLength: Int(totalLength),
            totalDuration: Int(totalDuration),
            overallDuration: Int(overallDuration),
            avgStrokeSpeed: totalDuration > 0 ? Int(totalLength / CGFloat(totalDuration) * 1000) : 0,
            pauseCount: pauseCount,
            maxPauseDuration: maxPauseDuration,
            avgPauseDuration: avgPauseDuration,
            stabilityScore: overallStability,
            canvasSize: StrokeMetrics.CanvasSizeInt(
                width: Int(strokeData.canvas.width),
                height: Int(strokeData.canvas.height)
            )
        )
    }

    // MARK: - 辅助方法

    /// 计算两点之间的距离
    private static func distance(_ p1: StrokeData.Point, _ p2: StrokeData.Point) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    /// 计算笔画总长度
    private static func calculateStrokeLength(_ points: [StrokeData.Point]) -> CGFloat {
        guard points.count >= 2 else { return 0 }

        var length: CGFloat = 0
        for i in 1..<points.count {
            length += distance(points[i - 1], points[i])
        }

        return (length * 100).rounded() / 100
    }

    /// 计算笔画抖动程度（0-100，越高越稳定）
    /// 通过分析相邻点的方向变化来评估
    private static func calculateJitter(_ points: [StrokeData.Point]) -> Int {
        guard points.count >= 3 else { return 0 }

        var totalAngleChange: CGFloat = 0
        var segmentCount = 0

        for i in 2..<points.count {
            let p1 = points[i - 2]
            let p2 = points[i - 1]
            let p3 = points[i]

            // 计算两个向量
            let v1x = p2.x - p1.x
            let v1y = p2.y - p1.y
            let v2x = p3.x - p2.x
            let v2y = p3.y - p2.y

            // 计算向量长度
            let len1 = sqrt(v1x * v1x + v1y * v1y)
            let len2 = sqrt(v2x * v2x + v2y * v2y)

            if len1 > 0.1 && len2 > 0.1 {
                // 计算夹角（使用点积）
                let dot = v1x * v2x + v1y * v2y
                let cosAngle = max(-1, min(1, dot / (len1 * len2)))
                let angle = acos(cosAngle) * 180 / .pi

                totalAngleChange += angle
                segmentCount += 1
            }
        }

        guard segmentCount > 0 else { return 0 }

        // 平均角度变化，转换为0-100分数
        let avgAngleChange = totalAngleChange / CGFloat(segmentCount)
        // 角度变化越小，分数越高（越稳定）
        // 假设5度以下为很稳定，60度以上为很抖
        let jitterScore = max(0, min(100, 100 - (avgAngleChange - 5) * 2.5))

        return Int(jitterScore.rounded())
    }

    /// 计算笔画之间的停顿
    private static func calculatePauses(_ strokes: [StrokeData.Stroke]) -> [Int] {
        var pauses: [Int] = []

        for i in 1..<strokes.count {
            let prevStroke = strokes[i - 1]
            let currStroke = strokes[i]

            guard let prevEnd = prevStroke.points.last,
                  let currStart = currStroke.points.first else { continue }

            let pauseDuration = Int(currStart.t - prevEnd.t)
            if pauseDuration > 100 {  // 超过100ms算停顿
                pauses.append(pauseDuration)
            }
        }

        return pauses
    }
}

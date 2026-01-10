//
//  PathSmoothingUtility.swift
//  pinghu12250
//
//  路径平滑工具
//  - Douglas-Peucker 算法：减少点数，去除冗余点
//  - Catmull-Rom 样条：平滑曲线插值
//

import Foundation
import CoreGraphics

/// 路径平滑工具
enum PathSmoothingUtility {

    // MARK: - Douglas-Peucker 简化算法

    /// 使用 Douglas-Peucker 算法简化路径
    /// - Parameters:
    ///   - points: 原始点数组
    ///   - epsilon: 容差值（越小保留越多细节，建议 1.0-3.0）
    /// - Returns: 简化后的点数组
    static func douglasPeucker(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        // 找到距离首尾连线最远的点
        var maxDistance: CGFloat = 0
        var maxIndex = 0

        let start = points[0]
        let end = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // 如果最大距离大于容差，递归简化
        if maxDistance > epsilon {
            let left = douglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(Array(points[maxIndex...]), epsilon: epsilon)
            // 合并结果（去除重复的中间点）
            return Array(left.dropLast()) + right
        } else {
            // 否则只保留首尾两点
            return [start, end]
        }
    }

    /// 计算点到线段的垂直距离
    private static func perpendicularDistance(
        _ point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        // 线段长度的平方
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            // 线段退化为点
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        // 计算投影参数 t
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared

        if t < 0 {
            // 投影点在线段起点之前
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        } else if t > 1 {
            // 投影点在线段终点之后
            return hypot(point.x - lineEnd.x, point.y - lineEnd.y)
        } else {
            // 投影点在线段上
            let projX = lineStart.x + t * dx
            let projY = lineStart.y + t * dy
            return hypot(point.x - projX, point.y - projY)
        }
    }

    // MARK: - Catmull-Rom 样条插值

    /// 使用 Catmull-Rom 样条平滑路径
    /// - Parameters:
    ///   - points: 控制点数组（至少需要 4 个点）
    ///   - segments: 每段曲线的插值点数（越大越平滑，建议 8-16）
    ///   - tension: 张力参数（0.0-1.0，默认 0.5 为标准 Catmull-Rom）
    /// - Returns: 平滑后的点数组
    static func catmullRomSpline(
        _ points: [CGPoint],
        segments: Int = 10,
        tension: CGFloat = 0.5
    ) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        if points.count == 2 {
            return linearInterpolate(points[0], points[1], segments: segments)
        }

        if points.count == 3 {
            // 对于 3 个点，使用二次贝塞尔曲线
            return quadraticBezier(points[0], points[1], points[2], segments: segments)
        }

        var result: [CGPoint] = []

        // 扩展控制点（首尾各复制一个）
        let extendedPoints = [points[0]] + points + [points[points.count - 1]]

        // 对每一段进行插值
        for i in 1..<(extendedPoints.count - 2) {
            let p0 = extendedPoints[i - 1]
            let p1 = extendedPoints[i]
            let p2 = extendedPoints[i + 1]
            let p3 = extendedPoints[i + 2]

            for j in 0..<segments {
                let t = CGFloat(j) / CGFloat(segments)
                let point = catmullRomPoint(p0, p1, p2, p3, t: t, tension: tension)
                result.append(point)
            }
        }

        // 添加最后一个点
        result.append(points[points.count - 1])

        return result
    }

    /// 计算 Catmull-Rom 曲线上的一个点
    private static func catmullRomPoint(
        _ p0: CGPoint,
        _ p1: CGPoint,
        _ p2: CGPoint,
        _ p3: CGPoint,
        t: CGFloat,
        tension: CGFloat
    ) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        // Catmull-Rom 矩阵系数
        let s = (1 - tension) / 2

        let a0 = -s * t3 + 2 * s * t2 - s * t
        let a1 = (2 - s) * t3 + (s - 3) * t2 + 1
        let a2 = (s - 2) * t3 + (3 - 2 * s) * t2 + s * t
        let a3 = s * t3 - s * t2

        let x = a0 * p0.x + a1 * p1.x + a2 * p2.x + a3 * p3.x
        let y = a0 * p0.y + a1 * p1.y + a2 * p2.y + a3 * p3.y

        return CGPoint(x: x, y: y)
    }

    /// 线性插值
    private static func linearInterpolate(
        _ start: CGPoint,
        _ end: CGPoint,
        segments: Int
    ) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }

    /// 二次贝塞尔曲线
    private static func quadraticBezier(
        _ p0: CGPoint,
        _ p1: CGPoint,
        _ p2: CGPoint,
        segments: Int
    ) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let oneMinusT = 1 - t

            let x = oneMinusT * oneMinusT * p0.x +
                    2 * oneMinusT * t * p1.x +
                    t * t * p2.x

            let y = oneMinusT * oneMinusT * p0.y +
                    2 * oneMinusT * t * p1.y +
                    t * t * p2.y

            result.append(CGPoint(x: x, y: y))
        }
        return result
    }

    // MARK: - 组合平滑处理

    /// 组合处理：先简化再平滑
    /// - Parameters:
    ///   - points: 原始点数组
    ///   - simplifyEpsilon: Douglas-Peucker 容差值
    ///   - smoothSegments: Catmull-Rom 插值段数
    /// - Returns: 处理后的点数组
    static func simplifyAndSmooth(
        _ points: [CGPoint],
        simplifyEpsilon: CGFloat = 1.5,
        smoothSegments: Int = 8
    ) -> [CGPoint] {
        // 点数太少直接返回
        guard points.count > 3 else { return points }

        // 第一步：简化（减少点数）
        let simplified = douglasPeucker(points, epsilon: simplifyEpsilon)

        // 简化后点数不足，直接返回
        guard simplified.count >= 2 else { return points }

        // 第二步：平滑（插值）
        return catmullRomSpline(simplified, segments: smoothSegments)
    }

    // MARK: - 工具方法

    /// 计算路径总长度
    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }

        var length: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            length += hypot(dx, dy)
        }
        return length
    }

    /// 计算路径边界框
    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

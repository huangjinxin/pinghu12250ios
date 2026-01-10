//
//  RangeGuard.swift
//  pinghu12250
//
//  数值范围守卫 - 在业务层验证和修正数值
//  防止非法数值传递到 View 层导致崩溃
//
//  【核心原则】View 层不应该 trust 任何数据
//  所有来自 JSON / 计算的数值，在进入 View 前必须经过 RangeGuard
//

import Foundation
import CoreGraphics
import Combine

// MARK: - RangeGuard

/// 数值范围守卫
/// 用于验证、修正和记录非法数值
enum RangeGuard {

    // MARK: - 整数守卫

    /// 守卫整数值
    /// - Parameters:
    ///   - value: 原始值
    ///   - range: 有效范围
    ///   - default: 默认值（当 value 无效时使用）
    ///   - context: 上下文描述（用于诊断）
    /// - Returns: 安全的值
    static func guardInt(
        _ value: Int?,
        in range: ClosedRange<Int>,
        default defaultValue: Int,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> Int {
        guard let value = value else {
            recordNilValue(context: context, file: file, line: line)
            return clamp(defaultValue, to: range)
        }

        if range.contains(value) {
            return value
        }

        recordOutOfRange(
            value: Double(value),
            range: "\(range.lowerBound)...\(range.upperBound)",
            context: context,
            file: file,
            line: line
        )

        return clamp(value, to: range)
    }

    /// 守卫可选整数值，返回可选
    static func guardOptionalInt(
        _ value: Int?,
        in range: ClosedRange<Int>,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> Int? {
        guard let value = value else { return nil }

        if range.contains(value) {
            return value
        }

        recordOutOfRange(
            value: Double(value),
            range: "\(range.lowerBound)...\(range.upperBound)",
            context: context,
            file: file,
            line: line
        )

        return clamp(value, to: range)
    }

    // MARK: - 浮点数守卫

    /// 守卫 Double 值
    static func guardDouble(
        _ value: Double?,
        in range: ClosedRange<Double>,
        default defaultValue: Double,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> Double {
        guard let value = value else {
            recordNilValue(context: context, file: file, line: line)
            return clamp(defaultValue, to: range)
        }

        // 检查 NaN 和 infinity
        guard value.isFinite else {
            recordNonFinite(value: value, context: context, file: file, line: line)
            return clamp(defaultValue, to: range)
        }

        if range.contains(value) {
            return value
        }

        recordOutOfRange(
            value: value,
            range: "\(range.lowerBound)...\(range.upperBound)",
            context: context,
            file: file,
            line: line
        )

        return clamp(value, to: range)
    }

    /// 守卫 CGFloat 值
    static func guardCGFloat(
        _ value: CGFloat?,
        in range: ClosedRange<CGFloat>,
        default defaultValue: CGFloat,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> CGFloat {
        guard let value = value else {
            recordNilValue(context: context, file: file, line: line)
            return clamp(defaultValue, to: range)
        }

        guard value.isFinite else {
            recordNonFinite(value: Double(value), context: context, file: file, line: line)
            return clamp(defaultValue, to: range)
        }

        if range.contains(value) {
            return value
        }

        recordOutOfRange(
            value: Double(value),
            range: "\(range.lowerBound)...\(range.upperBound)",
            context: context,
            file: file,
            line: line
        )

        return clamp(value, to: range)
    }

    // MARK: - 页码专用守卫

    /// 守卫页码值
    /// - Parameters:
    ///   - page: 当前页码
    ///   - totalPages: 总页数
    /// - Returns: 安全的页码（1 ~ max(1, totalPages)）
    static func guardPage(
        _ page: Int,
        totalPages: Int,
        context: String = "page",
        file: String = #file,
        line: Int = #line
    ) -> Int {
        let safeTotalPages = max(1, totalPages)
        return guardInt(
            page,
            in: 1...safeTotalPages,
            default: 1,
            context: context,
            file: file,
            line: line
        )
    }

    /// 守卫总页数
    /// - Returns: 安全的总页数（至少为 1）
    static func guardTotalPages(
        _ totalPages: Int?,
        context: String = "totalPages",
        file: String = #file,
        line: Int = #line
    ) -> Int {
        guard let totalPages = totalPages, totalPages > 0 else {
            if totalPages != nil && totalPages! <= 0 {
                recordOutOfRange(
                    value: Double(totalPages!),
                    range: "1...∞",
                    context: context,
                    file: file,
                    line: line
                )
            }
            return 1
        }
        return totalPages
    }

    // MARK: - 难度值守卫

    /// 守卫难度值（1-5）
    static func guardDifficulty(
        _ difficulty: Int?,
        context: String = "difficulty",
        file: String = #file,
        line: Int = #line
    ) -> Int {
        return guardInt(
            difficulty,
            in: 1...5,
            default: 3,
            context: context,
            file: file,
            line: line
        )
    }

    // MARK: - 进度值守卫

    /// 守卫进度值（0.0-1.0）
    static func guardProgress(
        _ progress: Double?,
        context: String = "progress",
        file: String = #file,
        line: Int = #line
    ) -> Double {
        return guardDouble(
            progress,
            in: 0.0...1.0,
            default: 0.0,
            context: context,
            file: file,
            line: line
        )
    }

    /// 守卫百分比值（0-100）
    static func guardPercentage(
        _ percentage: Double?,
        context: String = "percentage",
        file: String = #file,
        line: Int = #line
    ) -> Double {
        return guardDouble(
            percentage,
            in: 0.0...100.0,
            default: 0.0,
            context: context,
            file: file,
            line: line
        )
    }

    // MARK: - 尺寸守卫

    /// 守卫宽度/高度（必须 > 0）
    static func guardDimension(
        _ dimension: CGFloat?,
        min: CGFloat = 1,
        max: CGFloat = 10000,
        default defaultValue: CGFloat = 100,
        context: String = "dimension",
        file: String = #file,
        line: Int = #line
    ) -> CGFloat {
        return guardCGFloat(
            dimension,
            in: min...max,
            default: defaultValue,
            context: context,
            file: file,
            line: line
        )
    }

    /// 守卫 CGSize
    static func guardSize(
        _ size: CGSize?,
        minWidth: CGFloat = 1,
        minHeight: CGFloat = 1,
        default defaultSize: CGSize = CGSize(width: 100, height: 100),
        context: String = "size",
        file: String = #file,
        line: Int = #line
    ) -> CGSize {
        guard let size = size else {
            recordNilValue(context: context, file: file, line: line)
            return defaultSize
        }

        let width = guardDimension(
            size.width,
            min: minWidth,
            default: defaultSize.width,
            context: "\(context).width",
            file: file,
            line: line
        )

        let height = guardDimension(
            size.height,
            min: minHeight,
            default: defaultSize.height,
            context: "\(context).height",
            file: file,
            line: line
        )

        return CGSize(width: width, height: height)
    }

    /// 守卫 CGRect（frame 维度检查）
    static func guardFrame(
        _ frame: CGRect?,
        default defaultFrame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
        context: String = "frame",
        file: String = #file,
        line: Int = #line
    ) -> CGRect {
        guard let frame = frame else {
            recordNilValue(context: context, file: file, line: line)
            return defaultFrame
        }

        // 检查是否为有效 frame
        guard frame.width > 0 && frame.height > 0 &&
              frame.origin.x.isFinite && frame.origin.y.isFinite &&
              frame.width.isFinite && frame.height.isFinite else {
            recordInvalidFrame(frame: frame, context: context, file: file, line: line)
            return defaultFrame
        }

        return frame
    }

    // MARK: - Private Helpers

    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        return Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    // MARK: - 诊断记录

    private static func recordNilValue(
        context: String,
        file: String,
        line: Int
    ) {
        RangeGuardDiagnostics.shared.record(
            type: .nilValue,
            context: context,
            message: "Nil value encountered",
            file: file,
            line: line
        )
    }

    private static func recordOutOfRange(
        value: Double,
        range: String,
        context: String,
        file: String,
        line: Int
    ) {
        RangeGuardDiagnostics.shared.record(
            type: .outOfRange,
            context: context,
            message: "Value \(value) out of range \(range)",
            file: file,
            line: line
        )
    }

    private static func recordNonFinite(
        value: Double,
        context: String,
        file: String,
        line: Int
    ) {
        RangeGuardDiagnostics.shared.record(
            type: .nonFinite,
            context: context,
            message: "Non-finite value: \(value)",
            file: file,
            line: line
        )
    }

    private static func recordInvalidFrame(
        frame: CGRect,
        context: String,
        file: String,
        line: Int
    ) {
        RangeGuardDiagnostics.shared.record(
            type: .invalidFrame,
            context: context,
            message: "Invalid frame: \(frame)",
            file: file,
            line: line
        )
    }
}

// MARK: - RangeGuardDiagnostics

/// RangeGuard 诊断记录器
final class RangeGuardDiagnostics {
    static let shared = RangeGuardDiagnostics()

    private let lock = NSLock()
    private var records: [Record] = []
    private let maxRecords = 100

    private init() {}

    enum RecordType: String, Codable {
        case nilValue = "nil_value"
        case outOfRange = "out_of_range"
        case nonFinite = "non_finite"
        case invalidFrame = "invalid_frame"
    }

    struct Record: Codable {
        let timestamp: Date
        let type: RecordType
        let context: String
        let message: String
        let file: String
        let line: Int
    }

    func record(
        type: RecordType,
        context: String,
        message: String,
        file: String,
        line: Int
    ) {
        lock.lock()
        defer { lock.unlock() }

        let record = Record(
            timestamp: Date(),
            type: type,
            context: context,
            message: message,
            file: (file as NSString).lastPathComponent,
            line: line
        )

        records.append(record)

        if records.count > maxRecords {
            records.removeFirst()
        }

        // 输出日志
        appLog("[RangeGuard] [\(context)] \(message)")

        #if DEBUG
        #if DEBUG
        print("[RangeGuard WARNING] [\(context)] \(message) at \(record.file):\(line)")
        #endif
        #endif
    }

    func getRecords() -> [Record] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        records.removeAll()
    }

    /// 导出诊断报告
    func exportReport() -> String {
        let records = getRecords()
        guard !records.isEmpty else {
            return "No RangeGuard violations recorded."
        }

        var report = "=== RangeGuard Violations Report ===\n"
        report += "Total: \(records.count) violations\n\n"

        for (index, record) in records.enumerated() {
            report += """
            [\(index + 1)] \(record.timestamp.formatted())
            Type: \(record.type.rawValue)
            Context: \(record.context)
            Message: \(record.message)
            Location: \(record.file):\(record.line)

            """
        }

        return report
    }
}

// MARK: - 便捷扩展

extension Int {
    /// 使用 RangeGuard 确保值在范围内
    func guarded(in range: ClosedRange<Int>, context: String = "") -> Int {
        RangeGuard.guardInt(self, in: range, default: range.lowerBound, context: context)
    }
}

extension Double {
    /// 使用 RangeGuard 确保值在范围内
    func guarded(in range: ClosedRange<Double>, context: String = "") -> Double {
        RangeGuard.guardDouble(self, in: range, default: range.lowerBound, context: context)
    }
}

extension CGFloat {
    /// 使用 RangeGuard 确保值在范围内
    func guarded(in range: ClosedRange<CGFloat>, context: String = "") -> CGFloat {
        RangeGuard.guardCGFloat(self, in: range, default: range.lowerBound, context: context)
    }
}

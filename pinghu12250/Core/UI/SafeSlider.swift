//
//  SafeSlider.swift
//  pinghu12250
//
//  安全 Slider 封装 - 防止 SwiftUI Slider 崩溃
//  修复 Fatal error: max stride must be positive
//
//  【强制规则】禁止在项目中直接使用 SwiftUI 原生 Slider
//  所有 Slider 必须使用此组件
//

import SwiftUI

// MARK: - SafeSlider

/// 安全的 Slider 封装
/// 解决 SwiftUI Slider 在以下情况下崩溃的问题：
/// - max <= min（range 无效）
/// - stride <= 0
/// - 值为 NaN 或 infinity
///
/// 使用方式：与原生 Slider 完全一致
/// ```swift
/// SafeSlider(value: $page, in: 1...totalPages, step: 1)
/// ```
struct SafeSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride?
    let onEditingChanged: ((Bool) -> Void)?

    // 安全后的实际 range
    private var safeRange: ClosedRange<V> {
        let min = range.lowerBound
        let max = range.upperBound

        // 确保 max > min
        if max <= min {
            // 记录诊断信息
            SliderDiagnostics.recordInvalidRange(
                min: Double(min),
                max: Double(max),
                step: step.map { Double($0) }
            )
            // 返回安全的默认 range
            return min...(min + 1)
        }

        return range
    }

    // 安全的 step
    private var safeStep: V.Stride {
        guard let step = step else {
            return 1
        }

        if step <= 0 || !step.isFinite {
            SliderDiagnostics.recordInvalidStep(Double(step))
            return 1
        }

        return step
    }

    // 安全的 value
    private var safeValue: V {
        var v = value

        // 检查 NaN 或 infinity
        if !v.isFinite {
            SliderDiagnostics.recordInvalidValue(Double(v))
            v = safeRange.lowerBound
        }

        // clamp 到范围内
        return Swift.min(Swift.max(v, safeRange.lowerBound), safeRange.upperBound)
    }

    // 是否可以安全渲染
    private var canRender: Bool {
        let min = range.lowerBound
        let max = range.upperBound

        // 基本检查
        guard max > min else { return false }
        guard min.isFinite && max.isFinite else { return false }

        // step 检查
        if let step = step {
            guard step > 0 && step.isFinite else { return false }
        }

        return true
    }

    // MARK: - Init

    init(
        value: Binding<V>,
        in range: ClosedRange<V>,
        step: V.Stride? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
    }

    // MARK: - Body

    var body: some View {
        if canRender {
            if step != nil {
                Slider(
                    value: Binding(
                        get: { safeValue },
                        set: { newValue in
                            guard newValue.isFinite else { return }
                            value = newValue
                        }
                    ),
                    in: safeRange,
                    step: safeStep,
                    onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    }
                )
            } else {
                Slider(
                    value: Binding(
                        get: { safeValue },
                        set: { newValue in
                            guard newValue.isFinite else { return }
                            value = newValue
                        }
                    ),
                    in: safeRange,
                    onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    }
                )
            }
        } else {
            // 无法渲染时显示占位 UI
            SliderPlaceholder(
                min: range.lowerBound,
                max: range.upperBound,
                step: step
            )
        }
    }
}

// MARK: - SliderPlaceholder

/// Slider 无法渲染时的占位 UI
private struct SliderPlaceholder<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    let min: V
    let max: V
    let step: V.Stride?

    var body: some View {
        HStack {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)
                .overlay(
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 20, height: 20),
                    alignment: .leading
                )
        }
        .onAppear {
            // 在占位 UI 出现时记录诊断
            SliderDiagnostics.recordPlaceholderShown(
                min: Double(min),
                max: Double(max),
                step: step.map { Double($0) }
            )
        }
    }
}

// MARK: - SafeSlider 便捷初始化

extension SafeSlider where V == Double {
    /// 页码 Slider 便捷初始化
    /// - Parameters:
    ///   - page: 当前页码绑定
    ///   - totalPages: 总页数
    static func pageSlider(
        page: Binding<Int>,
        totalPages: Int,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) -> SafeSlider {
        SafeSlider(
            value: Binding(
                get: { Double(page.wrappedValue) },
                set: { page.wrappedValue = Int($0) }
            ),
            in: 1...Double(max(1, totalPages)),
            step: 1,
            onEditingChanged: onEditingChanged
        )
    }
}

// MARK: - SliderDiagnostics

/// Slider 诊断记录器
final class SliderDiagnostics {
    static let shared = SliderDiagnostics()

    private let lock = NSLock()
    private var diagnostics: [SliderDiagnostic] = []
    private let maxCount = 50

    private init() {}

    struct SliderDiagnostic: Codable {
        let timestamp: Date
        let type: String
        let min: Double?
        let max: Double?
        let step: Double?
        let value: Double?
        let file: String
        let line: Int
        let message: String
    }

    // MARK: - 记录方法

    static func recordInvalidRange(
        min: Double,
        max: Double,
        step: Double?,
        file: String = #file,
        line: Int = #line
    ) {
        shared.record(
            type: "invalid_range",
            min: min,
            max: max,
            step: step,
            value: nil,
            file: file,
            line: line,
            message: "Invalid range: min(\(min)) >= max(\(max))"
        )
    }

    static func recordInvalidStep(
        _ step: Double,
        file: String = #file,
        line: Int = #line
    ) {
        shared.record(
            type: "invalid_step",
            min: nil,
            max: nil,
            step: step,
            value: nil,
            file: file,
            line: line,
            message: "Invalid step: \(step) (must be > 0 and finite)"
        )
    }

    static func recordInvalidValue(
        _ value: Double,
        file: String = #file,
        line: Int = #line
    ) {
        shared.record(
            type: "invalid_value",
            min: nil,
            max: nil,
            step: nil,
            value: value,
            file: file,
            line: line,
            message: "Invalid value: \(value) (NaN or infinity)"
        )
    }

    static func recordPlaceholderShown(
        min: Double,
        max: Double,
        step: Double?,
        file: String = #file,
        line: Int = #line
    ) {
        shared.record(
            type: "placeholder_shown",
            min: min,
            max: max,
            step: step,
            value: nil,
            file: file,
            line: line,
            message: "Slider placeholder shown due to invalid params"
        )

        // 同时记录 FreezeSnapshot
        let snapshot = FreezeSnapshot.capture(
            reason: "SafeSlider: invalid params (min=\(min), max=\(max), step=\(String(describing: step)))",
            level: .none,
            currentScreen: (file as NSString).lastPathComponent
        )
        FreezeSnapshotStorage.shared.save(snapshot)
    }

    private func record(
        type: String,
        min: Double?,
        max: Double?,
        step: Double?,
        value: Double?,
        file: String,
        line: Int,
        message: String
    ) {
        lock.lock()
        defer { lock.unlock() }

        let diagnostic = SliderDiagnostic(
            timestamp: Date(),
            type: type,
            min: min,
            max: max,
            step: step,
            value: value,
            file: (file as NSString).lastPathComponent,
            line: line,
            message: message
        )

        diagnostics.append(diagnostic)

        // 限制数量
        if diagnostics.count > maxCount {
            diagnostics.removeFirst()
        }

        // 输出日志
        appLog("[SafeSlider] \(message)")

        #if DEBUG
        #if DEBUG
        print("[SafeSlider WARNING] \(message) at \((file as NSString).lastPathComponent):\(line)")
        #endif
        #endif
    }

    // MARK: - 导出

    func getAllDiagnostics() -> [SliderDiagnostic] {
        lock.lock()
        defer { lock.unlock() }
        return diagnostics
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        diagnostics.removeAll()
    }
}

// MARK: - Preview

#if DEBUG
struct SafeSlider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // 正常情况
            SafeSliderPreviewWrapper(
                title: "正常 Slider",
                initialValue: 5,
                range: 1...10
            )

            // 无效 range (max <= min)
            SafeSliderPreviewWrapper(
                title: "无效 range (max <= min)",
                initialValue: 5,
                range: 10...1
            )

            // totalPages = 0
            SafeSliderPreviewWrapper(
                title: "totalPages = 0",
                initialValue: 1,
                range: 1...0
            )
        }
        .padding()
    }
}

private struct SafeSliderPreviewWrapper: View {
    let title: String
    @State var value: Double
    let range: ClosedRange<Double>

    init(title: String, initialValue: Double, range: ClosedRange<Double>) {
        self.title = title
        self._value = State(initialValue: initialValue)
        self.range = range
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            SafeSlider(value: $value, in: range, step: 1)

            Text("Value: \(Int(value))")
                .font(.caption2)
        }
    }
}
#endif

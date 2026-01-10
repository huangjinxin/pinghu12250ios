//
//  ChartComponents.swift
//  pinghu12250
//
//  炫酷图表组件 - 带动画效果
//

import SwiftUI
import Charts

// MARK: - 环形进度视图

struct RingProgressView: View {
    let progress: Double  // 0.0 - 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let gradientColors: [Color]
    let animate: Bool

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        size: CGFloat = 120,
        lineWidth: CGFloat = 12,
        gradientColors: [Color] = [.green, .mint],
        animate: Bool = true
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.gradientColors = gradientColors
        self.animate = animate
    }

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // 进度圆环
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedProgress)

            // 发光效果
            Circle()
                .trim(from: max(0, animatedProgress - 0.02), to: animatedProgress)
                .stroke(gradientColors.last ?? .green, lineWidth: lineWidth + 4)
                .blur(radius: 6)
                .rotationEffect(.degrees(-90))
                .opacity(0.5)
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedProgress)

            // 端点小球
            Circle()
                .fill(gradientColors.last ?? .green)
                .frame(width: lineWidth + 4, height: lineWidth + 4)
                .offset(y: -size / 2)
                .rotationEffect(.degrees(animatedProgress * 360 - 90))
                .shadow(color: gradientColors.last?.opacity(0.5) ?? .green.opacity(0.5), radius: 4)
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedProgress)
        }
        .frame(width: size, height: size)
        .onAppear {
            if animate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animatedProgress = progress
                }
            } else {
                animatedProgress = progress
            }
        }
        .onChange(of: animate) { _, newValue in
            if newValue {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - 通过率环形卡片

struct PassRateRingCard: View {
    let passRate: Int
    let total: Int
    let approved: Int
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.appPrimary)
                Text("通过率")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                // 环形进度
                ZStack {
                    RingProgressView(
                        progress: Double(passRate) / 100.0,
                        size: 100,
                        lineWidth: 10,
                        gradientColors: passRateColors,
                        animate: animate
                    )

                    // 中心数字
                    VStack(spacing: 2) {
                        AnimatedNumber(value: passRate, suffix: "%", animate: animate)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(passRateTextColor)

                        Text("通过率")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 统计数字
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(icon: "checkmark.circle.fill", label: "已通过", value: approved, color: .green, animate: animate)
                    StatRow(icon: "doc.text.fill", label: "总提交", value: total, color: .blue, animate: animate)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var passRateColors: [Color] {
        if passRate >= 80 {
            return [.green, .mint]
        } else if passRate >= 60 {
            return [.yellow, .orange]
        } else {
            return [.orange, .red]
        }
    }

    private var passRateTextColor: Color {
        if passRate >= 80 {
            return .green
        } else if passRate >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    let animate: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            AnimatedNumber(value: value, animate: animate)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 动画数字

struct AnimatedNumber: View {
    let value: Int
    var suffix: String = ""
    let animate: Bool

    @State private var displayValue: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            Text("\(displayValue)")
            if !suffix.isEmpty {
                Text(suffix)
            }
        }
        .onAppear {
            if animate {
                animateValue()
            } else {
                displayValue = value
            }
        }
        .onChange(of: animate) { _, newValue in
            if newValue {
                animateValue()
            }
        }
    }

    private func animateValue() {
        displayValue = 0
        let duration: Double = 0.8
        let steps = min(abs(value), 40)
        guard steps > 0 else {
            displayValue = value
            return
        }

        let stepValue = value / steps
        let interval = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayValue = min(i * stepValue, value)
                    if i == steps {
                        displayValue = value
                    }
                }
            }
        }
    }
}

// MARK: - 增强趋势图

struct EnhancedTrendChart: View {
    let trend: [TrendItem]
    let animate: Bool

    @State private var selectedItem: TrendItem?
    @State private var showTooltip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.appPrimary)
                Text("近7天趋势")
                    .font(.headline)
                Spacer()

                // 总计
                if let total = trend.reduce(0, { $0 + $1.submitted }) as Int? {
                    Text("共 \(total) 次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Chart {
                ForEach(trend) { item in
                    // 区域填充
                    AreaMark(
                        x: .value("日期", item.shortDate),
                        y: .value("提交数", animate ? item.submitted : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // 折线
                    LineMark(
                        x: .value("日期", item.shortDate),
                        y: .value("提交数", animate ? item.submitted : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    // 数据点
                    PointMark(
                        x: .value("日期", item.shortDate),
                        y: .value("提交数", animate ? item.submitted : 0)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(item.id == selectedItem?.id ? 120 : 60)
                    .annotation(position: .top) {
                        if item.id == selectedItem?.id && showTooltip {
                            VStack(spacing: 2) {
                                Text("\(item.submitted)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(item.shortDate)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                            .shadow(radius: 2)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: String = proxy.value(atX: x) {
                                        if let item = trend.first(where: { $0.shortDate == date }) {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                selectedItem = item
                                                showTooltip = true
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showTooltip = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        selectedItem = nil
                                    }
                                }
                        )
                }
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 3D 效果饼图

struct Enhanced3DPieChart: View {
    let data: [PieSlice]
    let animate: Bool

    @State private var selectedSlice: PieSlice?
    @State private var rotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.appPrimary)
                Text("状态分布")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                // 3D 饼图
                ZStack {
                    // 阴影层（3D效果）
                    Chart(data) { slice in
                        SectorMark(
                            angle: .value("数量", animate ? slice.value : 0),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color.opacity(0.3))
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    .offset(x: 3, y: 3)
                    .blur(radius: 2)

                    // 主饼图
                    Chart(data) { slice in
                        SectorMark(
                            angle: .value("数量", animate ? slice.value : 0),
                            innerRadius: .ratio(0.5),
                            outerRadius: selectedSlice?.id == slice.id ? .ratio(1.05) : .ratio(0.95),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        if animate {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                rotation = 360
                            }
                        }
                    }

                    // 中心装饰
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Image(systemName: "chart.pie")
                        .font(.title2)
                        .foregroundColor(.appPrimary)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSlice?.id)

                // 图例
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(data) { slice in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(slice.color)
                                .frame(width: 14, height: 14)
                                .shadow(color: slice.color.opacity(0.5), radius: 2)

                            Text(slice.label)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(slice.value))")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("(\(Int(slice.percentage))%)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedSlice?.id == slice.id ? slice.color.opacity(0.15) : Color.clear)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedSlice?.id == slice.id {
                                    selectedSlice = nil
                                } else {
                                    selectedSlice = slice
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 增强柱状图

struct EnhancedBarChart: View {
    let items: [CheckInItem]
    let getStats: (CheckInItem) -> TemplateStats?
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.appPrimary)
                Text("各项目统计")
                    .font(.headline)
                Spacer()
            }

            // 自定义柱状图（更炫酷的效果）
            HStack(alignment: .bottom, spacing: 20) {
                ForEach(items) { item in
                    if let stats = getStats(item) {
                        VStack(spacing: 8) {
                            // 堆叠柱子
                            GeometryReader { geo in
                                let total = CGFloat(stats.approved + stats.pending + stats.rejected)
                                let maxHeight = geo.size.height
                                let scale = total > 0 ? maxHeight / max(total, 1) : 0

                                VStack(spacing: 2) {
                                    Spacer()

                                    // 退回（顶部）
                                    if stats.rejected > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.red, .red.opacity(0.7)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: animate ? CGFloat(stats.rejected) * scale : 0)
                                            .shadow(color: .red.opacity(0.3), radius: 2, y: 2)
                                    }

                                    // 待审
                                    if stats.pending > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.orange, .yellow],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: animate ? CGFloat(stats.pending) * scale : 0)
                                            .shadow(color: .orange.opacity(0.3), radius: 2, y: 2)
                                    }

                                    // 通过（底部）
                                    if stats.approved > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.green, .mint],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: animate ? CGFloat(stats.approved) * scale : 0)
                                            .shadow(color: .green.opacity(0.3), radius: 2, y: 2)
                                    }
                                }
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(items.firstIndex(where: { $0.id == item.id }) ?? 0) * 0.1), value: animate)
                            }
                            .frame(height: 120)

                            // 数字
                            Text("\(stats.total)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(item.color)

                            // 标签
                            Text(item.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // 图例
            HStack(spacing: 16) {
                LegendDot(color: .green, label: "通过")
                LegendDot(color: .orange, label: "待审")
                LegendDot(color: .red, label: "退回")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            RingProgressView(progress: 0.75, animate: true)

            PassRateRingCard(passRate: 85, total: 45, approved: 38, animate: true)

            Enhanced3DPieChart(
                data: [
                    PieSlice(label: "通过", value: 45, color: .green, percentage: 60),
                    PieSlice(label: "待审", value: 8, color: .orange, percentage: 11),
                    PieSlice(label: "退回", value: 3, color: .red, percentage: 4)
                ],
                animate: true
            )
        }
        .padding()
    }
}

//
//  MiTianGridView.swift
//  pinghu12250
//
//  米字格/田字格视图组件
//  用于生词卡片和书写练习的格子背景
//

import SwiftUI

/// 米字格/田字格视图
struct MiTianGridView: View {
    /// 显示的汉字（可选）
    let character: String?
    /// 格子类型
    let gridType: GridType
    /// 格子尺寸
    let size: CGFloat
    /// 是否显示字符
    var showCharacter: Bool = true
    /// 字符透明度（临摹模式使用）
    var characterOpacity: Double = 1.0
    /// 字符颜色
    var characterColor: Color = Color(red: 0.8, green: 0, blue: 0)  // 正红色 #CC0000

    var body: some View {
        ZStack {
            // 格子背景
            Canvas { context, size in
                drawGrid(context: context, size: size)
            }
            .frame(width: size, height: size)

            // 汉字
            if showCharacter, let char = character, !char.isEmpty {
                Text(char)
                    .font(.system(size: size * 0.6, weight: .medium, design: .serif))
                    .foregroundColor(characterColor.opacity(characterOpacity))
            }
        }
        .frame(width: size, height: size)
    }

    /// 绘制格子
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let padding: CGFloat = 2

        // 填充米黄色背景
        let bgRect = CGRect(x: 0, y: 0, width: w, height: h)
        context.fill(Path(bgRect), with: .color(Color(hex: "FDF5E6")))

        // 绘制外框 - 深黑色
        var borderPath = Path()
        borderPath.addRect(CGRect(x: padding, y: padding, width: w - padding * 2, height: h - padding * 2))
        context.stroke(borderPath, with: .color(.black.opacity(0.9)), lineWidth: 2)

        // 绘制内部线条 - 暗红色虚线
        let lineColor = Color(red: 0.8, green: 0.36, blue: 0.36)  // #CD5C5C

        // 虚线样式
        let dashStyle = StrokeStyle(lineWidth: 1, dash: [6, 6])

        // 横线（中间）
        var hLine = Path()
        hLine.move(to: CGPoint(x: 0, y: h / 2))
        hLine.addLine(to: CGPoint(x: w, y: h / 2))
        context.stroke(hLine, with: .color(lineColor), style: dashStyle)

        // 竖线（中间）
        var vLine = Path()
        vLine.move(to: CGPoint(x: w / 2, y: 0))
        vLine.addLine(to: CGPoint(x: w / 2, y: h))
        context.stroke(vLine, with: .color(lineColor), style: dashStyle)

        // 米字格额外的对角线
        if gridType == .mi {
            // 左上到右下
            var diag1 = Path()
            diag1.move(to: CGPoint(x: 0, y: 0))
            diag1.addLine(to: CGPoint(x: w, y: h))
            context.stroke(diag1, with: .color(lineColor), style: dashStyle)

            // 右上到左下
            var diag2 = Path()
            diag2.move(to: CGPoint(x: w, y: 0))
            diag2.addLine(to: CGPoint(x: 0, y: h))
            context.stroke(diag2, with: .color(lineColor), style: dashStyle)
        }
    }
}

// MARK: - 预览

#Preview("米字格") {
    MiTianGridView(character: "春", gridType: .mi, size: 120)
}

#Preview("田字格") {
    MiTianGridView(character: "夏", gridType: .tian, size: 120)
}

#Preview("临摹模式") {
    MiTianGridView(character: "秋", gridType: .mi, size: 300, characterOpacity: 0.15)
}

// MARK: - 米字格背景（无文字）

/// 米字格背景视图（仅显示格子，不显示文字）
struct MiTianGridBackground: View {
    let size: CGFloat
    var gridType: GridType = .mi

    var body: some View {
        MiTianGridView(
            character: nil,
            gridType: gridType,
            size: size,
            showCharacter: false
        )
    }
}

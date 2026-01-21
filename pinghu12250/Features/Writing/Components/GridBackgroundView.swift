//
//  GridBackgroundView.swift
//  pinghu12250
//
//  米字格/田字格背景组件
//

import SwiftUI

struct GridBackgroundView: View {
    let gridType: GridType
    let lineColor: Color
    let lineWidth: CGFloat

    init(gridType: GridType = .mi, lineColor: Color = .gray.opacity(0.3), lineWidth: CGFloat = 1) {
        self.gridType = gridType
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Canvas { context, canvasSize in
                let rect = CGRect(x: (canvasSize.width - size) / 2,
                                  y: (canvasSize.height - size) / 2,
                                  width: size, height: size)

                // 外框
                context.stroke(
                    Path(rect),
                    with: .color(lineColor),
                    lineWidth: lineWidth * 2
                )

                // 十字线
                var crossPath = Path()
                crossPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
                crossPath.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                crossPath.move(to: CGPoint(x: rect.minX, y: rect.midY))
                crossPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                context.stroke(crossPath, with: .color(lineColor), lineWidth: lineWidth)

                // 米字格额外的对角线
                if gridType == .mi {
                    var diagonalPath = Path()
                    diagonalPath.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    diagonalPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    diagonalPath.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                    diagonalPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    context.stroke(
                        diagonalPath,
                        with: .color(lineColor),
                        style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
                    )
                }
            }
        }
    }
}

#Preview {
    HStack {
        GridBackgroundView(gridType: .mi)
            .frame(width: 150, height: 150)
        GridBackgroundView(gridType: .tian)
            .frame(width: 150, height: 150)
    }
    .padding()
}

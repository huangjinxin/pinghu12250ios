//
//  WritingCanvasView.swift
//  pinghu12250
//
//  PencilKit书写画布
//  支持手指和Apple Pencil输入
//  导出与Web端兼容的笔画数据格式
//

import SwiftUI
import PencilKit
import Combine

/// PencilKit书写画布视图
struct WritingCanvasView: UIViewRepresentable {
    /// 笔画数据（绑定）
    @Binding var strokeData: StrokeData
    /// 笔宽
    var penWidth: CGFloat = 4
    /// 笔色
    var penColor: Color = .black
    /// 画布尺寸
    var canvasSize: CGSize = CGSize(width: 300, height: 300)
    /// 绘制变化回调
    var onDrawingChanged: (() -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput  // 支持手指和Apple Pencil

        // 设置画笔工具
        let ink = PKInkingTool(.pen, color: UIColor(penColor), width: penWidth)
        canvasView.tool = ink

        // 禁用滚动
        canvasView.isScrollEnabled = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false

        // 存储引用供后续使用
        context.coordinator.canvasView = canvasView

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // 更新画笔设置
        let ink = PKInkingTool(.pen, color: UIColor(penColor), width: penWidth)
        canvasView.tool = ink

        // 更新画布尺寸
        context.coordinator.canvasSize = canvasSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: WritingCanvasView
        weak var canvasView: PKCanvasView?
        var canvasSize: CGSize = CGSize(width: 300, height: 300)
        var currentPenWidth: CGFloat = 4  // 当前笔宽

        // 记录每笔的开始时间（用于时间戳计算）
        private var strokeStartTimes: [Int: Int64] = [:]

        init(_ parent: WritingCanvasView) {
            self.parent = parent
            self.currentPenWidth = parent.penWidth
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 更新当前笔宽
            currentPenWidth = parent.penWidth
            // 将 PKDrawing 转换为与Web兼容的 StrokeData 格式
            parent.strokeData = convertPKDrawingToStrokeData(
                canvasView.drawing,
                canvasSize: canvasSize
            )

            // 通知变化
            parent.onDrawingChanged?()
        }

        /// 关键方法：转换为Web兼容的笔画数据格式
        func convertPKDrawingToStrokeData(_ drawing: PKDrawing, canvasSize: CGSize) -> StrokeData {
            var strokes: [StrokeData.Stroke] = []
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            for (index, stroke) in drawing.strokes.enumerated() {
                var points: [StrokeData.Point] = []
                let path = stroke.path

                // 获取或创建该笔的开始时间
                let strokeStartTime: Int64
                if let cachedTime = strokeStartTimes[index] {
                    strokeStartTime = cachedTime
                } else {
                    // 新笔画，使用当前时间减去估算的偏移
                    strokeStartTime = now - Int64((drawing.strokes.count - index) * 1000)
                    strokeStartTimes[index] = strokeStartTime
                }

                for i in 0..<path.count {
                    let point = path[i]
                    let location = point.location

                    // 计算时间戳（基于点的位置估算时间进度）
                    let t = strokeStartTime + Int64(Double(i) / Double(max(path.count - 1, 1)) * 500)

                    points.append(StrokeData.Point(
                        x: location.x,
                        y: location.y,
                        t: t,
                        p: point.force > 0 ? point.force : nil
                    ))
                }

                // 生成唯一的stroke ID（与Web格式一致）
                let strokeId = "stroke_\(strokeStartTime)_\(UUID().uuidString.prefix(9))"

                // 使用当前笔宽（因为iOS 17+的PKInk没有width属性）
                strokes.append(StrokeData.Stroke(
                    id: strokeId,
                    color: stroke.ink.color.hexString,
                    lineWidth: currentPenWidth,
                    points: points
                ))
            }

            return StrokeData(
                version: STROKE_DATA_VERSION,
                canvas: StrokeData.CanvasSize(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    dpr: UIScreen.main.scale
                ),
                strokes: strokes,
                preview: nil
            )
        }

        /// 清除画布
        func clearCanvas() {
            canvasView?.drawing = PKDrawing()
            strokeStartTimes.removeAll()
        }

        /// 撤销最后一笔
        func undoLastStroke() {
            guard let canvasView = canvasView else { return }
            var drawing = canvasView.drawing
            if !drawing.strokes.isEmpty {
                drawing.strokes.removeLast()
                canvasView.drawing = drawing
                strokeStartTimes.removeValue(forKey: drawing.strokes.count)
            }
        }
    }
}

// MARK: - 画布控制器（供外部调用）

/// 画布控制器
class WritingCanvasController: ObservableObject {
    weak var coordinator: WritingCanvasView.Coordinator?

    func clearCanvas() {
        coordinator?.clearCanvas()
    }

    func undoLastStroke() {
        coordinator?.undoLastStroke()
    }
}

// MARK: - 带控制器的画布视图

/// 带控制器的书写画布
struct ControlledWritingCanvasView: View {
    @Binding var strokeData: StrokeData
    var penWidth: CGFloat = 4
    var penColor: Color = .black
    var canvasSize: CGSize = CGSize(width: 300, height: 300)
    @ObservedObject var controller: WritingCanvasController

    var body: some View {
        WritingCanvasView(
            strokeData: $strokeData,
            penWidth: penWidth,
            penColor: penColor,
            canvasSize: canvasSize
        )
        .onAppear {
            // 注意：这里需要在实际使用时设置coordinator
        }
    }
}

// MARK: - 预览

#Preview {
    struct PreviewWrapper: View {
        @State private var strokeData = StrokeData.empty()
        @State private var penWidth: CGFloat = 4
        @State private var penColor: Color = .black

        var body: some View {
            VStack {
                ZStack {
                    // 背景格子
                    MiTianGridView(character: nil, gridType: .mi, size: 300)

                    // 书写画布
                    WritingCanvasView(
                        strokeData: $strokeData,
                        penWidth: penWidth,
                        penColor: penColor,
                        canvasSize: CGSize(width: 300, height: 300)
                    )
                    .frame(width: 300, height: 300)
                }
                .frame(width: 300, height: 300)
                .cornerRadius(12)
                .shadow(radius: 4)

                // 工具栏
                HStack {
                    Text("笔宽: \(Int(penWidth))")
                    Slider(value: $penWidth, in: 2...12, step: 1)
                        .frame(width: 100)

                    ColorPicker("", selection: $penColor)
                        .labelsHidden()
                }
                .padding()

                // 笔画信息
                Text("笔画数: \(strokeData.strokes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

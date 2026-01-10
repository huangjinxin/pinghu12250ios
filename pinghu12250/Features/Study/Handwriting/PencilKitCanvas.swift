//
//  PencilKitCanvas.swift
//  pinghu12250
//
//  PencilKit 画布组件 - 支持 Apple Pencil 和手指手写
//

import SwiftUI
import PencilKit

// MARK: - 画布工具类型

enum CanvasTool: String, CaseIterable, Identifiable {
    case pen = "钢笔"
    case pencil = "铅笔"
    case marker = "马克笔"
    case eraser = "橡皮擦"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }

    func createTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: width)
        case .eraser:
            return PKEraserTool(.bitmap)
        }
    }
}

// MARK: - 画布颜色

struct CanvasColor: Identifiable, Equatable {
    let id = UUID()
    let color: UIColor
    let name: String

    static let presets: [CanvasColor] = [
        CanvasColor(color: .black, name: "黑色"),
        CanvasColor(color: .systemBlue, name: "蓝色"),
        CanvasColor(color: .systemRed, name: "红色"),
        CanvasColor(color: .systemGreen, name: "绿色"),
        CanvasColor(color: .systemOrange, name: "橙色"),
        CanvasColor(color: .systemPurple, name: "紫色"),
    ]
}

// MARK: - PencilKit 画布

struct PencilKitCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var drawing: PKDrawing
    let tool: CanvasTool
    let color: UIColor
    let lineWidth: CGFloat
    let backgroundColor: UIColor
    let isRulerActive: Bool
    let allowsFingerDrawing: Bool
    let onDrawingChanged: ((PKDrawing) -> Void)?

    init(
        canvasView: Binding<PKCanvasView>,
        drawing: Binding<PKDrawing>,
        tool: CanvasTool = .pen,
        color: UIColor = .black,
        lineWidth: CGFloat = 3,
        backgroundColor: UIColor = .white,
        isRulerActive: Bool = false,
        allowsFingerDrawing: Bool = true,
        onDrawingChanged: ((PKDrawing) -> Void)? = nil
    ) {
        self._canvasView = canvasView
        self._drawing = drawing
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
        self.isRulerActive = isRulerActive
        self.allowsFingerDrawing = allowsFingerDrawing
        self.onDrawingChanged = onDrawingChanged
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.tool = tool.createTool(color: color, width: lineWidth)
        canvasView.backgroundColor = backgroundColor
        canvasView.isRulerActive = isRulerActive
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvasView.isOpaque = false
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false

        // 设置最小缩放
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 3.0

        // 确保 canvasView 成为第一响应者以接收 Apple Pencil 输入
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 更新工具
        uiView.tool = tool.createTool(color: color, width: lineWidth)
        uiView.isRulerActive = isRulerActive
        uiView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly

        // 更新绘图（如果外部改变）
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }

        // 确保 canvasView 保持第一响应者状态以接收 Apple Pencil 输入
        if !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitCanvas

        init(_ parent: PencilKitCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
                self.parent.onDrawingChanged?(canvasView.drawing)
            }
        }
    }
}

// MARK: - 画布工具栏

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: CanvasColor
    @Binding var lineWidth: CGFloat
    @Binding var isRulerActive: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void

    @State private var showColorPicker = false
    @State private var showWidthPicker = false

    var body: some View {
        HStack(spacing: 12) {
            // 工具选择
            ForEach(CanvasTool.allCases) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 24)

            // 颜色选择
            Button {
                showColorPicker.toggle()
            } label: {
                Circle()
                    .fill(Color(selectedColor.color))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    )
            }
            .popover(isPresented: $showColorPicker) {
                colorPickerView
            }

            // 线宽选择
            Button {
                showWidthPicker.toggle()
            } label: {
                Image(systemName: "lineweight")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            .popover(isPresented: $showWidthPicker) {
                widthPickerView
            }

            Divider()
                .frame(height: 24)

            // 标尺
            Button {
                isRulerActive.toggle()
            } label: {
                Image(systemName: "ruler")
                    .font(.system(size: 18))
                    .foregroundColor(isRulerActive ? .appPrimary : .primary)
            }

            Spacer()

            // 撤销/重做
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18))
            }

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18))
            }

            // 清除
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func toolButton(_ tool: CanvasTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 20))
                .foregroundColor(selectedTool == tool ? .appPrimary : .primary)
                .frame(width: 36, height: 36)
                .background(selectedTool == tool ? Color.appPrimary.opacity(0.1) : Color.clear)
                .cornerRadius(8)
        }
    }

    private var colorPickerView: some View {
        VStack(spacing: 12) {
            Text("选择颜色")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 40))
            ], spacing: 12) {
                ForEach(CanvasColor.presets) { canvasColor in
                    Button {
                        selectedColor = canvasColor
                        showColorPicker = false
                    } label: {
                        Circle()
                            .fill(Color(canvasColor.color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColor.id == canvasColor.id
                                            ? Color.appPrimary
                                            : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                    }
                }
            }
        }
        .padding()
        .frame(width: 200)
    }

    private var widthPickerView: some View {
        VStack(spacing: 16) {
            Text("线条粗细")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach([1.0, 3.0, 5.0, 8.0, 12.0], id: \.self) { width in
                    Button {
                        lineWidth = width
                        showWidthPicker = false
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: width / 2)
                                .fill(Color(selectedColor.color))
                                .frame(width: 60, height: width)

                            Spacer()

                            if lineWidth == width {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding()
        .frame(width: 150)
    }
}

// MARK: - 画布视图（完整组件）

struct CanvasContainerView: View {
    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 3
    @State private var isRulerActive = false
    @State private var undoManager: UndoManager?

    let onSave: ((UIImage) -> Void)?
    let onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            CanvasToolbar(
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                lineWidth: $lineWidth,
                isRulerActive: $isRulerActive,
                onUndo: {
                    undoManager?.undo()
                },
                onRedo: {
                    undoManager?.redo()
                },
                onClear: {
                    drawing = PKDrawing()
                }
            )

            Divider()

            // 画布
            PencilKitCanvas(
                canvasView: $canvasView,
                drawing: $drawing,
                tool: selectedTool,
                color: selectedColor.color,
                lineWidth: lineWidth,
                isRulerActive: isRulerActive,
                onDrawingChanged: { _ in
                    // 可以在这里处理绘图变化
                }
            )
            .background(Color.white)
            .onAppear {
                undoManager = canvasView.undoManager
            }
        }
    }

    /// 导出为图片
    func exportAsImage() -> UIImage {
        let bounds = canvasView.bounds
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
}

// MARK: - 预览

#Preview {
    CanvasContainerView(
        onSave: { _ in },
        onCancel: {}
    )
}

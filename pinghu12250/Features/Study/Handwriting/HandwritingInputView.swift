//
//  HandwritingInputView.swift
//  pinghu12250
//
//  手写输入视图 - 用于 AI 对话的手写输入界面
//

import SwiftUI
import PencilKit

// MARK: - 手写输入模式

enum HandwritingMode {
    case draw      // 绘图模式（直接发送图片）
    case recognize // 识别模式（转为文字）
}

// MARK: - 手写输入视图

struct HandwritingInputView: View {
    @Environment(\.dismiss) var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 3
    @State private var isRulerActive = false
    @State private var mode: HandwritingMode = .draw

    // 识别状态
    @State private var isRecognizing = false
    @State private var recognizedText = ""
    @State private var showRecognitionResult = false

    // 回调
    let onSendImage: (UIImage) -> Void
    let onSendText: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模式切换
                modeSelector

                // 工具栏
                toolBar

                Divider()

                // 画布
                ZStack {
                    // 背景格子
                    GridPatternView()
                        .opacity(0.3)

                    PencilKitCanvas(
                        canvasView: $canvasView,
                        drawing: $drawing,
                        tool: selectedTool,
                        color: selectedColor.color,
                        lineWidth: lineWidth,
                        backgroundColor: .clear,
                        isRulerActive: isRulerActive
                    )
                }
                .background(Color.white)

                // 识别结果
                if showRecognitionResult {
                    recognitionResultView
                }

                Divider()

                // 底部操作栏
                bottomBar
            }
            .navigationTitle("手写输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 模式选择器

    private var modeSelector: some View {
        Picker("模式", selection: $mode) {
            Text("绘图").tag(HandwritingMode.draw)
            Text("识别文字").tag(HandwritingMode.recognize)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - 工具栏

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 工具选择
                ForEach(CanvasTool.allCases) { tool in
                    toolButton(tool)
                }

                Divider()
                    .frame(height: 28)

                // 颜色选择
                ForEach(CanvasColor.presets.prefix(4)) { canvasColor in
                    colorButton(canvasColor)
                }

                Divider()
                    .frame(height: 28)

                // 线宽
                HStack(spacing: 8) {
                    ForEach([2.0, 4.0, 6.0], id: \.self) { width in
                        widthButton(width)
                    }
                }

                Divider()
                    .frame(height: 28)

                // 撤销/重做
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                }

                Button {
                    canvasView.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                }

                // 清除
                Button {
                    drawing = PKDrawing()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .background(Color(.systemGray6))
    }

    private func toolButton(_ tool: CanvasTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 18))
                .foregroundColor(selectedTool == tool ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(selectedTool == tool ? Color.appPrimary : Color(.systemGray5))
                .cornerRadius(8)
        }
    }

    private func colorButton(_ canvasColor: CanvasColor) -> some View {
        Button {
            selectedColor = canvasColor
        } label: {
            Circle()
                .fill(Color(canvasColor.color))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(
                            selectedColor.id == canvasColor.id
                                ? Color.appPrimary
                                : Color.gray.opacity(0.3),
                            lineWidth: selectedColor.id == canvasColor.id ? 3 : 1
                        )
                )
        }
    }

    private func widthButton(_ width: CGFloat) -> some View {
        Button {
            lineWidth = width
        } label: {
            Circle()
                .fill(lineWidth == width ? Color.appPrimary : Color(.systemGray4))
                .frame(width: width * 3, height: width * 3)
        }
    }

    // MARK: - 识别结果视图

    private var recognitionResultView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("识别结果")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showRecognitionResult = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            if isRecognizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在识别...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                TextEditor(text: $recognizedText)
                    .font(.body)
                    .frame(height: 60)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if mode == .recognize {
                // 识别模式
                Button {
                    recognizeHandwriting()
                } label: {
                    HStack {
                        Image(systemName: "text.viewfinder")
                        Text("识别文字")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .disabled(drawing.strokes.isEmpty || isRecognizing)

                if !recognizedText.isEmpty {
                    Button {
                        onSendText(recognizedText)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("发送文字")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }
                }
            } else {
                // 绘图模式
                Button {
                    sendAsImage()
                } label: {
                    HStack {
                        Image(systemName: "photo")
                        Text("发送图片")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(drawing.strokes.isEmpty ? Color.gray : Color.appPrimary)
                    .cornerRadius(12)
                }
                .disabled(drawing.strokes.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 操作方法

    private func sendAsImage() {
        let image = exportDrawing()
        onSendImage(image)
        dismiss()
    }

    private func exportDrawing() -> UIImage {
        let bounds = canvasView.bounds
        let drawingImage = drawing.image(from: bounds, scale: UIScreen.main.scale)

        // 添加白色背景
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            drawingImage.draw(in: bounds)
        }
    }

    private func recognizeHandwriting() {
        isRecognizing = true
        showRecognitionResult = true

        // 使用 Vision 框架识别手写
        Task {
            let image = exportDrawing()
            let text = await HandwritingRecognizer.shared.recognize(image: image)

            await MainActor.run {
                recognizedText = text
                isRecognizing = false
            }
        }
    }
}

// MARK: - 网格背景

struct GridPatternView: View {
    let lineSpacing: CGFloat = 30
    let lineColor: Color = .gray.opacity(0.3)

    var body: some View {
        Canvas { context, size in
            let rows = Int(size.height / lineSpacing)
            let cols = Int(size.width / lineSpacing)

            // 横线
            for i in 0...rows {
                let y = CGFloat(i) * lineSpacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }

            // 竖线
            for i in 0...cols {
                let x = CGFloat(i) * lineSpacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - 紧凑手写按钮（用于输入框）

struct CompactHandwritingButton: View {
    @State private var showHandwriting = false
    let onSendImage: (UIImage) -> Void
    let onSendText: (String) -> Void

    var body: some View {
        Button {
            showHandwriting = true
        } label: {
            Image(systemName: "pencil.tip.crop.circle")
                .font(.system(size: 24))
                .foregroundColor(.appPrimary)
        }
        .sheet(isPresented: $showHandwriting) {
            HandwritingInputView(
                onSendImage: onSendImage,
                onSendText: onSendText
            )
        }
    }
}

// MARK: - 预览

#Preview {
    HandwritingInputView(
        onSendImage: { _ in },
        onSendText: { _ in }
    )
}

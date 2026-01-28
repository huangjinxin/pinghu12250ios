//
//  CalligraphyCanvasView.swift
//  pinghu12250
//
//  全屏书写画布视图
//

import SwiftUI
import PencilKit

struct CalligraphyCanvasView: View {
    @ObservedObject var viewModel: WritingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 5
    @State private var isRulerActive = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar

                Divider()

                // 绘图工具栏（原底部工具栏，移到上方防止误触）
                drawingToolbar

                Divider()

                // 画布区域
                ZStack {
                    // 背景
                    Color.white

                    // 米字格
                    GridBackgroundView(gridType: .mi, lineColor: .gray.opacity(0.3))

                    // 参考字
                    if let char = viewModel.currentChar {
                        ReferenceCharView(
                            character: char,
                            fontName: viewModel.registeredFontNames[viewModel.selectedFont?.id ?? ""],
                            opacity: 0.15
                        )
                    }

                    // PencilKit画布
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
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: min(geometry.size.width, geometry.size.height) * 0.9)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGray6))
        .overlay {
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("保存中...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("继续练习") {}
            Button("返回") { dismiss() }
        }
    }

    // MARK: - 顶部工具栏

    private var topToolbar: some View {
        HStack {
            Button("关闭") { dismiss() }

            Spacer()

            // 进度指示
            if !viewModel.practiceText.isEmpty {
                Text("\(viewModel.currentCharIndex + 1)/\(viewModel.practiceText.count)")
                    .font(.headline)

                ProgressView(value: viewModel.practiceProgress)
                    .frame(width: 100)
            }

            Spacer()

            Button("保存作品") {
                Task { await saveWork() }
            }
            .disabled(drawing.strokes.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 绘图工具栏（位于画布上方）

    private var drawingToolbar: some View {
        VStack(spacing: 12) {
            // 工具选择
            HStack(spacing: 16) {
                ForEach(CanvasTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.system(size: 22))
                            .foregroundColor(selectedTool == tool ? .appPrimary : .primary)
                            .frame(width: 44, height: 44)
                            .background(selectedTool == tool ? Color.appPrimary.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                    }
                }

                Divider().frame(height: 30)

                // 颜色选择
                ForEach(CanvasColor.presets.prefix(4)) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(Color(color.color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor.id == color.id ? Color.appPrimary : Color.clear, lineWidth: 3)
                            )
                    }
                }
            }

            // 操作按钮
            HStack(spacing: 20) {
                // 上一个字
                Button {
                    viewModel.previousChar()
                    clearCanvas()
                } label: {
                    Label("上一个", systemImage: "chevron.left")
                }
                .disabled(viewModel.currentCharIndex == 0)

                // 清除
                Button {
                    clearCanvas()
                } label: {
                    Label("清除", systemImage: "trash")
                        .foregroundColor(.red)
                }

                // 撤销
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }

                // 下一个字
                Button {
                    viewModel.nextChar()
                    clearCanvas()
                } label: {
                    Label("下一个", systemImage: "chevron.right")
                }
                .disabled(viewModel.currentCharIndex >= viewModel.practiceText.count - 1)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 操作

    private func clearCanvas() {
        drawing = PKDrawing()
        canvasView.drawing = PKDrawing()
    }

    private func saveWork() async {
        isSaving = true
        defer { isSaving = false }

        // 导出图片
        let bounds = canvasView.bounds
        let image = drawing.image(from: bounds, scale: UIScreen.main.scale)

        let success = await viewModel.saveWork(
            content: viewModel.practiceText,
            image: image,
            drawing: drawing,
            canvasSize: bounds.size
        )

        if success {
            showSaveSuccess = true
        }
    }
}

#Preview {
    CalligraphyCanvasView(viewModel: {
        let vm = WritingViewModel()
        vm.practiceText = "永字八法"
        return vm
    }())
}

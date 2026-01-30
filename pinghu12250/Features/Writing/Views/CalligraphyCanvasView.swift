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
    @State private var isPencilOnly = false
    @State private var isRulerActive = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧工具栏
                leftToolbar
                    .frame(width: 80)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color(.systemGray5)),
                        alignment: .trailing
                    )
                
                // 中间画布区域
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
                        isRulerActive: isRulerActive,
                        allowsFingerDrawing: !isPencilOnly
                    )
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
                
                // 右侧历史/列表区域
                rightHistoryPanel
                    .frame(width: 120)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color(.systemGray5)),
                        alignment: .leading
                    )
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

    // MARK: - 左侧工具栏

    private var leftToolbar: some View {
        VStack(spacing: 16) {
            // 关闭按钮 (Top)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
            .padding(.top, 16)

            Divider()

            // Apple Pencil 模式切换
            Button {
                isPencilOnly.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isPencilOnly ? "applepencil" : "hand.draw")
                        .font(.system(size: 22))
                        .foregroundColor(isPencilOnly ? .appPrimary : .primary)
                    Text(isPencilOnly ? "Pencil" : "手写")
                        .font(.caption2)
                }
            }

            Divider()

            // 工具选择 (Vertical)
            VStack(spacing: 12) {
                ForEach(CanvasTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTool == tool ? .appPrimary : .primary)
                            .frame(width: 40, height: 40)
                            .background(selectedTool == tool ? Color.appPrimary.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            // 粗细滑块
            VStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)

                // 垂直滑块
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // 背景轨道
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 8)

                        // 填充轨道
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appPrimary)
                            .frame(width: 8, height: geo.size.height * (lineWidth / 30))

                        // 拖动手柄
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .offset(y: -geo.size.height * (lineWidth / 30) + 10)
                    }
                    .frame(maxWidth: .infinity)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newValue = 30 * (1 - value.location.y / geo.size.height)
                                lineWidth = max(1, min(30, newValue))
                            }
                    )
                }
                .frame(width: 40, height: 80)

                Text("\(Int(lineWidth))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 颜色选择 - 色彩按钮
            VStack(spacing: 8) {
                ForEach(CanvasColor.presets) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(Color(color.color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColor.id == color.id ? Color.appPrimary : Color.gray.opacity(0.3),
                                        lineWidth: selectedColor.id == color.id ? 3 : 1
                                    )
                            )
                            .scaleEffect(selectedColor.id == color.id ? 1.1 : 1.0)
                    }
                }
            }

            Spacer()

            // 撤销/清除
            VStack(spacing: 12) {
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 20))
                }

                Button {
                    clearCanvas()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - 右侧列表区域
    
    private var rightHistoryPanel: some View {
        VStack {
            Text("所有文字")
                .font(.headline)
                .padding(.top, 20)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.practiceText.enumerated()), id: \.offset) { index, char in
                        Button {
                            // Jump to char
                            if index != viewModel.currentCharIndex {
                                // Save current before switch? simplified for now just switch
                                viewModel.jumpToChar(index)
                                clearCanvas() // Reset canvas for new char
                            }
                        } label: {
                            Text(String(char))
                                .font(.title3)
                                .frame(width: 50, height: 50)
                                .background(viewModel.currentCharIndex == index ? Color.appPrimary.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(viewModel.currentCharIndex == index ? Color.appPrimary : Color(.systemGray4), lineWidth: 1)
                                )
                                .foregroundColor(viewModel.currentCharIndex == index ? .appPrimary : .primary)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            Button("保存当前") {
                Task { await saveWork() }
            }
            .padding()
            .disabled(drawing.strokes.isEmpty)
        }
    }

    private func clearCanvas() {
        drawing = PKDrawing()
        canvasView.drawing = PKDrawing()
    }

    private func saveWork() async {
        isSaving = true
        defer { isSaving = false }

        // 导出图片（带白色背景，确保Web端显示正常）
        let bounds = canvasView.bounds
        let scale = UIScreen.main.scale

        // 创建带白色背景的图片
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            // 填充白色背景
            UIColor.white.setFill()
            context.fill(bounds)
            // 绘制笔画
            drawing.image(from: bounds, scale: scale).draw(in: bounds)
        }

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

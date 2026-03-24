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
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 5
    @State private var isPencilOnly = false
    @State private var isRulerActive = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

    // 逐字暂存（与Web端completedRecords对齐）
    @State private var charDrawings: [Int: PKDrawing] = [:]
    @State private var completedRecords: [CompletedCharRecord] = []

    struct CompletedCharRecord {
        let character: String
        let strokeData: StrokeDataV2
        let preview: String  // base64
    }

    private var isCompact: Bool { hSizeClass == .compact }

    var body: some View {
        GeometryReader { geometry in
            if isCompact {
                portraitLayout
            } else {
                landscapeLayout
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

    // MARK: - 横屏/iPad布局（原布局）

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            leftToolbar
                .frame(width: 80)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle().frame(width: 1).foregroundColor(Color(.systemGray5)),
                    alignment: .trailing
                )
            canvasArea.padding(20)
            rightHistoryPanel
                .frame(width: 120)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle().frame(width: 1).foregroundColor(Color(.systemGray5)),
                    alignment: .leading
                )
        }
    }

    // MARK: - 竖屏iPhone布局

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            compactToolbar
            // 画布
            canvasArea.padding(8)
            // 底部字符条 + 保存
            compactBottomBar
        }
    }

    // MARK: - 共用画布区域

    private var canvasArea: some View {
        ZStack {
            Color.white
            GridBackgroundView(gridType: .mi, lineColor: .gray.opacity(0.3))
            if let char = viewModel.currentChar {
                ReferenceCharView(
                    character: char,
                    fontName: viewModel.registeredFontNames[viewModel.selectedFont?.id ?? ""],
                    opacity: 0.15
                )
            }
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
                    canvasView.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
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
            Text("已完成")
                .font(.headline)
                .padding(.top, 20)

            Text("\(completedRecords.count)/\(viewModel.practiceText.filter { !$0.isWhitespace }.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.practiceText.filter { !$0.isWhitespace }.enumerated()), id: \.offset) { index, char in
                        Button {
                            switchToChar(index)
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(char))
                                    .font(.title3)
                                    .frame(width: 50, height: 50)
                                    .background(viewModel.currentCharIndex == index ? Color.appPrimary.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(viewModel.currentCharIndex == index ? Color.appPrimary : Color(.systemGray4), lineWidth: 1)
                                    )
                                    .foregroundColor(viewModel.currentCharIndex == index ? .appPrimary : .primary)
                                // 已完成标记
                                if completedRecords.contains(where: { $0.character == String(char) }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 保存并下一个（与Web端一致）
            Button {
                Task { await saveCharAndNext() }
            } label: {
                Text(isLastChar ? "保存并完成" : "保存并下一个")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(drawing.strokes.isEmpty)
            .padding(.horizontal, 8)

            Button("跳过") {
                skipToNext()
            }
            .font(.caption)
            .disabled(isLastChar)
            .padding(.bottom, 8)
            .disabled(drawing.strokes.isEmpty)
        }
    }

    // MARK: - 竖屏顶部工具栏

    private var compactToolbar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray)
            }

            Divider().frame(height: 28)

            ForEach(CanvasTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundColor(selectedTool == tool ? .appPrimary : .primary)
                        .frame(width: 36, height: 36)
                        .background(selectedTool == tool ? Color.appPrimary.opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                }
            }

            Divider().frame(height: 28)

            // 颜色
            ForEach(CanvasColor.presets) { color in
                Button { selectedColor = color } label: {
                    Circle().fill(Color(color.color)).frame(width: 24, height: 24)
                        .overlay(Circle().stroke(selectedColor.id == color.id ? Color.appPrimary : Color.clear, lineWidth: 2))
                }
            }

            Spacer()

            Button { canvasView.undoManager?.undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 18))
            }
            Button { canvasView.undoManager?.redo() } label: {
                Image(systemName: "arrow.uturn.forward").font(.system(size: 18))
            }
            Button { clearCanvas() } label: {
                Image(systemName: "trash").font(.system(size: 18)).foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 竖屏底部字符条

    private var compactBottomBar: some View {
        VStack(spacing: 8) {
            // 横向字符列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { index, char in
                        Button { switchToChar(index) } label: {
                            Text(String(char))
                                .font(.body)
                                .frame(width: 40, height: 40)
                                .background(viewModel.currentCharIndex == index ? Color.appPrimary.opacity(0.15) : Color(.systemGray6))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(viewModel.currentCharIndex == index ? Color.appPrimary : Color.clear, lineWidth: 2)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if completedRecords.contains(where: { $0.character == String(char) }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            // 保存按钮
            HStack(spacing: 12) {
                Text("\(completedRecords.count)/\(characters.count)")
                    .font(.caption).foregroundColor(.secondary)

                Spacer()

                if !isLastChar {
                    Button("跳过") { skipToNext() }
                        .font(.subheadline)
                }

                Button {
                    Task { await saveCharAndNext() }
                } label: {
                    Text(isLastChar ? "保存并完成" : "下一个")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.borderedProminent)
                .disabled(drawing.strokes.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    private var characters: [Character] {
        viewModel.practiceText.filter { !$0.isWhitespace }.map { $0 }
    }

    private var isLastChar: Bool {
        viewModel.currentCharIndex >= characters.count - 1
    }

    private func clearCanvas() {
        drawing = PKDrawing()
        canvasView.drawing = PKDrawing()
    }

    /// 切换字符时暂存当前笔画、恢复目标笔画
    private func switchToChar(_ index: Int) {
        guard index != viewModel.currentCharIndex else { return }
        // 暂存当前
        charDrawings[viewModel.currentCharIndex] = drawing
        // 切换
        viewModel.jumpToChar(index)
        // 恢复目标
        let restored = charDrawings[index] ?? PKDrawing()
        drawing = restored
        canvasView.drawing = restored
    }

    private func skipToNext() {
        guard !isLastChar else { return }
        switchToChar(viewModel.currentCharIndex + 1)
    }

    /// 导出当前画布为 base64 PNG 预览图
    private func exportPreview() -> String? {
        let bounds = canvasView.bounds
        guard bounds.size.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            drawing.image(from: bounds, scale: UIScreen.main.scale).draw(in: bounds)
        }
        guard let data = image.pngData() else { return nil }
        return "data:image/png;base64," + data.base64EncodedString()
    }

    /// 保存当前字并进入下一个（与Web端saveAndNext一致）
    private func saveCharAndNext() async {
        guard !drawing.strokes.isEmpty else { return }
        guard let char = viewModel.currentChar else { return }

        let strokeData = StrokeDataV2.from(drawing: drawing, canvasSize: canvasView.bounds.size)
        let preview = exportPreview() ?? ""

        let record = CompletedCharRecord(
            character: String(char),
            strokeData: strokeData,
            preview: preview
        )

        // 更新或追加记录
        if let idx = completedRecords.firstIndex(where: { $0.character == String(char) }) {
            completedRecords[idx] = record
        } else {
            completedRecords.append(record)
        }

        if isLastChar {
            // 最后一个字，提交整个作品
            await submitWork()
        } else {
            // 进入下一个
            charDrawings[viewModel.currentCharIndex] = drawing
            viewModel.nextChar()
            clearCanvas()
        }
    }

    /// 提交整个作品到服务器（与Web端saveWork一致）
    private func submitWork() async {
        isSaving = true
        defer { isSaving = false }

        let success = await viewModel.saveWorkPerChar(
            text: viewModel.practiceText,
            records: completedRecords.map { ($0.character, $0.strokeData, $0.preview) },
            fontId: viewModel.selectedFont?.id
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

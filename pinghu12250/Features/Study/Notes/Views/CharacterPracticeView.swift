//
//  CharacterPracticeView.swift
//  pinghu12250
//
//  书写练习全屏视图
//  支持多字练习、PencilKit书写、临摹模式
//  保存数据格式与Web端完全兼容
//

import SwiftUI
import PencilKit

/// 书写练习全屏视图
struct CharacterPracticeView: View {
    /// 要练习的笔记列表
    let notes: [ReadingNote]
    /// 关闭回调
    var onClose: (() -> Void)?
    /// 保存成功回调
    var onSave: ((ReadingNote, String) -> Void)?  // (原笔记, 新练习ID)
    /// 完成回调
    var onComplete: (([WritingPracticeRecord]) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TextbookViewModel()

    // MARK: - 状态

    @State private var currentIndex = 0
    @State private var gridType: GridType = .mi
    @State private var strokeData = StrokeData.empty(canvasSize: CGSize(width: 300, height: 300))
    @State private var tracingMode = false
    @State private var penWidth: CGFloat = 4
    @State private var penColor: Color = .black
    @State private var sessionRecords: [WritingPracticeRecord] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    // PencilKit画布
    @State private var canvasView: PKCanvasView?

    /// 当前字符
    private var currentNote: ReadingNote? {
        guard currentIndex < notes.count else { return nil }
        return notes[currentIndex]
    }

    private var currentCharacter: String {
        currentNote?.query ?? contentDict?["character"] as? String ?? ""
    }

    private var currentPinyin: String? {
        contentDict?["pinyin"] as? String
    }

    private var currentDefinition: String? {
        contentDict?["definition"] as? String ?? contentDict?["meaning"] as? String
    }

    private var contentDict: [String: Any]? {
        guard let content = currentNote?.content else { return nil }
        if let dict = content.value as? [String: Any] {
            return dict
        }
        return nil
    }

    private var isLastCharacter: Bool {
        currentIndex >= notes.count - 1
    }

    private var hasStrokes: Bool {
        !strokeData.strokes.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            headerBar

            // 主练习区
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let canvasSize = calculateCanvasSize(geometry: geometry)

                if isLandscape {
                    // 横屏布局：左参考 | 中书写 | 右历史
                    HStack(spacing: 0) {
                        // 左侧参考区
                        referenceArea
                            .frame(width: 160)

                        // 中间书写区（居中）
                        Spacer()
                        writingArea(canvasSize: canvasSize)
                        Spacer()

                        // 右侧历史区
                        historyArea
                            .frame(width: 140)
                    }
                    .padding(20)
                } else {
                    // 竖屏布局
                    VStack(spacing: 16) {
                        // 顶部：参考 + 历史
                        HStack(spacing: 16) {
                            referenceArea
                            Spacer()
                            historyArea
                        }

                        // 书写区（居中）
                        HStack {
                            Spacer()
                            writingArea(canvasSize: canvasSize)
                            Spacer()
                        }
                    }
                    .padding(16)
                }
            }

            // 底部操作栏
            footerBar
        }
        .background(Color(.systemGray6))
        .alert("错误", isPresented: $showError) {
            Button("确定") {}
        } message: {
            Text(errorMessage)
        }
    }

    /// 计算画布尺寸（根据可用空间自适应）
    private func calculateCanvasSize(geometry: GeometryProxy) -> CGFloat {
        let isLandscape = geometry.size.width > geometry.size.height
        if isLandscape {
            // 横屏：高度 - 工具栏 - padding
            return min(geometry.size.height - 100, geometry.size.width * 0.45, 400)
        } else {
            // 竖屏：宽度 - padding
            return min(geometry.size.width - 40, geometry.size.height * 0.5, 400)
        }
    }

    // MARK: - 顶部工具栏

    private var headerBar: some View {
        HStack {
            // 关闭按钮
            Button {
                dismiss()
                onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
            }

            Text("书写练习")
                .font(.headline)

            if notes.count > 1 {
                Text("\(currentIndex + 1)/\(notes.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            Spacer()

            // 当前字符信息
            VStack(spacing: 2) {
                Text(currentCharacter)
                    .font(.system(size: 32, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 0.8, green: 0, blue: 0))

                if let pinyin = currentPinyin {
                    Text(pinyin)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            // 格子类型选择
            Picker("", selection: $gridType) {
                Text("米字格").tag(GridType.mi)
                Text("田字格").tag(GridType.tian)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - 左侧参考区

    private var referenceArea: some View {
        VStack(spacing: 12) {
            MiTianGridView(
                character: currentCharacter,
                gridType: gridType,
                size: 120
            )

            if let definition = currentDefinition {
                Text(definition)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(width: 140)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 中间书写区

    private func writingArea(canvasSize: CGFloat) -> some View {
        VStack(spacing: 16) {
            // 书写画布
            ZStack {
                // 米字格背景
                MiTianGridView(
                    character: tracingMode ? currentCharacter : nil,
                    gridType: gridType,
                    size: canvasSize,
                    showCharacter: tracingMode,
                    characterOpacity: 0.15
                )

                // PencilKit 书写画布
                CharacterPencilKitCanvas(
                    strokeData: $strokeData,
                    penWidth: penWidth,
                    penColor: penColor
                )
                .frame(width: canvasSize, height: canvasSize)
            }
            .frame(width: canvasSize, height: canvasSize)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            // 工具栏
            writingToolBar
        }
    }

    private var writingToolBar: some View {
        HStack(spacing: 16) {
            // 撤销
            Button {
                undoStroke()
            } label: {
                Label("撤销", systemImage: "arrow.uturn.backward")
                    .font(.caption)
            }
            .disabled(!hasStrokes)

            // 清除
            Button {
                clearCanvas()
            } label: {
                Label("清除", systemImage: "trash")
                    .font(.caption)
            }
            .disabled(!hasStrokes)

            // 临摹模式
            Toggle(isOn: $tracingMode) {
                Label("临摹", systemImage: "eye")
                    .font(.caption)
            }
            .toggleStyle(.button)

            Divider()
                .frame(height: 20)

            // 笔宽
            HStack(spacing: 4) {
                Text("笔宽")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $penWidth, in: 2...12, step: 1)
                    .frame(width: 80)
            }

            // 颜色选择
            ColorPicker("", selection: $penColor)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    // MARK: - 右侧历史区

    private var historyArea: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                Text("本次练习")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if sessionRecords.isEmpty {
                VStack {
                    Spacer()
                    Text("开始书写吧")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(sessionRecords) { record in
                            WritingPracticeRecordThumbnail(record: record)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 底部操作栏

    private var footerBar: some View {
        HStack {
            // 上一个
            Button {
                prevCharacter()
            } label: {
                Label("上一个", systemImage: "chevron.left")
            }
            .disabled(currentIndex == 0)

            Spacer()

            // 保存并下一个
            Button {
                Task {
                    await saveAndNext()
                }
            } label: {
                Label(
                    isLastCharacter ? "保存并完成" : "保存并下一个",
                    systemImage: "checkmark"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasStrokes || isSaving)

            Spacer()

            // 跳过
            Button {
                skipToNext()
            } label: {
                Label("跳过", systemImage: "chevron.right")
            }
            .disabled(isLastCharacter)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - 操作方法

    private func undoStroke() {
        guard !strokeData.strokes.isEmpty else { return }
        strokeData.strokes.removeLast()
    }

    private func clearCanvas() {
        strokeData = StrokeData.empty(canvasSize: CGSize(width: 300, height: 300))
    }

    private func prevCharacter() {
        guard currentIndex > 0 else { return }
        clearCanvas()
        currentIndex -= 1
    }

    private func skipToNext() {
        guard !isLastCharacter else { return }
        clearCanvas()
        currentIndex += 1
    }

    private func saveAndNext() async {
        guard let currentNote = currentNote, hasStrokes else { return }

        isSaving = true
        defer { isSaving = false }

        // 1. 生成预览图
        let preview = WritingEvaluationService.shared.generatePreviewImage(
            strokeData: strokeData,
            size: CGSize(width: 200, height: 200),
            backgroundColor: .white
        )

        // 2. 构建保存内容
        var saveContent = strokeData
        saveContent.preview = preview
        saveContent.character = currentCharacter
        saveContent.originalNoteId = currentNote.id
        saveContent.gridType = gridType.rawValue

        // 3. 调用API保存
        guard let contentJSON = saveContent.toJSONString() else {
            errorMessage = "数据序列化失败"
            showError = true
            return
        }

        let newNote = await viewModel.createNote(
            textbookId: currentNote.textbookId,
            sourceType: "writing_practice",
            query: currentCharacter,
            content: contentJSON,
            snippet: "书写练习: \(currentCharacter)",
            page: currentNote.page
        )

        if let newNote = newNote {
            // 添加到本次会话记录
            let record = WritingPracticeRecord(
                id: newNote.id,
                character: currentCharacter,
                preview: preview,
                createdAt: Date()
            )
            sessionRecords.append(record)

            // 回调
            onSave?(currentNote, newNote.id)

            // 清除画布，下一个
            clearCanvas()

            if isLastCharacter {
                // 完成
                onComplete?(sessionRecords)
                dismiss()
                onClose?()
            } else {
                currentIndex += 1
            }
        } else {
            errorMessage = "保存失败，请重试"
            showError = true
        }
    }
}

// MARK: - PencilKit画布包装

/// PencilKit画布（书写练习专用）
struct CharacterPencilKitCanvas: UIViewRepresentable {
    @Binding var strokeData: StrokeData
    var penWidth: CGFloat
    var penColor: Color

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.isScrollEnabled = false

        let ink = PKInkingTool(.pen, color: UIColor(penColor), width: penWidth)
        canvasView.tool = ink

        context.coordinator.canvasView = canvasView
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        let ink = PKInkingTool(.pen, color: UIColor(penColor), width: penWidth)
        canvasView.tool = ink

        // 如果strokeData被清空，清除画布
        if strokeData.strokes.isEmpty && !canvasView.drawing.strokes.isEmpty {
            canvasView.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CharacterPencilKitCanvas
        weak var canvasView: PKCanvasView?
        private var strokeStartTimes: [Int: Int64] = [:]

        init(_ parent: CharacterPencilKitCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.strokeData = convertToStrokeData(canvasView.drawing)
        }

        private func convertToStrokeData(_ drawing: PKDrawing) -> StrokeData {
            var strokes: [StrokeData.Stroke] = []
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            for (index, stroke) in drawing.strokes.enumerated() {
                var points: [StrokeData.Point] = []
                let path = stroke.path

                let strokeStartTime = strokeStartTimes[index] ?? (now - Int64((drawing.strokes.count - index) * 1000))
                if strokeStartTimes[index] == nil {
                    strokeStartTimes[index] = strokeStartTime
                }

                for i in 0..<path.count {
                    let point = path[i]
                    let t = strokeStartTime + Int64(Double(i) / Double(max(path.count - 1, 1)) * 500)

                    points.append(StrokeData.Point(
                        x: point.location.x,
                        y: point.location.y,
                        t: t,
                        p: point.force > 0 ? point.force : nil
                    ))
                }

                let strokeId = "stroke_\(strokeStartTime)_\(UUID().uuidString.prefix(9))"
                // 使用parent.penWidth，因为iOS 17+ PKInk没有width属性
                strokes.append(StrokeData.Stroke(
                    id: strokeId,
                    color: stroke.ink.color.hexString,
                    lineWidth: parent.penWidth,
                    points: points
                ))
            }

            return StrokeData(
                version: STROKE_DATA_VERSION,
                canvas: StrokeData.CanvasSize(width: 300, height: 300, dpr: UIScreen.main.scale),
                strokes: strokes
            )
        }
    }
}

// MARK: - 练习记录

/// 书写练习记录（本地使用）
struct WritingPracticeRecord: Identifiable {
    let id: String
    let character: String
    let preview: String?
    let createdAt: Date

    init(id: String = UUID().uuidString, character: String, preview: String?, createdAt: Date) {
        self.id = id
        self.character = character
        self.preview = preview
        self.createdAt = createdAt
    }
}

/// 练习记录缩略图
struct WritingPracticeRecordThumbnail: View {
    let record: WritingPracticeRecord

    var body: some View {
        HStack(spacing: 8) {
            // 预览图
            if let preview = record.preview,
               let data = Data(base64Encoded: preview.replacingOccurrences(of: "data:image/png;base64,", with: "")),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(record.character)
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.character)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(formatTime(record.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    let sampleNotes = [
        ReadingNote(
            id: "1",
            userId: "user1",
            textbookId: "tb1",
            sessionId: nil,
            sourceType: "dict",
            query: "春",
            content: AnyCodable(["pinyin": "chūn", "definition": "一年的第一个季节"]),
            snippet: nil,
            page: 1,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        ),
        ReadingNote(
            id: "2",
            userId: "user1",
            textbookId: "tb1",
            sessionId: nil,
            sourceType: "dict",
            query: "夏",
            content: AnyCodable(["pinyin": "xià", "definition": "一年的第二个季节"]),
            snippet: nil,
            page: 1,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        )
    ]

    CharacterPracticeView(notes: sampleNotes)
}

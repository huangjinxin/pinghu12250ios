//
//  HandwritingNoteEditor.swift
//  pinghu12250
//
//  手写笔记编辑器 - 基于 PencilKit
//

import SwiftUI
import PencilKit
import Combine

// MARK: - 手写笔记编辑器

struct HandwritingNoteEditor: View {
    let textbookId: String
    let pageIndex: Int?
    let existingNote: StudyNote?
    let onSave: (StudyNote, Data?) -> Void
    let onCancel: () -> Void

    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var title: String = ""
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 3
    @State private var isRulerActive = false
    @State private var isFavorite = false
    @State private var tags: [String] = []
    @State private var showTagInput = false
    @State private var newTag = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 工具栏
                toolbarView

                Divider()

                // 画布
                PencilKitCanvas(
                    canvasView: $canvasView,
                    drawing: $drawing,
                    tool: selectedTool,
                    color: selectedColor.color,
                    lineWidth: lineWidth,
                    isRulerActive: isRulerActive
                )
                .background(Color.white)

                Divider()

                // 底部选项
                bottomOptionsView
            }
            .navigationTitle(existingNote == nil ? "手写笔记" : "编辑手写笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                    .disabled(drawing.strokes.isEmpty)
                }
            }
            .onAppear {
                loadExistingNote()
            }
        }
    }

    // MARK: - 工具栏

    private var toolbarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 工具选择
                ForEach(CanvasTool.allCases) { tool in
                    toolButton(tool)
                }

                Divider()
                    .frame(height: 24)

                // 颜色选择
                ForEach(CanvasColor.presets.prefix(5)) { canvasColor in
                    colorButton(canvasColor)
                }

                Divider()
                    .frame(height: 24)

                // 线宽选择
                ForEach([2.0, 4.0, 8.0], id: \.self) { width in
                    lineWidthButton(width)
                }

                Divider()
                    .frame(height: 24)

                // 标尺
                Button {
                    isRulerActive.toggle()
                } label: {
                    Image(systemName: "ruler")
                        .font(.system(size: 18))
                        .foregroundColor(isRulerActive ? .appPrimary : .secondary)
                        .frame(width: 36, height: 36)
                        .background(isRulerActive ? Color.appPrimary.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }

                // 撤销/重做
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }

                Button {
                    canvasView.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
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
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func toolButton(_ tool: CanvasTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 20))
                .foregroundColor(selectedTool == tool ? .appPrimary : .secondary)
                .frame(width: 36, height: 36)
                .background(selectedTool == tool ? Color.appPrimary.opacity(0.1) : Color.clear)
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
                            selectedColor.id == canvasColor.id ? Color.appPrimary : Color.clear,
                            lineWidth: 3
                        )
                )
        }
    }

    private func lineWidthButton(_ width: CGFloat) -> some View {
        Button {
            lineWidth = width
        } label: {
            Circle()
                .fill(Color(selectedColor.color))
                .frame(width: width + 4, height: width + 4)
                .padding(4)
                .background(
                    Circle()
                        .stroke(
                            lineWidth == width ? Color.appPrimary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }

    // MARK: - 底部选项

    private var bottomOptionsView: some View {
        VStack(spacing: 12) {
            // 标题输入
            HStack {
                TextField("笔记标题（可选）", text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                // 收藏按钮
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .orange : .secondary)
                        .font(.system(size: 22))
                }
            }

            // 标签
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 已添加的标签
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.caption)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.1))
                            .foregroundColor(.appPrimary)
                            .cornerRadius(10)
                        }

                        // 添加标签按钮
                        Button {
                            showTagInput.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("标签")
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .foregroundColor(.secondary)
                            .cornerRadius(10)
                        }
                    }
                }

                if showTagInput {
                    HStack {
                        TextField("输入标签", text: $newTag)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onSubmit {
                                addTag()
                            }
                        Button("添加") {
                            addTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 辅助方法

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }

    private func loadExistingNote() {
        guard let note = existingNote else { return }

        title = note.title
        isFavorite = note.isFavorite
        tags = note.tags

        // 尝试加载保存的绘图
        if let drawingAttachment = note.attachments.first(where: { $0.type == .drawing }),
           let data = drawingAttachment.data,
           let loadedDrawing = try? PKDrawing(data: data) {
            drawing = loadedDrawing
        }
    }

    private func saveNote() {
        // 导出绘图为图片（用于预览）
        let bounds = drawing.bounds
        let image = drawing.image(from: bounds, scale: UIScreen.main.scale)

        // 创建绘图附件
        let drawingData = drawing.dataRepresentation()
        let attachment = NoteAttachment(
            id: UUID(),
            type: .drawing,
            data: drawingData,
            url: nil
        )

        // 创建笔记
        let note: StudyNote
        if let existing = existingNote {
            note = StudyNote(
                id: existing.id,
                textbookId: textbookId,
                pageIndex: pageIndex ?? existing.pageIndex,
                title: title.isEmpty ? "手写笔记" : title,
                content: "[手写笔记]",
                type: .handwriting,
                tags: tags,
                color: existing.color,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                isFavorite: isFavorite,
                attachments: [attachment]
            )
        } else {
            note = StudyNote(
                textbookId: textbookId,
                pageIndex: pageIndex,
                title: title.isEmpty ? "手写笔记" : title,
                content: "[手写笔记]",
                type: .handwriting,
                tags: tags,
                isFavorite: isFavorite,
                attachments: [attachment]
            )
        }

        onSave(note, drawing.dataRepresentation())
    }
}

// MARK: - 手写笔记预览

struct HandwritingNotePreview: View {
    let note: StudyNote

    @State private var drawing: PKDrawing?

    var body: some View {
        Group {
            if let drawing = drawing, !drawing.strokes.isEmpty {
                // 显示手写内容
                Image(uiImage: drawing.image(from: drawing.bounds, scale: UIScreen.main.scale))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                // 占位符
                VStack(spacing: 8) {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.system(size: 30))
                        .foregroundColor(.teal)
                    Text("手写笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .onAppear {
            loadDrawing()
        }
    }

    private func loadDrawing() {
        if let attachment = note.attachments.first(where: { $0.type == .drawing }),
           let data = attachment.data,
           let loadedDrawing = try? PKDrawing(data: data) {
            drawing = loadedDrawing
        }
    }
}

// MARK: - 预览

#Preview {
    HandwritingNoteEditor(
        textbookId: "test",
        pageIndex: 0,
        existingNote: nil,
        onSave: { _, _ in },
        onCancel: {}
    )
}

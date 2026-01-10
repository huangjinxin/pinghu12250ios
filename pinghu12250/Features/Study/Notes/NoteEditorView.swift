//
//  NoteEditorView.swift
//  pinghu12250
//
//  笔记编辑器视图
//

import SwiftUI

// MARK: - 笔记编辑器

struct NoteEditorView: View {
    let textbookId: String
    let pageIndex: Int?
    let existingNote: StudyNote?
    let onSave: (StudyNote) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var noteType: StudyNoteType = .text
    @State private var noteColor: StudyNoteColor = .default
    @State private var tags: [String] = []
    @State private var isFavorite: Bool = false

    @State private var showTagInput = false
    @State private var newTag = ""
    @State private var showColorPicker = false
    @State private var showVoiceRecording = false
    @State private var showHandwritingEditor = false
    @StateObject private var voiceRecorder = VoiceNoteRecorder()
    @FocusState private var isContentFocused: Bool

    init(
        textbookId: String,
        pageIndex: Int?,
        existingNote: StudyNote? = nil,
        onSave: @escaping (StudyNote) -> Void
    ) {
        self.textbookId = textbookId
        self.pageIndex = pageIndex
        self.existingNote = existingNote
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 类型选择
                    typeSelector

                    // 标题输入
                    titleInput

                    // 内容输入
                    contentInput

                    // 颜色选择
                    colorSelector

                    // 标签管理
                    tagsSection

                    // 收藏开关
                    favoriteToggle
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(existingNote == nil ? "新建笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let note = existingNote {
                    title = note.title
                    content = note.content
                    noteType = note.type
                    noteColor = note.color
                    tags = note.tags
                    isFavorite = note.isFavorite
                }
            }
            .fullScreenCover(isPresented: $showHandwritingEditor) {
                DismissibleCover(showCloseButton: false) {
                    HandwritingNoteEditor(
                        textbookId: textbookId,
                        pageIndex: pageIndex,
                        existingNote: existingNote,
                        onSave: { note, _ in
                            onSave(note)
                            dismiss()
                        },
                        onCancel: {
                            showHandwritingEditor = false
                            noteType = .text  // 切换回文字模式
                        }
                    )
                }
            }
        }
    }

    // MARK: - 类型选择器

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("笔记类型")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StudyNoteType.allCases, id: \.self) { type in
                        Button {
                            if type == .handwriting {
                                // 手写模式：打开专用编辑器
                                showHandwritingEditor = true
                            } else {
                                noteType = type
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 60, height: 60)
                            .background(noteType == type ? type.color.opacity(0.2) : Color(.systemGray6))
                            .foregroundColor(noteType == type ? type.color : .secondary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(noteType == type ? type.color : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 标题输入

    private var titleInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题（可选）")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("输入标题...", text: $title)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 内容输入

    private var contentInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("内容")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(content.count) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .focused($isContentFocused)

                // 语音输入按钮
                Button {
                    showVoiceRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showVoiceRecording) {
            VoiceRecordingSheet(
                onComplete: { text in
                    content += (content.isEmpty ? "" : "\n") + text
                    showVoiceRecording = false
                },
                onCancel: {
                    showVoiceRecording = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - 颜色选择器

    private var colorSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("背景颜色")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(StudyNoteColor.allCases, id: \.self) { color in
                    Button {
                        noteColor = color
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.solidColor.opacity(color == .default ? 0.3 : 1))
                                .frame(width: 36, height: 36)

                            if noteColor == color {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(color == .default || color == .yellow ? .black : .white)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 标签管理

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("标签")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showTagInput.toggle()
                } label: {
                    Image(systemName: showTagInput ? "minus.circle" : "plus.circle")
                        .foregroundColor(.appPrimary)
                }
            }

            // 已添加的标签
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1))
                        .foregroundColor(.appPrimary)
                        .cornerRadius(12)
                    }
                }
            }

            // 标签输入
            if showTagInput {
                HStack {
                    TextField("输入标签...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }
                    Button("添加") {
                        addTag()
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // 推荐标签
                Text("推荐标签")
                    .font(.caption)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(CommonTags.all.filter { !tags.contains($0) }.prefix(10), id: \.self) { tag in
                        Button {
                            tags.append(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }

    // MARK: - 收藏开关

    private var favoriteToggle: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.orange)
            Text("添加到收藏")
            Spacer()
            Toggle("", isOn: $isFavorite)
                .tint(.orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 保存笔记

    private func saveNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let note: StudyNote
        if let existing = existingNote {
            note = StudyNote(
                id: existing.id,
                textbookId: textbookId,
                pageIndex: pageIndex ?? existing.pageIndex,
                title: title,
                content: trimmedContent,
                type: noteType,
                tags: tags,
                color: noteColor,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                isFavorite: isFavorite,
                attachments: existing.attachments
            )
        } else {
            note = StudyNote(
                textbookId: textbookId,
                pageIndex: pageIndex,
                title: title,
                content: trimmedContent,
                type: noteType,
                tags: tags,
                color: noteColor,
                isFavorite: isFavorite
            )
        }

        onSave(note)
        dismiss()
    }
}

// MARK: - 快速笔记浮窗

struct QuickNotePopover: View {
    let textbookId: String
    let pageIndex: Int
    let initialContent: String
    let onSave: (StudyNote) -> Void
    @Binding var isPresented: Bool

    @State private var content: String = ""
    @State private var noteType: StudyNoteType = .text

    var body: some View {
        VStack(spacing: 12) {
            // 类型快捷选择
            HStack(spacing: 8) {
                ForEach([StudyNoteType.highlight, .text, .question], id: \.self) { type in
                    Button {
                        noteType = type
                    } label: {
                        Image(systemName: type.icon)
                            .font(.subheadline)
                            .foregroundColor(noteType == type ? .white : type.color)
                            .padding(8)
                            .background(noteType == type ? type.color : type.color.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                Spacer()
            }

            // 内容
            TextField("添加笔记...", text: $content, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    let note = StudyNote(
                        textbookId: textbookId,
                        pageIndex: pageIndex,
                        content: content.isEmpty ? initialContent : content,
                        type: noteType
                    )
                    onSave(note)
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("保存")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appPrimary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .onAppear {
            content = initialContent
        }
    }
}

// MARK: - 预览

#Preview {
    NoteEditorView(
        textbookId: "test",
        pageIndex: 0,
        onSave: { _ in }
    )
}

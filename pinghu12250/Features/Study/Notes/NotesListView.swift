//
//  NotesListView.swift
//  pinghu12250
//
//  笔记列表视图
//

import SwiftUI
import PencilKit

// MARK: - 笔记列表视图

struct NotesListView: View {
    @ObservedObject var notesManager = NotesManager.shared
    let textbookId: String
    let currentPage: Int?
    let onSelectNote: ((StudyNote) -> Void)?
    var onJumpToPage: ((Int) -> Void)? = nil  // 跳转到教材页面

    @State private var filter = NoteFilter()
    @State private var showFilterSheet = false
    @State private var showNewNoteSheet = false
    @State private var selectedNote: StudyNote?
    @State private var showDeleteAlert = false
    @State private var noteToDelete: UUID?

    init(
        textbookId: String,
        currentPage: Int? = nil,
        onSelectNote: ((StudyNote) -> Void)? = nil,
        onJumpToPage: ((Int) -> Void)? = nil
    ) {
        self.textbookId = textbookId
        self.currentPage = currentPage
        self.onSelectNote = onSelectNote
        self.onJumpToPage = onJumpToPage
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和过滤栏
            searchAndFilterBar

            // 快捷分类标签
            quickFilterTags

            // 笔记列表
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                notesList
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(filter: $filter)
        }
        .sheet(isPresented: $showNewNoteSheet) {
            NoteEditorView(
                textbookId: textbookId,
                pageIndex: currentPage,
                onSave: { note in
                    notesManager.createNote(note)
                }
            )
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorView(
                textbookId: textbookId,
                pageIndex: note.pageIndex,
                existingNote: note,
                onSave: { updated in
                    notesManager.updateNote(updated)
                }
            )
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let id = noteToDelete {
                    notesManager.deleteNote(id)
                }
            }
        } message: {
            Text("确定要删除这条笔记吗？")
        }
    }

    // MARK: - 过滤后的笔记

    private var filteredNotes: [StudyNote] {
        notesManager.getFilteredNotes(filter: filter, textbookId: textbookId)
    }

    // MARK: - 搜索和过滤栏

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索笔记...", text: $filter.searchText)
                    .textFieldStyle(.plain)

                if !filter.searchText.isEmpty {
                    Button {
                        filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // 过滤按钮
            Button {
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.appPrimary)

                    if !filter.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }

            // 新建按钮
            Button {
                showNewNoteSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.appPrimary)
            }
        }
        .padding()
    }

    // MARK: - 快捷分类标签

    private var quickFilterTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                quickFilterChip(
                    label: "全部",
                    isSelected: filter.types.isEmpty,
                    count: notesManager.getNotes(for: textbookId).count
                ) {
                    filter.types = []
                }

                // 按类型
                ForEach(StudyNoteType.allCases, id: \.self) { type in
                    let count = notesManager.getNotes(for: textbookId).filter { $0.type == type }.count
                    if count > 0 {
                        quickFilterChip(
                            label: type.displayName,
                            icon: type.icon,
                            isSelected: filter.types.contains(type),
                            count: count
                        ) {
                            if filter.types.contains(type) {
                                filter.types.remove(type)
                            } else {
                                filter.types.insert(type)
                            }
                        }
                    }
                }

                // 收藏
                let favoriteCount = notesManager.getNotes(for: textbookId).filter { $0.isFavorite }.count
                if favoriteCount > 0 {
                    quickFilterChip(
                        label: "收藏",
                        icon: "star.fill",
                        isSelected: filter.showFavoritesOnly,
                        count: favoriteCount,
                        color: .orange
                    ) {
                        filter.showFavoritesOnly.toggle()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private func quickFilterChip(
        label: String,
        icon: String? = nil,
        isSelected: Bool,
        count: Int,
        color: Color = .appPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.caption)
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(16)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(filter.isEmpty ? "暂无笔记" : "没有符合条件的笔记")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(filter.isEmpty ? "点击 + 创建第一条笔记" : "尝试调整筛选条件")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            if filter.isEmpty {
                Button {
                    showNewNoteSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("创建笔记")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 笔记列表

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredNotes) { note in
                    NoteCardView(
                        note: note,
                        onTap: {
                            if let onSelectNote = onSelectNote {
                                onSelectNote(note)
                            } else {
                                selectedNote = note
                            }
                        },
                        onFavorite: {
                            notesManager.toggleFavorite(note.id)
                        },
                        onDelete: {
                            noteToDelete = note.id
                            showDeleteAlert = true
                        },
                        onJumpToPage: onJumpToPage,
                        onToggleResolved: {
                            notesManager.toggleResolved(note.id)
                        },
                        onTagToggle: { tag in
                            notesManager.toggleTag(note.id, tag: tag)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - 笔记卡片视图

struct NoteCardView: View {
    let note: StudyNote
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    var onJumpToPage: ((Int) -> Void)? = nil  // 跳转到教材页面
    var onToggleResolved: (() -> Void)? = nil  // 切换疑问解决状态
    var onTagToggle: ((String) -> Void)? = nil  // 切换快捷标签

    /// 获取手写笔记缩略图
    private var handwritingThumbnail: UIImage? {
        guard note.type == .handwriting,
              let drawingAttachment = note.attachments.first(where: { $0.type == .drawing }),
              let drawingData = drawingAttachment.data,
              let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        // 生成缩略图
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }

        // 计算缩放以适应缩略图大小
        let maxSize: CGFloat = 200
        let scale = min(maxSize / bounds.width, maxSize / bounds.height, 1.0)
        let scaledSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        return drawing.image(from: bounds, scale: scale)
    }

    /// 获取 OCR 识别文字（从批注管理器）
    private var ocrText: String? {
        guard note.type == .handwriting,
              let pageIndex = note.pageIndex else { return nil }
        return AnnotationNoteManager.shared.getAnnotation(
            textbookId: note.textbookId,
            pageIndex: pageIndex
        )?.ocrText
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 头部
                noteHeader

                // 标题
                Text(note.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 快捷标签芯片
                quickTagChips

                // 手写笔记缩略图预览
                if note.type == .handwriting, let thumbnail = handwritingThumbnail {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 80)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )

                        // OCR 识别文字（可复制）
                        if let ocr = ocrText, !ocr.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "text.viewfinder")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(ocr)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                // 复制按钮
                                Button {
                                    UIPasteboard.general.string = ocr
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                        }
                    }
                } else {
                    // 内容预览（非手写笔记）
                    Text(note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // 底部信息
                noteFooter
            }
            .padding()
            .background(note.color.color)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 头部

    private var noteHeader: some View {
        HStack {
            // 类型标签
            HStack(spacing: 4) {
                Image(systemName: note.type.icon)
                    .font(.caption)
                Text(note.type.displayName)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(note.type.color)
            .cornerRadius(6)

            // 疑问状态标记（仅对疑问类型显示）
            if note.type == .question {
                Button {
                    onToggleResolved?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: note.isResolved ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text(note.isResolved ? "已解决" : "未解决")
                            .font(.caption)
                    }
                    .foregroundColor(note.isResolved ? .green : .orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(note.isResolved ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
            }

            // 页码（可点击跳转）
            if let pageIndex = note.pageIndex {
                Button {
                    onJumpToPage?(pageIndex)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "book.pages")
                            .font(.caption2)
                        Text("P\(pageIndex + 1)")
                            .font(.caption)
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(4)
                }
                .disabled(onJumpToPage == nil)
            }

            Spacer()

            // 收藏按钮
            Button(action: onFavorite) {
                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .foregroundColor(note.isFavorite ? .orange : .secondary)
            }

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
    }

    // MARK: - 快捷标签芯片

    private var quickTagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QuickTag.presets) { tag in
                    let isActive = note.tags.contains(tag.tagText)
                    Button {
                        onTagToggle?(tag.tagText)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: tag.icon)
                                .font(.system(size: 9))
                            Text(tag.label)
                                .font(.caption2)
                        }
                        .foregroundColor(isActive ? .white : tag.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? tag.color : tag.color.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .disabled(onTagToggle == nil)
                }
            }
        }
    }

    // MARK: - 底部信息

    private var noteFooter: some View {
        HStack {
            // 标签
            if !note.tags.isEmpty {
                let displayTags = note.tags.filter { tag in
                    !QuickTag.presets.contains { $0.tagText == tag }
                }
                if !displayTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(displayTags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.appPrimary)
                        }
                        if displayTags.count > 3 {
                            Text("+\(displayTags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 时间
            Text(note.updatedAt.relativeTimeString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 过滤器面板

struct FilterSheetView: View {
    @Binding var filter: NoteFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 类型过滤
                Section("笔记类型") {
                    ForEach(StudyNoteType.allCases, id: \.self) { type in
                        Button {
                            if filter.types.contains(type) {
                                filter.types.remove(type)
                            } else {
                                filter.types.insert(type)
                            }
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                                Spacer()
                                if filter.types.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // 颜色过滤
                Section("颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(StudyNoteColor.allCases, id: \.self) { color in
                            Button {
                                if filter.colors.contains(color) {
                                    filter.colors.remove(color)
                                } else {
                                    filter.colors.insert(color)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.solidColor)
                                        .frame(width: 32, height: 32)

                                    if filter.colors.contains(color) {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 排序
                Section("排序") {
                    Picker("排序方式", selection: $filter.sortBy) {
                        ForEach(NoteSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Toggle("升序", isOn: $filter.sortAscending)
                }

                // 其他
                Section {
                    Toggle("只显示收藏", isOn: $filter.showFavoritesOnly)
                }

                // 重置
                Section {
                    Button("重置所有筛选", role: .destructive) {
                        filter = NoteFilter()
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 注意: Date.relativeTimeString 已移至 Core/Extensions/Date+Extensions.swift

// MARK: - 预览

#Preview {
    NotesListView(textbookId: "test", currentPage: 0)
}

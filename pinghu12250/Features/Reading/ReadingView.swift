//
//  ReadingView.swift
//  pinghu12250
//
//  读书 - 教材和读书笔记
//

import SwiftUI
import PDFKit
import Combine

struct ReadingView: View {
    @StateObject private var viewModel = TextbookViewModel()
    @State private var showLibrary = false
    @State private var isCheckingUpdates = false
    @State private var showUpdateToast = false
    @State private var updateToastMessage = ""

    var body: some View {
            // 直接显示我的教材（去掉顶层 tab 切换）
            MyTextbooksView(viewModel: viewModel)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("我的教材")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showLibrary = true
                        } label: {
                            Image(systemName: "building.columns")
                                .font(.title3)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await checkForUpdates()
                            }
                        } label: {
                            if isCheckingUpdates {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title3)
                            }
                        }
                        .disabled(isCheckingUpdates)
                    }
                }
                .overlay {
                    if showUpdateToast {
                        VStack {
                            Spacer()
                            Text(updateToastMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .padding(.bottom, 100)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: showUpdateToast)
                    }
                }
        .task {
            await viewModel.loadAllData()
        }
        .refreshable {
            await viewModel.loadAllData()
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showLibrary) {
            LibraryFullScreenView(viewModel: viewModel, onDismiss: { showLibrary = false })
        }
    }

    /// 检查教材更新
    private func checkForUpdates() async {
        isCheckingUpdates = true

        // 重新加载收藏的教材数据
        await viewModel.loadFavorites()

        isCheckingUpdates = false

        // 显示 Toast
        updateToastMessage = "已刷新，共 \(viewModel.favoriteTextbooks.count) 本教材"
        withAnimation {
            showUpdateToast = true
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation {
            showUpdateToast = false
        }
    }
}

// MARK: - 电子书库全屏视图

private struct LibraryFullScreenView: View {
    @ObservedObject var viewModel: TextbookViewModel
    let onDismiss: () -> Void

    @State private var isCheckingUpdates = false
    @State private var showUpdateToast = false
    @State private var updateToastMessage = ""

    var body: some View {
        NavigationStack {
            TextbookLibraryView(viewModel: viewModel)
                .navigationTitle("电子书库")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onDismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("返回")
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await checkForUpdates()
                            }
                        } label: {
                            if isCheckingUpdates {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.body)
                            }
                        }
                        .disabled(isCheckingUpdates)
                    }
                }
                .overlay {
                    if showUpdateToast {
                        VStack {
                            Spacer()
                            Text(updateToastMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .padding(.bottom, 100)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: showUpdateToast)
                    }
                }
        }
    }

    /// 检查教材更新
    private func checkForUpdates() async {
        isCheckingUpdates = true

        // 重新加载公共教材数据
        await viewModel.loadPublicTextbooks()

        isCheckingUpdates = false

        // 显示 Toast
        updateToastMessage = "已刷新，共 \(viewModel.totalCount) 本教材"
        withAnimation {
            showUpdateToast = true
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation {
            showUpdateToast = false
        }
    }
}

// MARK: - 教材区域

struct TextbooksSection: View {
    @ObservedObject var viewModel: TextbookViewModel
    @State private var activeTab: TextbookTab = .myTextbooks

    enum TextbookTab: String, CaseIterable {
        case myTextbooks = "我的教材"
        case library = "电子书库"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 子标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(TextbookTab.allCases, id: \.self) { tab in
                        TextbookTabButton(title: tab.rawValue, isSelected: activeTab == tab) {
                            activeTab = tab
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            // 内容
            Group {
                switch activeTab {
                case .myTextbooks:
                    MyTextbooksView(viewModel: viewModel)
                case .library:
                    TextbookLibraryView(viewModel: viewModel)
                }
            }
        }
    }
}

struct TextbookTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .appPrimary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.appPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 我的笔记

struct MyNotesView: View {
    @ObservedObject var viewModel: TextbookViewModel
    @State private var expandedNoteId: String? = nil  // 当前展开的笔记ID（互斥展开）
    @State private var showTextbookReader = false
    @State private var selectedTextbook: Textbook?
    @State private var selectedPage: Int = 1
    @State private var selectedNoteForFocus: ReadingNote?
    @State private var selectedNoteForEdit: ReadingNote?

    var body: some View {
        ScrollView {
            if viewModel.isLoadingNotes {
                ProgressView()
                    .padding(40)
            } else if viewModel.readingNotes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("还没有学习笔记")
                        .foregroundColor(.secondary)
                    Text("在阅读教材时保存内容即可添加笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.readingNotes) { note in
                        ExpandableNoteCard(
                            note: note,
                            isExpanded: expandedNoteId == note.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if expandedNoteId == note.id {
                                        expandedNoteId = nil
                                    } else {
                                        expandedNoteId = note.id
                                    }
                                }
                            },
                            onJumpToTextbook: {
                                if let textbook = note.textbook {
                                    selectedTextbook = textbook
                                    selectedPage = note.page ?? 1
                                    showTextbookReader = true
                                }
                            },
                            onFocusMode: {
                                selectedNoteForFocus = note
                            },
                            onEdit: {
                                selectedNoteForEdit = note
                            },
                            onDelete: {
                                Task {
                                    _ = await viewModel.deleteNote(note.id)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.loadReadingNotes()
        }
        .fullScreenCover(isPresented: $showTextbookReader) {
            if let textbook = selectedTextbook {
                DismissibleCover {
                    TextbookStudyViewWithInitialPage(
                        textbook: textbook,
                        initialPage: selectedPage
                    )
                }
            }
        }
        .fullScreenCover(item: $selectedNoteForFocus) { note in
            DismissibleCover {
                NoteFocusView(note: note)
            }
        }
        .sheet(item: $selectedNoteForEdit) { note in
            NoteEditorSheet(note: note, viewModel: viewModel)
        }
    }
}

// MARK: - 笔记编辑器 Sheet

struct NoteEditorSheet: View {
    let note: ReadingNote
    @ObservedObject var viewModel: TextbookViewModel
    @Environment(\.dismiss) var dismiss

    @State private var editedQuery: String = ""
    @State private var editedContent: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("笔记标题", text: $editedQuery)
                }

                Section("内容") {
                    TextEditor(text: $editedContent)
                        .frame(minHeight: 200)
                }

                Section {
                    HStack {
                        Text("类型")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: note.typeIcon)
                                .font(.caption2)
                            Text(note.typeLabel)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(note.typeColor)
                        .cornerRadius(8)
                    }

                    if let page = note.page {
                        HStack {
                            Text("页码")
                            Spacer()
                            Text("P\(page)")
                                .foregroundColor(.secondary)
                        }
                    }

                    if let textbook = note.textbook {
                        HStack {
                            Text("教材")
                            Spacer()
                            Text(textbook.displayTitle)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveNote()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                editedQuery = note.query ?? ""
                // 使用 HTMLHelper 去除 HTML 标签，显示纯文本
                let rawContent = note.contentString ?? note.snippet ?? ""
                editedContent = HTMLHelper.stripHTML(rawContent)
            }
        }
    }

    private func saveNote() {
        isSaving = true
        Task {
            let success = await viewModel.updateNote(
                note.id,
                query: editedQuery.isEmpty ? nil : editedQuery,
                content: editedContent.isEmpty ? nil : editedContent
            )
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - 可展开的笔记卡片

struct ExpandableNoteCard: View {
    let note: ReadingNote
    let isExpanded: Bool
    let onToggle: () -> Void
    let onJumpToTextbook: () -> Void
    let onFocusMode: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部（始终显示）
            HStack(alignment: .top) {
                // 可点击展开的区域
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // 类型标签
                        HStack(spacing: 4) {
                            Image(systemName: note.typeIcon)
                                .font(.caption2)
                            Text(note.typeLabel)
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(note.typeColor)
                        .cornerRadius(8)

                        if let page = note.page {
                            Text("P\(page)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }

                        Spacer()

                        // 展开/折叠指示器
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 查询内容/标题
                    if let query = note.query, !query.isEmpty {
                        Text(query)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(isExpanded ? nil : 2)
                            .textSelection(.enabled)
                    }

                    // 摘要（折叠时显示）
                    if !isExpanded, let snippet = note.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    // 时间（折叠时显示）
                    if !isExpanded {
                        Text(note.createdAt?.relativeDescription ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggle)

                // 更多按钮菜单（独立于点击区域）
                Menu {
                    if note.textbook != nil {
                        Button {
                            onJumpToTextbook()
                        } label: {
                            Label("跳转教材", systemImage: "book")
                        }
                    }

                    Button {
                        onFocusMode()
                    } label: {
                        Label("专注模式", systemImage: "arrow.up.left.and.arrow.down.right")
                    }

                    Button {
                        onEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }

            // 展开内容
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isExpanded ? 0.1 : 0.05), radius: isExpanded ? 8 : 2, y: 2)
        .confirmationDialog("确定要删除这条笔记吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 展开内容

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 根据类型渲染不同内容
            noteContentByType

            // 教材信息
            if let textbook = note.textbook {
                textbookInfoRow(textbook)
            }

            // 时间和操作
            HStack {
                Text(note.createdAt?.relativeDescription ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 操作按钮
                HStack(spacing: 16) {
                    if note.textbook != nil {
                        Button(action: onJumpToTextbook) {
                            HStack(spacing: 4) {
                                Image(systemName: "book")
                                Text("跳转教材")
                            }
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                        }
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - 根据笔记类型渲染内容

    @ViewBuilder
    private var noteContentByType: some View {
        switch note.sourceType {
        case "practice", "exercise":
            // 练习题类型 - 使用 PracticeQuestionView
            practiceContent

        case "solving":
            // 解题类型
            solvingContent

        case "dict":
            // 查字类型
            dictContent

        default:
            // 其他类型 - 显示摘要和详细内容
            defaultContent
        }
    }

    // MARK: - 练习题内容

    @ViewBuilder
    private var practiceContent: some View {
        if let content = note.content,
           let questions = PracticeQuestionData.parse(from: content.value) {
            VStack(spacing: 12) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    PracticeQuestionView(question: question, index: index, compact: true)
                }
            }
            .textSelection(.enabled)
        } else if let snippet = note.snippet, !snippet.isEmpty {
            // 降级显示摘要
            Text(snippet)
                .font(.subheadline)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }

    // MARK: - 解题内容

    @ViewBuilder
    private var solvingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }

            if let content = note.contentString, !content.isEmpty {
                RichContentView(text: content)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - 查字内容

    @ViewBuilder
    private var dictContent: some View {
        if let content = note.content?.value as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                if let word = content["text"] as? String ?? content["word"] as? String {
                    Text(word)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                }

                if let pinyin = content["pinyin"] as? String {
                    Text(pinyin)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .textSelection(.enabled)
                }

                if let meaning = content["meaning"] as? String ?? content["definition"] as? String {
                    Text(meaning)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        } else if let snippet = note.snippet {
            Text(snippet)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    // MARK: - 默认内容

    @ViewBuilder
    private var defaultContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 摘录/snippet
            if let snippet = note.snippet, !snippet.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("摘录")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(snippet)
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
            }

            // 详细内容
            if let content = note.contentString, !content.isEmpty,
               content != note.snippet {
                VStack(alignment: .leading, spacing: 4) {
                    Text("详细内容")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    RichContentView(text: content)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - 教材信息行

    private func textbookInfoRow(_ textbook: Textbook) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(textbook.subjectColor.opacity(0.2))
                .frame(width: 32, height: 40)
                .overlay(
                    Text(textbook.subjectIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textbook.subjectColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(textbook.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(textbook.gradeName) · \(textbook.semester)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - 旧的 NoteCard（保留兼容）

struct NoteCard: View {
    let note: ReadingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 类型标签
                HStack(spacing: 4) {
                    Image(systemName: note.typeIcon)
                        .font(.caption2)
                    Text(note.typeLabel)
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(note.typeColor)
                .cornerRadius(8)

                if let page = note.page {
                    Text("P\(page)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let textbook = note.textbook {
                    Text(textbook.displayTitle)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }

                Spacer()
            }

            if let query = note.query, !query.isEmpty {
                Text(query)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
            }

            if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Text(note.createdAt?.relativeDescription ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct NoteDetailSheet: View {
    let note: ReadingNote
    @ObservedObject var viewModel: TextbookViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isDeleting = false
    @State private var showTextbookReader = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 类型和来源
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: note.typeIcon)
                            Text(note.typeLabel)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(note.typeColor)
                        .cornerRadius(8)

                        Spacer()

                        if let page = note.page {
                            Text("第 \(page) 页")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 教材信息 + 跳转按钮
                    if let textbook = note.textbook {
                        HStack {
                            HStack {
                                Image(systemName: "book.closed")
                                Text(textbook.displayTitle)
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)

                            Spacer()

                            // 跳转到教材按钮
                            Button {
                                showTextbookReader = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("打开教材")
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                            }
                        }
                    }

                    Divider()

                    // 查询内容
                    if let query = note.query, !query.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("查询内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(query)
                                .font(.title3)
                                .fontWeight(.medium)
                                .textSelection(.enabled)
                        }
                    }

                    // 摘录/内容
                    if let snippet = note.snippet, !snippet.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("摘录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(snippet)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // JSON 内容解析显示
                    if let content = note.contentString, !content.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("详细内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(content)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // 时间
                    Text(note.createdAt?.relativeDescription ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("笔记详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        Task {
                            isDeleting = true
                            let success = await viewModel.deleteNote(note.id)
                            isDeleting = false
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        // 跳转到教材阅读器（带初始页码）
        .fullScreenCover(isPresented: $showTextbookReader) {
            if let textbook = note.textbook {
                DismissibleCover {
                    TextbookStudyViewWithInitialPage(
                        textbook: textbook,
                        initialPage: note.page ?? 1
                    )
                }
            }
        }
    }
}

// MARK: - 带初始页码的教材阅读器包装

struct TextbookStudyViewWithInitialPage: View {
    let textbook: Textbook
    let initialPage: Int
    @Environment(\.dismiss) var dismiss

    @State private var fullTextbook: Textbook?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                // 加载中
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在加载教材...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if let error = errorMessage {
                // 错误状态
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("返回") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if let textbook = fullTextbook {
                // 使用新的阅读器架构
                TextbookReaderView(textbook: textbook)
                    .onAppear {
                        // 延迟设置初始页码，等待PDF加载完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(
                                name: .textbookJumpToPage,
                                object: nil,
                                userInfo: ["page": initialPage]
                            )
                        }
                    }
            }
        }
        .task {
            await loadTextbook()
        }
    }

    private func loadTextbook() async {
        print("📚 [TextbookStudy] loadTextbook called, textbook.id=\(textbook.id), pdfUrl=\(textbook.pdfUrl ?? "nil"), epubUrl=\(textbook.epubUrl ?? "nil"), contentType=\(textbook.contentType ?? "nil")")

        // 如果教材已经有内容（PDF 或 EPUB），直接使用
        if textbook.pdfUrl != nil || textbook.hasEpub {
            print("📚 [TextbookStudy] content exists, using directly (isEpub=\(textbook.isEpub))")
            fullTextbook = textbook
            isLoading = false
            return
        }

        print("📚 [TextbookStudy] no content, fetching from API...")

        // 否则通过 API 获取完整教材信息
        do {
            struct TextbookDetailResponse: Decodable {
                let textbook: Textbook
            }

            let response: TextbookDetailResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.textbooks)/\(textbook.id)"
            )

            print("📚 [TextbookStudy] API response received, pdfUrl=\(response.textbook.pdfUrl ?? "nil"), epubUrl=\(response.textbook.epubUrl ?? "nil"), contentType=\(response.textbook.contentType ?? "nil")")

            if response.textbook.pdfUrl != nil || response.textbook.hasEpub {
                fullTextbook = response.textbook
            } else {
                errorMessage = "该教材暂无内容文件"
            }
        } catch {
            print("📚 [TextbookStudy] API error: \(error)")
            errorMessage = "获取教材信息失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let textbookJumpToPage = Notification.Name("textbookJumpToPage")
}

// MARK: - 我的教材（收藏）

struct MyTextbooksView: View {
    @ObservedObject var viewModel: TextbookViewModel
    @State private var searchText = ""

    var filteredTextbooks: [Textbook] {
        if searchText.isEmpty {
            return viewModel.favoriteTextbooks
        }
        return viewModel.favoriteTextbooks.filter { textbook in
            textbook.title.localizedCaseInsensitiveContains(searchText) ||
            textbook.subjectName.localizedCaseInsensitiveContains(searchText) ||
            textbook.gradeName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索我的教材...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 内容
            ScrollView {
                if viewModel.isLoadingFavorites {
                    ProgressView()
                        .padding(40)
                } else if viewModel.favoriteTextbooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("还没有收藏教材")
                            .foregroundColor(.secondary)
                        Text("去电子书库看看")
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                    }
                    .padding(40)
                } else if filteredTextbooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("没有找到匹配的教材")
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)
                    ], spacing: 20) {
                        ForEach(filteredTextbooks) { textbook in
                            MyTextbookCard(textbook: textbook, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await viewModel.loadFavorites()
        }
    }
}

struct MyTextbookCard: View {
    let textbook: Textbook
    @ObservedObject var viewModel: TextbookViewModel

    // 阅读器状态
    @State private var showReader = false

    // 使用相同的书本比例
    private let bookRatio: CGFloat = 0.71
    private let bookHeight: CGFloat = 160  // 稍微小一点

    // 缓存状态
    private var isCached: Bool {
        if textbook.isEpub {
            return CacheService.shared.isEPUBCached(textbookId: textbook.id)
        } else {
            return DownloadManager.shared.isTextbookDownloaded(textbook.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 书本主体
            ZStack(alignment: .bottom) {
                bookCover
                    .frame(width: bookHeight * bookRatio, height: bookHeight)
                bookShelf
            }

            // 书名
            VStack(alignment: .leading, spacing: 2) {
                Text(textbook.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    Text(textbook.gradeName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // 下载/缓存状态指示
                    if isCached {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("已下载")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showReader = true
        }
        // 阅读器
        .fullScreenCover(isPresented: $showReader) {
            TextbookReaderView(textbook: textbook)
        }
    }

    private var bookCover: some View {
        ZStack {
            // 书脊效果
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.3), Color.black.opacity(0.1), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 6)
                Spacer()
            }
            .zIndex(2)

            // 封面
            Group {
                if let coverURL = textbook.coverImageURL {
                    CachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        bookPlaceholder
                    }
                } else {
                    bookPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // 左上角：已下载状态角标
            VStack {
                HStack {
                    if isCached {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .padding(6)
                    }
                    Spacer()
                }
                Spacer()
            }

            // 收藏标记（右上角）
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(4)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .padding(4)
                }
                Spacer()
            }
        }
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 3)
    }

    private var bookShelf: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [Color.clear, Color.black.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                .frame(height: 4)
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.75, blue: 0.65), Color(red: 0.7, green: 0.6, blue: 0.5)], startPoint: .top, endPoint: .bottom))
                .frame(height: 5)
                .cornerRadius(2)
        }
        .frame(width: bookHeight * bookRatio + 12)
        .offset(y: 5)
    }

    private var bookPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [textbook.subjectColor, textbook.subjectColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Text(textbook.subjectIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(textbook.subjectName)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - 教材封面

struct TextbookCover: View {
    let textbook: Textbook

    enum Size {
        case small, medium, large

        var width: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 80
            case .large: return 120
            }
        }

        var height: CGFloat {
            switch self {
            case .small: return 80
            case .medium: return 110
            case .large: return 160
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .title2
            case .medium: return .title
            case .large: return .largeTitle
            }
        }
    }

    var size: Size = .medium

    var body: some View {
        Group {
            // 使用完整的封面 URL
            if let coverURL = textbook.coverImageURL {
                CachedAsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
            } else {
                placeholderCover
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(8)
    }

    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [textbook.subjectColor, textbook.subjectColor.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(textbook.subjectIcon)
                .font(size.fontSize)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - 电子书库

struct TextbookLibraryView: View {
    @ObservedObject var viewModel: TextbookViewModel
    @State private var searchText = ""

    // 多选模式
    @State private var isSelectionMode = false
    @State private var selectedTextbookIds: Set<String> = []

    // 下载管理
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showDownloadSheet = false

    // 筛选选项
    private let subjects = ["全部", "语文", "数学", "英语", "科学", "道德法治"]
    private let grades = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    // 统计
    private var pdfCount: Int {
        viewModel.publicTextbooks.filter { $0.hasPdf }.count
    }
    private var noPdfCount: Int {
        viewModel.publicTextbooks.filter { !$0.hasPdf }.count
    }

    // 分页
    private var totalPages: Int {
        max(1, Int(ceil(Double(viewModel.totalCount) / Double(viewModel.pageSize))))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框（精简版）
            searchBar

            // 科目筛选栏
            subjectFilterBar

            // 年级筛选栏
            gradeFilterBar

            // 多选工具栏
            if isSelectionMode {
                selectionToolbar
            }

            // 下载状态栏
            if downloadManager.downloadingTextbookCount > 0 {
                downloadStatusBar
            }

            // 教材列表
            ScrollView {
                if viewModel.isLoading && viewModel.publicTextbooks.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.publicTextbooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无教材")
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                } else {
                    // 间距增大2倍：spacing 16->32, 行间距 20->40
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 32)
                    ], spacing: 40) {
                        ForEach(viewModel.publicTextbooks) { textbook in
                            LibraryTextbookCard(
                                textbook: textbook,
                                viewModel: viewModel,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedTextbookIds.contains(textbook.id),
                                onSelect: {
                                    toggleSelection(textbook.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)  // 增大水平边距
                    .padding(.vertical, 24)
                }
            }

            // 底部分页栏（集成统计信息）
            paginationBar
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadListView()
        }
        .onAppear {
            // 一页只显示两整行（约6本书）
            viewModel.pageSize = 6
        }
    }

    // MARK: - 搜索框（精简版）

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索教材名称...", text: $searchText)
                    .onSubmit {
                        Task { await viewModel.searchTextbooks(searchText) }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await viewModel.searchTextbooks("") }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // 多选按钮
            Button {
                withAnimation {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedTextbookIds.removeAll()
                    }
                }
            } label: {
                Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(isSelectionMode ? .appPrimary : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 科目筛选栏

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subjects, id: \.self) { subject in
                    let isSelected = (subject == "全部" && viewModel.selectedSubject.isEmpty) ||
                                   viewModel.selectedSubject == subject
                    Button {
                        Task {
                            if subject == "全部" {
                                await viewModel.applyFilters(
                                    subject: "",
                                    grade: viewModel.selectedGrade,
                                    semester: viewModel.selectedSemester,
                                    version: viewModel.selectedVersion
                                )
                            } else {
                                await viewModel.applyFilters(
                                    subject: subject,
                                    grade: viewModel.selectedGrade,
                                    semester: viewModel.selectedSemester,
                                    version: viewModel.selectedVersion
                                )
                            }
                        }
                    } label: {
                        Text(subject)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.appPrimary : Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 年级筛选栏

    private var gradeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(grades, id: \.self) { grade in
                    let isSelected = viewModel.selectedGrade == grade
                    let title = grade == 0 ? "全部年级" : "\(grade)年级"
                    Button {
                        Task {
                            await viewModel.applyFilters(
                                subject: viewModel.selectedSubject,
                                grade: grade,
                                semester: viewModel.selectedSemester,
                                version: viewModel.selectedVersion
                            )
                        }
                    } label: {
                        Text(title)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.blue : Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(Color(.systemGray6).opacity(0.5))
    }

    // MARK: - 底部分页栏（含统计信息）

    private var paginationBar: some View {
        HStack(spacing: 12) {
            // 上一页
            Button {
                Task {
                    await viewModel.loadPage(viewModel.currentPage - 1)
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(viewModel.currentPage <= 1 ? .gray.opacity(0.3) : .appPrimary)
            }
            .disabled(viewModel.currentPage <= 1 || viewModel.isLoading)

            Spacer()

            // 中间：统计信息 + 页码
            VStack(spacing: 2) {
                // 统计信息（紧凑显示）
                HStack(spacing: 8) {
                    Text("共\(viewModel.totalCount)本")
                        .foregroundColor(.primary)
                    Text("·")
                        .foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.green)
                        Text("\(pdfCount)")
                    }
                    if noPdfCount > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.doc")
                                .foregroundColor(.orange)
                            Text("\(noPdfCount)")
                        }
                    }
                }
                .font(.caption)

                // 页码显示
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("\(viewModel.currentPage) / \(totalPages)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 下一页
            Button {
                Task {
                    await viewModel.loadPage(viewModel.currentPage + 1)
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(viewModel.currentPage >= totalPages ? .gray.opacity(0.3) : .appPrimary)
            }
            .disabled(viewModel.currentPage >= totalPages || viewModel.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .top
        )
    }

    // MARK: - 多选工具栏

    private var selectionToolbar: some View {
        HStack(spacing: 16) {
            // 全选/取消全选
            Button {
                if selectedTextbookIds.count == downloadableTextbooks.count {
                    selectedTextbookIds.removeAll()
                } else {
                    selectedTextbookIds = Set(downloadableTextbooks.map { $0.id })
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedTextbookIds.count == downloadableTextbooks.count ? "checkmark.square.fill" : "square")
                    Text(selectedTextbookIds.count == downloadableTextbooks.count ? "取消全选" : "全选")
                }
                .font(.subheadline)
            }

            Divider()
                .frame(height: 20)

            // 已选数量
            Text("已选 \(selectedTextbookIds.count) 本")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // 下载按钮
            Button {
                startBatchDownload()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("下载")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedTextbookIds.isEmpty ? Color.gray : Color.appPrimary)
                .cornerRadius(8)
            }
            .disabled(selectedTextbookIds.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 下载状态栏

    private var downloadStatusBar: some View {
        Button {
            showDownloadSheet = true
        } label: {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)

                Text("正在下载 \(downloadManager.downloadingTextbookCount) 本教材...")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.appPrimary.opacity(0.1))
        }
    }

    // MARK: - 辅助方法

    private var downloadableTextbooks: [Textbook] {
        viewModel.publicTextbooks.filter { $0.hasPdf }
    }

    private func toggleSelection(_ id: String) {
        if selectedTextbookIds.contains(id) {
            selectedTextbookIds.remove(id)
        } else {
            selectedTextbookIds.insert(id)
        }
    }

    private func startBatchDownload() {
        let textbooksToDownload = viewModel.publicTextbooks
            .filter { selectedTextbookIds.contains($0.id) && $0.hasPdf }
            .compactMap { textbook -> (id: String, url: URL)? in
                guard let url = textbook.pdfFullURL else { return nil }
                return (id: textbook.id, url: url)
            }

        let _ = downloadManager.downloadTextbooks(textbooksToDownload)

        // 退出选择模式
        withAnimation {
            isSelectionMode = false
            selectedTextbookIds.removeAll()
        }
    }
}

struct LibraryTextbookCard: View {
    let textbook: Textbook
    @ObservedObject var viewModel: TextbookViewModel
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: (() -> Void)?

    // 阅读器状态
    @State private var showReader = false
    @ObservedObject private var downloadManager = DownloadManager.shared

    // 书本比例：中国课本约 185mm × 260mm，比例约 0.71:1
    private let bookRatio: CGFloat = 0.71
    private let bookHeight: CGFloat = 180

    private var downloadState: TextbookDownloadState {
        downloadManager.getTextbookDownloadState(textbook.id, pdfURL: textbook.pdfFullURL)
    }

    // EPUB 缓存状态
    private var isEpubCached: Bool {
        textbook.isEpub && CacheService.shared.isEPUBCached(textbookId: textbook.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 书本主体（带 3D 效果）
            ZStack(alignment: .bottom) {
                // 书本封面
                bookCover
                    .frame(width: bookHeight * bookRatio, height: bookHeight)

                // 底部书架/底座效果
                bookShelf
            }

            // 书名和信息
            VStack(alignment: .leading, spacing: 4) {
                Text(textbook.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    Text(textbook.gradeName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if textbook.hasPdf || textbook.hasEpub {
                        Text("·")
                            .foregroundColor(.secondary)

                        // 下载状态指示（PDF 或 EPUB）
                        if textbook.isEpub {
                            epubStatusIndicator
                        } else {
                            downloadStatusIndicator
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onSelect?()
            } else {
                showReader = true
            }
        }
        // 多选模式边框
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 3)
                .padding(-4)
        )
        // 阅读器
        .fullScreenCover(isPresented: $showReader) {
            TextbookReaderView(textbook: textbook)
        }
    }

    // MARK: - EPUB 状态指示器

    @ViewBuilder
    private var epubStatusIndicator: some View {
        if isEpubCached {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("已缓存")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        } else {
            HStack(spacing: 2) {
                Image(systemName: "book.closed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("EPUB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 下载状态指示器

    @ViewBuilder
    private var downloadStatusIndicator: some View {
        switch downloadState {
        case .downloaded:
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("已下载")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

        case .downloading(let progress):
            HStack(spacing: 4) {
                // 迷你进度圆环
                ZStack {
                    Circle()
                        .stroke(Color.appPrimary.opacity(0.2), lineWidth: 2)
                        .frame(width: 12, height: 12)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 12, height: 12)
                        .rotationEffect(.degrees(-90))
                }

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.appPrimary)
            }

        case .paused:
            HStack(spacing: 2) {
                Image(systemName: "pause.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("已暂停")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

        case .failed:
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text("失败")
                    .font(.caption2)
                    .foregroundColor(.red)
            }

        case .notDownloaded:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let size = textbook.formattedPdfSize {
                    Text(size)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 书本封面（3D 效果）

    private var bookCover: some View {
        ZStack {
            // 书脊阴影（左侧 3D 效果）
            HStack(spacing: 0) {
                // 书脊
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8)

                Spacer()
            }
            .zIndex(2)

            // 封面图片或占位符
            Group {
                if let coverURL = textbook.coverImageURL {
                    CachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        bookPlaceholder
                    }
                } else {
                    bookPlaceholder
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 4)
            )

            // 左上角：多选勾选框 / 下载状态图标
            VStack {
                HStack {
                    if isSelectionMode {
                        // 多选模式：显示勾选框
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .appPrimary : .white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .padding(6)
                    } else if textbook.hasPdf || textbook.hasEpub {
                        // 非多选模式：显示下载/缓存状态角标
                        if textbook.isEpub {
                            epubBadge
                        } else {
                            downloadBadge
                        }
                    }

                    Spacer()
                }
                Spacer()
            }

            // 右下角收藏按钮（非多选模式时显示）
            if !isSelectionMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            Task {
                                await viewModel.toggleFavorite(textbook)
                            }
                        } label: {
                            Image(systemName: viewModel.isFavorite(textbook.id) ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(viewModel.isFavorite(textbook.id) ? .red : .white)
                                .padding(6)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(6)
                    }
                }
            }
        }
        // 书本阴影
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 4)
        // 书本边框
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - 下载状态角标

    @ViewBuilder
    private var downloadBadge: some View {
        switch downloadState {
        case .downloaded:
            // 已下载：绿色勾
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
                .padding(6)

        case .downloading(let progress):
            // 下载中：进度圆环
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)

                Circle()
                    .stroke(Color.appPrimary.opacity(0.3), lineWidth: 3)
                    .frame(width: 20, height: 20)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            }
            .shadow(color: .black.opacity(0.2), radius: 2)
            .padding(6)

        case .paused:
            // 已暂停：橙色暂停图标
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
                .padding(6)

        case .failed:
            // 失败：红色感叹号
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
                .padding(6)

        case .notDownloaded:
            // 未下载：下载图标
            Button {
                startSingleDownload()
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 20, height: 20)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .padding(6)
        }
    }

    // MARK: - EPUB 缓存角标

    @ViewBuilder
    private var epubBadge: some View {
        if isEpubCached {
            // 已缓存：绿色勾
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
                .padding(6)
        } else {
            // 未缓存：EPUB 图标
            Image(systemName: "book.closed")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.blue.opacity(0.8))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 2)
                .padding(6)
        }
    }

    // MARK: - 书架底座

    private var bookShelf: some View {
        VStack(spacing: 0) {
            // 书本底部阴影
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 6)

            // 书架板
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.65),  // 木纹浅色
                            Color(red: 0.7, green: 0.6, blue: 0.5)      // 木纹深色
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 6)
                .cornerRadius(2)
        }
        .frame(width: bookHeight * bookRatio + 16)  // 比书本宽一点
        .offset(y: 6)
    }

    // MARK: - 封面占位符

    private var bookPlaceholder: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    textbook.subjectColor,
                    textbook.subjectColor.opacity(0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 科目图标
            VStack(spacing: 8) {
                Text(textbook.subjectIcon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text(textbook.subjectName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))

                Text(textbook.gradeName)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            // 模拟书本纹理
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 单个下载

    private func startSingleDownload() {
        guard let url = textbook.pdfFullURL else { return }

        let _ = downloadManager.download(
            url: url,
            fileName: "textbook_\(textbook.id).pdf",
            useBackground: true
        ) { _ in }
    }
}

// MARK: - 筛选弹窗

struct TextbookFilterSheet: View {
    @ObservedObject var viewModel: TextbookViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedSubject = ""
    @State private var selectedGrade = 0
    @State private var selectedSemester = ""
    @State private var selectedVersion = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("学科") {
                    Picker("选择学科", selection: $selectedSubject) {
                        Text("全部").tag("")
                        ForEach(viewModel.filterSubjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                }

                Section("年级") {
                    Picker("选择年级", selection: $selectedGrade) {
                        Text("全部").tag(0)
                        ForEach(viewModel.filterGrades, id: \.self) { grade in
                            Text("\(grade)年级").tag(grade)
                        }
                    }
                }

                Section("学期") {
                    Picker("选择学期", selection: $selectedSemester) {
                        Text("全部").tag("")
                        ForEach(viewModel.filterSemesters, id: \.self) { semester in
                            Text(semester).tag(semester)
                        }
                    }
                }

                Section("版本") {
                    Picker("选择版本", selection: $selectedVersion) {
                        Text("全部").tag("")
                        ForEach(viewModel.filterVersions, id: \.self) { version in
                            Text(version).tag(version)
                        }
                    }
                }
            }
            .navigationTitle("筛选教材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        Task {
                            await viewModel.applyFilters(
                                subject: selectedSubject,
                                grade: selectedGrade,
                                semester: selectedSemester,
                                version: selectedVersion
                            )
                            dismiss()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("重置") {
                        selectedSubject = ""
                        selectedGrade = 0
                        selectedSemester = ""
                        selectedVersion = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            selectedSubject = viewModel.selectedSubject
            selectedGrade = viewModel.selectedGrade
            selectedSemester = viewModel.selectedSemester
            selectedVersion = viewModel.selectedVersion
        }
    }
}

// MARK: - 旧版教材阅读器（已被 Features/Study/Reader/TextbookReaderView 替代）
// 保留 LegacyTextbookReaderView 用于兼容旧代码

struct LegacyTextbookReaderView: View {
    let textbook: Textbook
    @ObservedObject var viewModel: TextbookViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showToc = false

    var body: some View {
        NavigationStack {
            VStack {
                if textbook.hasPdf {
                    // PDF 阅读器
                    PDFReaderPlaceholder(textbook: textbook) {
                        dismiss()
                    }
                } else {
                    // HTML 课文内容
                    HTMLContentView(textbook: textbook, viewModel: viewModel)
                }
            }
            .navigationTitle(textbook.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showToc = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showToc) {
                TocSheet(textbook: textbook, viewModel: viewModel)
            }
        }
    }
}

struct PDFReaderPlaceholder: View {
    let textbook: Textbook
    var onClose: (() -> Void)?  // 关闭回调

    init(textbook: Textbook, onClose: (() -> Void)? = nil) {
        self.textbook = textbook
        self.onClose = onClose
    }

    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var showToolbar = true

    // 使用新的下载管理器
    @State private var downloadTask: DownloadTask?
    private let downloadManager = DownloadManager.shared

    var body: some View {
        ZStack {
            // 背景
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(error)
            } else if let pdfDoc = pdfDocument {
                // PDF 内容区
                VStack(spacing: 0) {
                    // PDF 视图
                    PDFKitView(document: pdfDoc, currentPage: $currentPage)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showToolbar.toggle()
                            }
                        }

                    // 底部工具栏
                    if showToolbar {
                        pdfBottomToolbar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                noPdfView
            }
        }
        .task {
            await loadPDF()
        }
    }

    // MARK: - 底部工具栏（类似 Web 端）

    private var pdfBottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 20) {
                // 上一页
                Button {
                    if currentPage > 1 {
                        withAnimation { currentPage -= 1 }
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(currentPage <= 1 ? .gray.opacity(0.3) : .appPrimary)
                }
                .disabled(currentPage <= 1)

                Spacer()

                // 页码显示和跳转
                HStack(spacing: 8) {
                    Text("第")
                        .foregroundColor(.secondary)
                    Text("\(currentPage)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                        .frame(minWidth: 30)
                    Text("/")
                        .foregroundColor(.secondary)
                    Text("\(totalPages)")
                        .foregroundColor(.secondary)
                    Text("页")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                Spacer()

                // 下一页
                Button {
                    if currentPage < totalPages {
                        withAnimation { currentPage += 1 }
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(currentPage >= totalPages ? .gray.opacity(0.3) : .appPrimary)
                }
                .disabled(currentPage >= totalPages)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private var loadingView: some View {
        ZStack {
            VStack(spacing: 24) {
                // 封面预览
                if let coverURL = textbook.coverImageURL {
                    CachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(textbook.subjectColor.opacity(0.2))
                            .frame(width: 140, height: 200)
                            .overlay(
                                Text(textbook.subjectIcon)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(textbook.subjectColor)
                            )
                    }
                }

                VStack(spacing: 12) {
                    Text(textbook.displayTitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 使用新的下载进度组件
                    if let task = downloadTask, task.state.isDownloading {
                        VStack(spacing: 8) {
                            DownloadProgressBar(task: task, showDetails: true)
                                .frame(width: 240)

                            if !task.speedText.isEmpty {
                                HStack(spacing: 8) {
                                    Text(task.speedText)
                                        .foregroundColor(.appPrimary)

                                    if !task.estimatedTimeRemaining.isEmpty {
                                        Text("·")
                                        Text("剩余 \(task.estimatedTimeRemaining)")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("准备中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 关闭按钮
                Button {
                    onClose?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text("取消加载")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 右上角关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("加载失败")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                Task { await loadPDF() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noPdfView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暂无PDF文件")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func loadPDF() async {
        isLoading = true
        loadError = nil

        // 使用完整的 PDF URL
        guard let url = textbook.pdfFullURL else {
            loadError = "未找到PDF文件"
            isLoading = false
            return
        }

        // 使用新的下载管理器（高速下载 + 缓存 + 断点续传）
        let task = downloadManager.downloadPDFWithProgress(url: url, textbookId: textbook.id)
        downloadTask = task

        // 如果已经缓存，直接加载
        if case .completed(let localURL) = task.state {
            await loadPDFDocument(from: localURL)
            return
        }

        // 等待下载完成
        do {
            let localURL = try await downloadManager.downloadPDF(url: url, textbookId: textbook.id)
            await loadPDFDocument(from: localURL)
        } catch {
            await MainActor.run {
                loadError = "下载失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    @MainActor
    private func loadPDFDocument(from url: URL) async {
        if let document = PDFDocument(url: url) {
            pdfDocument = document
            totalPages = document.pageCount
            isLoading = false
            #if DEBUG
            print("PDF 加载成功: \(totalPages) 页")
            #endif
        } else {
            loadError = "PDF文件格式无效"
            isLoading = false
        }
    }
}

// MARK: - PDFKit View

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.delegate = context.coordinator

        // 设置初始页面
        if let page = document.page(at: currentPage - 1) {
            pdfView.go(to: page)
        }

        // 监听页面变化
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let currentPDFPage = pdfView.currentPage {
            let pageIndex = document.index(for: currentPDFPage)
            if pageIndex + 1 != currentPage {
                if let newPage = document.page(at: currentPage - 1) {
                    pdfView.go(to: newPage)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: currentPage)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex + 1
            }
        }
    }
}

struct HTMLContentView: View {
    let textbook: Textbook
    @ObservedObject var viewModel: TextbookViewModel

    var body: some View {
        ScrollView {
            if viewModel.textbookToc.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)

                    Text("暂无课文内容")
                        .foregroundColor(.secondary)

                    Text("请从目录选择课程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.textbookToc) { unit in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("第\(unit.unitNumber)单元 \(unit.title)")
                                .font(.headline)
                                .padding(.top)

                            if let lessons = unit.lessons {
                                ForEach(lessons) { lesson in
                                    LessonRow(lesson: lesson)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.loadTextbookToc(textbook.id)
        }
    }
}

struct LessonRow: View {
    let lesson: TextbookLesson

    var body: some View {
        HStack {
            Text("\(lesson.lessonNumber). \(lesson.title)")
                .font(.subheadline)

            Spacer()

            if lesson.status == "APPROVED" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TocSheet: View {
    let textbook: Textbook
    @ObservedObject var viewModel: TextbookViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.textbookToc) { unit in
                    Section("第\(unit.unitNumber)单元 \(unit.title)") {
                        if let lessons = unit.lessons {
                            ForEach(lessons) { lesson in
                                Button {
                                    // 选择课程后关闭
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text("\(lesson.lessonNumber). \(lesson.title)")
                                        Spacer()
                                        if lesson.status == "APPROVED" {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadTextbookToc(textbook.id)
        }
    }
}

// MARK: - 读书笔记区域

struct ReadingSection: View {
    @State private var activeTab: ReadingTab = .bookshelf

    enum ReadingTab: String, CaseIterable {
        case bookshelf = "我的书架"
        case feed = "阅读动态"
        case search = "书库搜索"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 子标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(ReadingTab.allCases, id: \.self) { tab in
                        TextbookTabButton(title: tab.rawValue, isSelected: activeTab == tab) {
                            activeTab = tab
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            // 内容
            Group {
                switch activeTab {
                case .bookshelf:
                    BookshelfView()
                case .feed:
                    ReadingFeedView()
                case .search:
                    BookSearchView()
                }
            }
        }
    }
}

// MARK: - 我的书架

struct BookshelfView: View {
    @State private var books: [BookItem] = []
    @State private var isLoading = false
    @State private var showAddBook = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(40)
            } else if books.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("暂无书籍，快去添加吧")
                        .foregroundColor(.secondary)
                    Button("添加书籍") {
                        showAddBook = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(books) { book in
                        BookCard(book: book)
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddBook = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        books = [
            BookItem(id: 1, title: "小王子", author: "安托万·德·圣-埃克苏佩里", status: "READING", progress: 65, totalPages: 120),
            BookItem(id: 2, title: "夏洛的网", author: "E.B.怀特", status: "COMPLETED", progress: 100, totalPages: 180),
        ]
        isLoading = false
    }
}

struct BookItem: Identifiable {
    let id: Int
    let title: String
    let author: String
    let status: String
    let progress: Int
    let totalPages: Int

    var statusLabel: String {
        switch status {
        case "WANT_TO_READ": return "想读"
        case "READING": return "在读"
        case "COMPLETED": return "读完"
        case "DROPPED": return "弃读"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "READING": return .blue
        case "COMPLETED": return .green
        case "DROPPED": return .orange
        default: return .gray
        }
    }
}

struct BookCard: View {
    let book: BookItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面占位
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                )

            Text(book.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(book.author)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack {
                Text(book.statusLabel)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(book.statusColor)
                    .cornerRadius(4)

                Spacer()

                Text("\(book.progress)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(book.progress) / 100)
                .tint(book.statusColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 阅读动态

struct ReadingFeedView: View {
    @State private var logs: [ReadingLog] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(40)
            } else if logs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("还没有阅读动态")
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(logs) { log in
                        ReadingLogCard(log: log)
                    }
                }
                .padding()
            }
        }
        .task {
            await loadLogs()
        }
    }

    private func loadLogs() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        logs = [
            ReadingLog(id: 1, userName: "小明", bookTitle: "小王子", chapterInfo: "第五章", readPages: 15, content: "今天读到小王子和玫瑰花的故事，很感动...", likesCount: 5, createdAt: Date()),
        ]
        isLoading = false
    }
}

struct ReadingLog: Identifiable {
    let id: Int
    let userName: String
    let bookTitle: String
    let chapterInfo: String
    let readPages: Int
    let content: String
    let likesCount: Int
    let createdAt: Date
}

struct ReadingLogCard: View {
    let log: ReadingLog
    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(log.userName.prefix(1)))
                            .foregroundColor(.appPrimary)
                            .fontWeight(.medium)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(log.userName)
                            .fontWeight(.medium)
                        Text("读了")
                            .foregroundColor(.secondary)
                        Text("《\(log.bookTitle)》")
                            .foregroundColor(.appPrimary)
                    }
                    .font(.subheadline)

                    Text("\(log.chapterInfo) · \(log.readPages)页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(log.content)
                .font(.body)

            HStack {
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    isLiked.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(log.likesCount + (isLiked ? 1 : 0))")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 书库搜索

struct BookSearchView: View {
    @State private var searchText = ""
    @State private var books: [BookItem] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索书名或作者", text: $searchText)
                    .onSubmit {
                        Task { await searchBooks() }
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()

            // 结果列表
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(40)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(books) { book in
                            SearchResultCard(book: book)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await searchBooks()
        }
    }

    private func searchBooks() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        books = [
            BookItem(id: 1, title: "小王子", author: "安托万·德·圣-埃克苏佩里", status: "", progress: 0, totalPages: 120),
            BookItem(id: 2, title: "夏洛的网", author: "E.B.怀特", status: "", progress: 0, totalPages: 180),
            BookItem(id: 3, title: "窗边的小豆豆", author: "黑柳彻子", status: "", progress: 0, totalPages: 250),
        ]
        isLoading = false
    }
}

struct SearchResultCard: View {
    let book: BookItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面占位
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, .pink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                )

            Text(book.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(book.author)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text("共\(book.totalPages)页")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ReadingView()
}

//
//  NotesTabView.swift
//  pinghu12250
//
//  笔记主视图（7个Tab）
//  替换原有的AllNotesView
//  功能与Web端MyNotes.vue对齐
//

import SwiftUI

/// 笔记主视图（7个Tab）
struct NotesMainView: View {
    @StateObject private var viewModel = TextbookViewModel()

    // MARK: - 状态

    @State private var selectedTab: NoteTab = .all
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newest
    @State private var isLoading = false
    @State private var showPractice = false
    @State private var practiceNotes: [ReadingNote] = []
    @State private var selectedNote: ReadingNote?
    // showNoteFocus 已移除，改用 .sheet(item:) 绑定 selectedNote
    @State private var practiceCountMap: [String: Int] = [:]  // 生词ID -> 练习次数

    // MARK: - 计算属性

    /// 筛选后的笔记
    private var filteredNotes: [ReadingNote] {
        var notes = viewModel.readingNotes

        // 按Tab筛选
        if let sourceTypes = selectedTab.sourceTypes {
            notes = notes.filter { sourceTypes.contains($0.sourceType) }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            notes = notes.filter {
                ($0.query ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.snippet ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        // 排序
        notes = notes.sorted { n1, n2 in
            let date1 = parseDate(n1.createdAt)
            let date2 = parseDate(n2.createdAt)
            return sortOrder == .newest ? date1 > date2 : date1 < date2
        }

        return notes
    }

    /// 生词笔记
    private var vocabularyNotes: [ReadingNote] {
        viewModel.readingNotes.filter { $0.sourceType == "dict" }
    }

    /// 按教材分组的笔记
    private var notesByTextbook: [String: [ReadingNote]] {
        var result: [String: [ReadingNote]] = [:]
        for note in filteredNotes {
            let textbookId = note.textbookId ?? "unknown"
            if result[textbookId] == nil {
                result[textbookId] = []
            }
            result[textbookId]?.append(note)
        }
        return result
    }

    /// 教材名称映射
    private var textbookNames: [String: String] {
        var result: [String: String] = [:]
        for note in viewModel.readingNotes {
            if let textbookId = note.textbookId,
               let textbook = note.textbook {
                result[textbookId] = textbook.title
            }
        }
        result["unknown"] = "未分类"
        return result
    }

    /// 按时间分组的笔记
    private var notesByDate: [(String, [ReadingNote])] {
        var groups: [String: [ReadingNote]] = [:]

        for note in filteredNotes {
            let groupKey = dateGroupKey(note.createdAt)
            if groups[groupKey] == nil {
                groups[groupKey] = []
            }
            groups[groupKey]?.append(note)
        }

        // 排序分组
        let orderedKeys = ["收藏", "今天", "昨天", "本周", "更早"]
        return orderedKeys.compactMap { key in
            if let notes = groups[key], !notes.isEmpty {
                return (key, notes)
            }
            return nil
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏（保留iOS特色）
            statsBar

            // Tab栏
            ScrollableTabBar(selectedTab: $selectedTab)

            // 搜索栏
            searchBar

            // 内容区
            TabView(selection: $selectedTab) {
                // 全部
                allNotesView.tag(NoteTab.all)

                // 按时间
                timelineView.tag(NoteTab.timeline)

                // 按教材
                textbookGroupView.tag(NoteTab.textbook)

                // 生词本
                vocabularyView.tag(NoteTab.vocabulary)

                // 摘录
                filteredListView.tag(NoteTab.excerpt)

                // 练习
                filteredListView.tag(NoteTab.practice)

                // 解题
                filteredListView.tag(NoteTab.solving)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("我的笔记")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .fullScreenCover(isPresented: $showPractice) {
            CharacterPracticeView(
                notes: practiceNotes,
                onClose: {
                    showPractice = false
                    Task { await loadData() }
                },
                onComplete: { _ in
                    Task { await loadData() }
                }
            )
        }
        // 修改前：.sheet(isPresented: $showNoteFocus) { if let note = selectedNote { ... } }
        // 修改后：使用 .sheet(item:) 绑定，selectedNote 非 nil 时自动显示
        .sheet(item: $selectedNote) { note in
            NoteFocusViewWrapper(note: note)
        }
    }

    // MARK: - 统计栏

    private var statsBar: some View {
        HStack(spacing: 16) {
            // 总数
            HStack(spacing: 4) {
                Text("\(viewModel.readingNotes.count)")
                    .font(.system(size: 18, weight: .semibold))
                Text("条笔记")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 类型统计
            HStack(spacing: 12) {
                StatIcon(icon: "character.book.closed", count: vocabularyNotes.count, color: .blue)
                StatIcon(icon: "sparkles", count: countByType(["explain", "ai_analysis", "ai_quote"]), color: .purple)
                StatIcon(icon: "highlighter", count: countByType(["pdf_selection", "highlight"]), color: .orange)
                StatIcon(icon: "checkmark.circle", count: countByType(["practice", "exercise", "writing_practice"]), color: .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func countByType(_ types: [String]) -> Int {
        viewModel.readingNotes.filter { types.contains($0.sourceType) }.count
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索笔记...", text: $searchText)
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
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // 排序
            Menu {
                Button {
                    sortOrder = .newest
                } label: {
                    Label("最新优先", systemImage: sortOrder == .newest ? "checkmark" : "")
                }

                Button {
                    sortOrder = .oldest
                } label: {
                    Label("最早优先", systemImage: sortOrder == .oldest ? "checkmark" : "")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder.displayName)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 全部视图

    private var allNotesView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        NoteRowView(note: note)
                            .onTapGesture {
                                selectedNote = note
                                // showNoteFocus = true 已移除，selectedNote 非 nil 自动触发 sheet
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteNote(note) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await toggleFavorite(note) }
                                } label: {
                                    Label(
                                        note.isFavorite == true ? "取消收藏" : "收藏",
                                        systemImage: note.isFavorite == true ? "heart.slash" : "heart"
                                    )
                                }
                                .tint(note.isFavorite == true ? .gray : .red)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 时间线视图

    private var timelineView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notesByDate.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(notesByDate, id: \.0) { group, notes in
                        Section(header: Text(group)) {
                            ForEach(notes) { note in
                                NoteRowView(note: note)
                                    .onTapGesture {
                                        selectedNote = note
                                        // showNoteFocus = true 已移除
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 教材分组视图

    private var textbookGroupView: some View {
        TextbookGroupView(
            notesByTextbook: notesByTextbook,
            textbookNames: textbookNames,
            isLoading: isLoading,
            onNoteSelect: { note in
                selectedNote = note
                // showNoteFocus = true 已移除
            },
            onDelete: { note in
                Task { await deleteNote(note) }
            },
            onFavorite: { note in
                Task { await toggleFavorite(note) }
            }
        )
    }

    // MARK: - 生词本视图

    private var vocabularyView: some View {
        VocabularyGridView(
            notes: vocabularyNotes,
            practiceCountMap: practiceCountMap,
            isLoading: isLoading,
            onStartPractice: { notes in
                practiceNotes = notes
                showPractice = true
            },
            onFavorite: { note in
                Task { await toggleFavorite(note) }
            },
            onDelete: { note in
                Task { await deleteNote(note) }
            },
            onViewDetail: { note in
                selectedNote = note
                // showNoteFocus = true 已移除，使用 .sheet(item:) 绑定
            }
        )
    }

    // MARK: - 筛选列表视图

    private var filteredListView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        NoteRowView(note: note)
                            .onTapGesture {
                                selectedNote = note
                                // showNoteFocus = true 已移除，selectedNote 非 nil 自动触发 sheet
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("还没有笔记")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在阅读时创建笔记会显示在这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据操作

    private func loadData() async {
        isLoading = true
        await viewModel.loadReadingNotes()
        // 构建练习次数映射
        buildPracticeCountMap()
        isLoading = false
    }

    /// 构建练习次数映射
    /// 遍历所有 writing_practice 类型的笔记，统计每个原始生词的练习次数
    private func buildPracticeCountMap() {
        var map: [String: Int] = [:]

        // 获取所有练习记录
        let practiceRecords = viewModel.readingNotes.filter { $0.sourceType == "writing_practice" }

        for record in practiceRecords {
            // 尝试从 content 中获取 originalNoteId
            if let content = record.content,
               let dict = content.value as? [String: Any],
               let originalNoteId = dict["originalNoteId"] as? String {
                map[originalNoteId, default: 0] += 1
            }
            // 也可能通过 query（字符）关联
            else if let query = record.query, !query.isEmpty {
                // 查找同名的 dict 类型笔记
                if let dictNote = vocabularyNotes.first(where: { $0.query == query }) {
                    map[dictNote.id, default: 0] += 1
                }
            }
        }

        practiceCountMap = map
    }

    private func deleteNote(_ note: ReadingNote) async {
        _ = await viewModel.deleteNote(note.id)
    }

    private func toggleFavorite(_ note: ReadingNote) async {
        _ = await viewModel.toggleNoteFavorite(note.id)
    }

    // MARK: - 辅助方法

    private func parseDate(_ dateString: String?) -> Date {
        guard let str = dateString else { return Date.distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str) ?? Date.distantPast
    }

    private func dateGroupKey(_ dateString: String?) -> String {
        let date = parseDate(dateString)
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                  date > weekAgo {
            return "本周"
        } else {
            return "更早"
        }
    }
}

// MARK: - 排序选项

private enum SortOrder {
    case newest, oldest

    var displayName: String {
        switch self {
        case .newest: return "最新优先"
        case .oldest: return "最早优先"
        }
    }
}

// MARK: - 统计图标

private struct StatIcon: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 笔记行视图

private struct NoteRowView: View {
    let note: ReadingNote

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: typeIcon)
                .font(.system(size: 14))
                .foregroundColor(typeColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(note.query ?? note.snippet ?? "笔记")
                    .font(.system(size: 14))
                    .lineLimit(1)

                // 元信息
                HStack(spacing: 8) {
                    Text(note.typeLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.1))
                        .foregroundColor(typeColor)
                        .cornerRadius(4)

                    if let page = note.page {
                        Text("P\(page)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let date = note.createdAt {
                        Text(formatDate(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if note.isFavorite == true {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var typeIcon: String {
        switch note.sourceType {
        case "dict": return "character.book.closed"
        case "search": return "magnifyingglass"
        case "explain", "ai_analysis", "ai_quote": return "sparkles"
        case "pdf_selection", "highlight": return "highlighter"
        case "practice", "exercise": return "checkmark.circle"
        case "solving": return "questionmark.circle"
        case "writing_practice": return "pencil.line"
        case "drawing": return "scribble"
        default: return "note.text"
        }
    }

    private var typeColor: Color {
        switch note.sourceType {
        case "dict": return .blue
        case "search": return .gray
        case "explain", "ai_analysis", "ai_quote": return .purple
        case "pdf_selection", "highlight": return .orange
        case "practice", "exercise": return .green
        case "solving": return .red
        case "writing_practice": return .teal
        case "drawing": return .brown
        default: return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return "" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM/dd HH:mm"
        return displayFormatter.string(from: date)
    }
}

// MARK: - NoteFocusView包装器

private struct NoteFocusViewWrapper: View {
    let note: ReadingNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 直接使用 NoteFocusView，不嵌套 NavigationView
        // 因为 NoteFocusView 内部有自己的导航栏
        NoteFocusView(note: note)
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        NotesMainView()
    }
}

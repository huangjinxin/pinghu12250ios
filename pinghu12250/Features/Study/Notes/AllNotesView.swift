//
//  AllNotesView.swift
//  pinghu12250
//
//  统一笔记入口 - 时间流布局 + 收藏置顶
//  优化版：滑动操作、折叠筛选器、弹簧动画、触觉反馈
//

import SwiftUI
import Combine

// MARK: - 统一笔记入口视图

struct AllNotesView: View {
    @StateObject private var viewModel = TextbookViewModel()
    @State private var searchText: String = ""
    @State private var expandedNoteId: String? = nil
    @State private var textbookReaderItem: TextbookReaderItem?
    @State private var selectedNoteForFocus: ReadingNote?

    // 筛选器状态
    @State private var isFilterExpanded = false
    @State private var selectedTypeFilter: NoteFilterType = .all
    @State private var selectedTextbookFilter: String? = nil

    // 排序
    @State private var sortOrder: NoteSortOrder = .latestFirst

    // 统计栏折叠状态（滚动时自动折叠）
    @State private var isStatsCollapsed = false
    @State private var lastScrollOffset: CGFloat = 0

    // 触觉反馈
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - 教材阅读器包装结构（用于 fullScreenCover item 绑定）

    struct TextbookReaderItem: Identifiable {
        let id = UUID()
        let textbook: Textbook
        let page: Int
    }

    // MARK: - 筛选类型枚举

    enum NoteFilterType: String, CaseIterable {
        case all = "全部"
        case dict = "查字"
        case ai = "AI"
        case highlight = "摘录"
        case practice = "练习"
        case solving = "解题"

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .dict: return "character.book.closed"
            case .ai: return "sparkles"
            case .highlight: return "highlighter"
            case .practice: return "checkmark.circle"
            case .solving: return "lightbulb"
            }
        }

        var color: Color {
            switch self {
            case .all: return .gray
            case .dict: return .orange
            case .ai: return .green
            case .highlight: return .blue
            case .practice: return .purple
            case .solving: return .cyan
            }
        }

        var sourceTypes: [String] {
            switch self {
            case .all: return []
            case .dict: return ["dict"]
            case .ai: return ["explain", "ai_analysis", "ai_quote"]
            case .highlight: return ["pdf_selection", "highlight", "user_note"]
            case .practice: return ["practice", "exercise"]
            case .solving: return ["solving"]
            }
        }
    }

    // MARK: - 排序枚举

    enum NoteSortOrder: String, CaseIterable {
        case latestFirst = "最新优先"
        case oldestFirst = "最早优先"
        case byPage = "按页码"
        case byTextbook = "按教材"
    }

    // MARK: - 时间分组枚举

    enum TimeGroup: String, CaseIterable {
        case favorites = "收藏"
        case today = "今天"
        case yesterday = "昨天"
        case thisWeek = "本周"
        case earlier = "更早"

        var icon: String {
            switch self {
            case .favorites: return "star.fill"
            case .today: return "calendar"
            case .yesterday: return "calendar.badge.minus"
            case .thisWeek: return "calendar.badge.clock"
            case .earlier: return "clock.arrow.circlepath"
            }
        }

        var color: Color {
            switch self {
            case .favorites: return .orange
            case .today: return .blue
            case .yesterday: return .indigo
            case .thisWeek: return .purple
            case .earlier: return .gray
            }
        }
    }

    // MARK: - 统计计算属性

    private var noteCount: Int { viewModel.readingNotes.count }

    private var textbookCount: Int {
        Set(viewModel.readingNotes.compactMap { $0.textbookId }).count
    }

    private var uniqueTextbooks: [Textbook] {
        var seen = Set<String>()
        return viewModel.readingNotes.compactMap { $0.textbook }.filter { textbook in
            guard !seen.contains(textbook.id) else { return false }
            seen.insert(textbook.id)
            return true
        }
    }

    // 各类型笔记数量
    private var dictCount: Int {
        viewModel.readingNotes.filter { $0.sourceType == "dict" }.count
    }
    private var aiCount: Int {
        viewModel.readingNotes.filter { ["explain", "ai_analysis", "ai_quote"].contains($0.sourceType) }.count
    }
    private var highlightCount: Int {
        viewModel.readingNotes.filter { ["pdf_selection", "highlight", "user_note"].contains($0.sourceType) }.count
    }
    private var practiceCount: Int {
        viewModel.readingNotes.filter { ["practice", "exercise"].contains($0.sourceType) }.count
    }
    private var solvingCount: Int {
        viewModel.readingNotes.filter { $0.sourceType == "solving" }.count
    }

    // 今日笔记数
    private var todayCount: Int {
        filterNotesByTimeGroup(viewModel.readingNotes, group: .today).count
    }

    // 本周笔记数
    private var weekCount: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return viewModel.readingNotes.filter { note in
            if let date = note.parsedCreatedAt {
                return date >= weekAgo
            }
            return false
        }.count
    }

    // MARK: - 过滤后的笔记

    private var filteredNotes: [ReadingNote] {
        var notes = viewModel.readingNotes

        // 搜索过滤
        if !searchText.isEmpty {
            notes = notes.filter { note in
                (note.query?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.snippet?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // 类型过滤
        if selectedTypeFilter != .all {
            notes = notes.filter { note in
                selectedTypeFilter.sourceTypes.contains(note.sourceType)
            }
        }

        // 教材过滤
        if let textbookId = selectedTextbookFilter {
            notes = notes.filter { $0.textbookId == textbookId }
        }

        // 排序
        switch sortOrder {
        case .latestFirst:
            notes.sort { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .oldestFirst:
            notes.sort { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        case .byPage:
            notes.sort { ($0.page ?? 0) < ($1.page ?? 0) }
        case .byTextbook:
            notes.sort { ($0.textbook?.displayTitle ?? "") < ($1.textbook?.displayTitle ?? "") }
        }

        return notes
    }

    // MARK: - 时间分组

    private var groupedNotesByTime: [(group: TimeGroup, notes: [ReadingNote])] {
        var result: [(group: TimeGroup, notes: [ReadingNote])] = []

        // 收藏的笔记（基于 isFavorite 标记）
        let favoriteNotes = filteredNotes.filter { $0.isFavorite == true }
        if !favoriteNotes.isEmpty {
            result.append((group: .favorites, notes: favoriteNotes))
        }

        // 按时间分组（排除已收藏的）
        let nonFavoriteNotes = filteredNotes.filter { $0.isFavorite != true }

        let todayNotes = filterNotesByTimeGroup(nonFavoriteNotes, group: .today)
        if !todayNotes.isEmpty {
            result.append((group: .today, notes: todayNotes))
        }

        let yesterdayNotes = filterNotesByTimeGroup(nonFavoriteNotes, group: .yesterday)
        if !yesterdayNotes.isEmpty {
            result.append((group: .yesterday, notes: yesterdayNotes))
        }

        let thisWeekNotes = filterNotesByTimeGroup(nonFavoriteNotes, group: .thisWeek)
        if !thisWeekNotes.isEmpty {
            result.append((group: .thisWeek, notes: thisWeekNotes))
        }

        let earlierNotes = filterNotesByTimeGroup(nonFavoriteNotes, group: .earlier)
        if !earlierNotes.isEmpty {
            result.append((group: .earlier, notes: earlierNotes))
        }

        return result
    }

    private func filterNotesByTimeGroup(_ notes: [ReadingNote], group: TimeGroup) -> [ReadingNote] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart)!

        return notes.filter { note in
            guard let date = note.parsedCreatedAt else { return group == .earlier }

            switch group {
            case .favorites:
                return false // 由调用方处理
            case .today:
                return date >= todayStart
            case .yesterday:
                return date >= yesterdayStart && date < todayStart
            case .thisWeek:
                return date >= weekStart && date < yesterdayStart
            case .earlier:
                return date < weekStart
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏（一行紧凑显示，点击展开/折叠）
            compactStatsBar

            // 搜索栏 + 筛选按钮
            searchAndFilterBar

            // 折叠筛选器
            if isFilterExpanded {
                collapsibleFilterPanel
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }

            // 当前筛选条件提示
            if hasActiveFilters {
                activeFiltersBar
            }

            // 笔记列表（时间流）
            notesTimelineView
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await viewModel.loadReadingNotes()
        }
        .refreshable {
            await viewModel.loadReadingNotes(refresh: true)
        }
        .fullScreenCover(item: $textbookReaderItem) { item in
            DismissibleCover {
                TextbookStudyViewWithInitialPage(
                    textbook: item.textbook,
                    initialPage: item.page
                )
            }
        }
        .fullScreenCover(item: $selectedNoteForFocus) { note in
            DismissibleCover {
                NoteFocusView(note: note)
            }
        }
    }

    // MARK: - 紧凑统计栏（一行显示，点击展开详情）

    private var compactStatsBar: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isStatsCollapsed.toggle()
            }
            impactFeedback.impactOccurred()
        } label: {
            HStack(spacing: 12) {
                // 总数
                HStack(spacing: 4) {
                    Text("\(noteCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                    Text("条笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 类型统计（紧凑）
                if !isStatsCollapsed {
                    HStack(spacing: 8) {
                        compactTypeStat(icon: "character.book.closed", count: dictCount, color: .orange)
                        compactTypeStat(icon: "sparkles", count: aiCount, color: .green)
                        compactTypeStat(icon: "highlighter", count: highlightCount, color: .blue)
                        compactTypeStat(icon: "checkmark.circle", count: practiceCount, color: .purple)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // 展开指示
                Image(systemName: isStatsCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }

    // 紧凑类型统计
    private func compactTypeStat(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 搜索栏 + 筛选按钮

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索笔记...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        impactFeedback.impactOccurred()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(10)

            // 筛选按钮
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isFilterExpanded.toggle()
                }
                impactFeedback.impactOccurred()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16))
                    Text("筛选")
                        .font(.subheadline)
                    Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(hasActiveFilters ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(hasActiveFilters ? Color.appPrimary : Color(.systemBackground))
                .cornerRadius(10)
            }

            // 排序按钮
            Menu {
                ForEach(NoteSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                        selectionFeedback.selectionChanged()
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    // MARK: - 是否有激活的筛选条件

    private var hasActiveFilters: Bool {
        selectedTypeFilter != .all || selectedTextbookFilter != nil
    }

    // MARK: - 折叠筛选器面板

    private var collapsibleFilterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 教材筛选
            VStack(alignment: .leading, spacing: 8) {
                Text("教材")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 全部
                        filterChipButton(
                            title: "全部",
                            isSelected: selectedTextbookFilter == nil,
                            color: .gray
                        ) {
                            selectedTextbookFilter = nil
                        }

                        // 各教材
                        ForEach(uniqueTextbooks, id: \.id) { textbook in
                            filterChipButton(
                                title: textbook.displayTitle,
                                icon: textbook.subjectIcon,
                                isSelected: selectedTextbookFilter == textbook.id,
                                color: textbook.subjectColor
                            ) {
                                selectedTextbookFilter = textbook.id
                            }
                        }
                    }
                }
            }

            // 类型筛选
            VStack(alignment: .leading, spacing: 8) {
                Text("类型")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NoteFilterType.allCases, id: \.self) { filter in
                            filterChipButton(
                                title: filter.rawValue,
                                icon: filter.icon,
                                count: getFilterCount(filter),
                                isSelected: selectedTypeFilter == filter,
                                color: filter.color
                            ) {
                                selectedTypeFilter = filter
                            }
                        }
                    }
                }
            }

            // 重置按钮
            if hasActiveFilters {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTypeFilter = .all
                        selectedTextbookFilter = nil
                    }
                    impactFeedback.impactOccurred()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置筛选")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // 筛选 Chip 按钮
    private func filterChipButton(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            selectionFeedback.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if let icon = icon {
                    if icon.count == 1 {
                        Text(icon)
                            .font(.caption)
                    } else {
                        Image(systemName: icon)
                            .font(.caption)
                    }
                }
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }

    private func getFilterCount(_ filter: NoteFilterType) -> Int {
        if filter == .all {
            return viewModel.readingNotes.count
        }
        return viewModel.readingNotes.filter { filter.sourceTypes.contains($0.sourceType) }.count
    }

    // MARK: - 当前筛选条件提示栏

    private var activeFiltersBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("已筛选:")
                .font(.caption)
                .foregroundColor(.secondary)

            if let textbookId = selectedTextbookFilter,
               let textbook = uniqueTextbooks.first(where: { $0.id == textbookId }) {
                Text(textbook.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
            }

            if selectedTypeFilter != .all {
                if selectedTextbookFilter != nil {
                    Text("·")
                        .foregroundColor(.secondary)
                }
                Text(selectedTypeFilter.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTypeFilter.color)
            }

            Spacer()

            Text("\(filteredNotes.count) 条结果")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.9))
    }

    // MARK: - 笔记时间流视图

    private var notesTimelineView: some View {
        Group {
            if viewModel.isLoadingNotes {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(groupedNotesByTime, id: \.group) { group, notes in
                        Section {
                            ForEach(notes) { note in
                                TimelineNoteCard(
                                    note: note,
                                    isExpanded: expandedNoteId == note.id,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            expandedNoteId = expandedNoteId == note.id ? nil : note.id
                                        }
                                        impactFeedback.impactOccurred()
                                    },
                                    onJumpToTextbook: {
                                        if let textbook = note.textbook {
                                            // 延迟显示，等待确认对话框完全关闭
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                textbookReaderItem = TextbookReaderItem(
                                                    textbook: textbook,
                                                    page: note.page ?? 1
                                                )
                                            }
                                        }
                                    },
                                    onFocusMode: {
                                        selectedNoteForFocus = note
                                    },
                                    onFavorite: {
                                        Task {
                                            _ = await viewModel.toggleNoteFavorite(note.id)
                                        }
                                        impactFeedback.impactOccurred()
                                    },
                                    onDelete: {
                                        Task {
                                            _ = await viewModel.deleteNote(note.id)
                                        }
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        impactFeedback.impactOccurred()
                                        Task {
                                            _ = await viewModel.deleteNote(note.id)
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            _ = await viewModel.toggleNoteFavorite(note.id)
                                        }
                                        impactFeedback.impactOccurred()
                                    } label: {
                                        Label(note.isFavorite == true ? "取消收藏" : "收藏", systemImage: note.isFavorite == true ? "star.slash" : "star.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        } header: {
                            timeGroupHeader(group)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // 时间分组头部
    private func timeGroupHeader(_ group: TimeGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.caption)
                .foregroundColor(group.color)

            Text(group.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground).opacity(0.95))
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("还没有学习笔记")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在阅读教材时，选中文字即可保存笔记")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink {
                ReadingView()
            } label: {
                HStack {
                    Image(systemName: "books.vertical")
                    Text("打开教材书库")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.appPrimary)
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 时间流笔记卡片

struct TimelineNoteCard: View {
    let note: ReadingNote
    let isExpanded: Bool
    let onToggle: () -> Void
    let onJumpToTextbook: () -> Void
    let onFocusMode: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showMenu = false

    // 触觉反馈
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    // 使用 note 的实际收藏状态
    private var isFavorite: Bool {
        note.isFavorite ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部（可点击折叠/展开）
            cardHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggle()
                }

            // 展开的内容（不触发折叠）
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(isExpanded ? 0.1 : 0.05), radius: isExpanded ? 8 : 4, y: 2)
        .confirmationDialog("笔记操作", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("专注阅读") {
                onFocusMode()
            }
            if note.textbook != nil {
                Button("跳转教材") {
                    onJumpToTextbook()
                }
            }
            Button(isFavorite ? "取消收藏" : "收藏") {
                onFavorite()
            }
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 卡片头部

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶栏：收藏 + 类型 + 标题 + 更多菜单
            HStack(alignment: .top, spacing: 8) {
                // 收藏标记
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // 类型标签
                HStack(spacing: 4) {
                    Image(systemName: note.typeIcon)
                        .font(.caption2)
                    Text(note.typeLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(note.typeColor)
                .cornerRadius(8)

                // 标题
                Text(note.query ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 1)

                Spacer()

                // 更多菜单按钮
                Button {
                    showMenu = true
                    impactFeedback.impactOccurred()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // 内容预览（折叠时显示）
            if !isExpanded {
                notePreviewContent
            }

            // 底栏：来源教材 + 页码 + 时间
            HStack {
                if let textbook = note.textbook {
                    HStack(spacing: 4) {
                        Text(textbook.subjectIcon)
                            .font(.caption)
                        Text(textbook.displayTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let page = note.page {
                    Text("· P\(page)")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }

                Spacer()

                // 时间
                Text(note.relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // 展开指示器
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - 折叠时的预览内容

    @ViewBuilder
    private var notePreviewContent: some View {
        let previewText = extractPreviewText()
        if !previewText.isEmpty {
            Text(previewText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    /// 提取预览文本（从各种类型的内容中）
    private func extractPreviewText() -> String {
        // 优先使用 snippet
        if let snippet = note.snippet, !snippet.isEmpty {
            return snippet
        }

        // 尝试解析 content
        if let content = note.contentString, !content.isEmpty {
            return parseContentForPreview(content)
        }

        return ""
    }

    /// 解析内容用于预览
    private func parseContentForPreview(_ content: String) -> String {
        // 尝试解析为 JSON
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 不是 JSON，直接返回（限制长度）
            return String(content.prefix(100))
        }

        // 根据 JSON 结构提取文本
        // 练习题：stem 字段
        if let stem = json["stem"] as? String {
            return stem
        }
        if let question = json["question"] as? [String: Any],
           let stem = question["stem"] as? String {
            return stem
        }

        // 解题记录：answer 字段
        if let answer = json["answer"] as? String {
            return String(answer.prefix(100))
        }

        // 摘录/高亮：text 字段
        if let text = json["text"] as? String {
            return text
        }

        // 手写批注：显示提示
        if json["drawingData"] != nil {
            return "手写批注内容"
        }

        return ""
    }

    // MARK: - 展开内容（根据类型渲染）

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal)

            // 根据笔记类型显示不同内容
            switch note.sourceType {
            case "dict":
                dictExpandedContent
            case "practice", "exercise":
                practiceExpandedContent
            case "solving":
                solvingExpandedContent
            case "highlight", "pdf_selection":
                highlightExpandedContent
            case "user_note":
                userNoteExpandedContent
            case "ai_analysis", "explain", "ai_quote":
                aiExpandedContent
            default:
                defaultExpandedContent
            }
        }
        .padding(.bottom)
    }

    // MARK: - 查字典内容

    private var dictExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 查询的字/词
            if let query = note.query, !query.isEmpty {
                HStack(spacing: 12) {
                    Text(query)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 72, height: 72)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("查字结果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let page = note.page {
                            Text("第 \(page) 页")
                                .font(.caption)
                                .foregroundColor(.appPrimary)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // 字典内容
            if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - 练习题内容（可交互HTML渲染）

    private var practiceExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let content = note.contentString, !content.isEmpty {
                // 使用WebView渲染可交互的练习题
                InteractivePracticeView(jsonContent: content)
                    .frame(minHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - 解题内容（解析 JSON 中的 answer）

    private var solvingExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let content = note.contentString, !content.isEmpty {
                let answerText = parseSolvingContent(content)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.cyan)
                        Text("解答")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(answerText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cyan.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 摘录/高亮内容

    private var highlightExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let content = note.contentString, !content.isEmpty {
                let highlightText = parseHighlightContent(content)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "highlighter")
                            .foregroundColor(.yellow)
                        Text("摘录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(highlightText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 4)
                        .cornerRadius(2),
                    alignment: .leading
                )
                .padding(.horizontal)
            } else if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - 用户笔记内容（手写或文本）

    private var userNoteExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let content = note.contentString, !content.isEmpty {
                let parsed = parseUserNoteContent(content)

                if parsed.isDrawing {
                    // 手写批注
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pencil.tip")
                                .foregroundColor(.orange)
                            Text("手写批注")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("包含手写内容，请在专注模式查看")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    // 文本笔记
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.orange)
                            Text("我的笔记")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(parsed.text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - AI 分析内容

    private var aiExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let content = note.contentString, !content.isEmpty {
                let aiText = parseAIContent(content)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                        Text("AI 分析")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(aiText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 默认展开内容

    private var defaultExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .textSelection(.enabled)
            }

            if let content = note.contentString, !content.isEmpty {
                let displayText = parseGenericContent(content)
                if displayText != note.snippet && !displayText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("详细内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Text(displayText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - 内容解析方法

    /// 解析练习题 JSON
    private func parsePracticeQuestion(_ content: String) -> NotePracticeQuestion {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NotePracticeQuestion(stem: content, options: [], answer: "", type: "text")
        }

        // 直接是 question 对象
        if let stem = json["stem"] as? String {
            return parseQuestionJSON(json)
        }
        // 嵌套在 question 字段中
        if let questionDict = json["question"] as? [String: Any] {
            return parseQuestionJSON(questionDict)
        }

        return NotePracticeQuestion(stem: content, options: [], answer: "", type: "text")
    }

    private func parseQuestionJSON(_ json: [String: Any]) -> NotePracticeQuestion {
        let stem = json["stem"] as? String ?? ""
        let answer = json["answer"] as? String ?? ""
        let type = json["type"] as? String ?? "choice"

        var options: [NotePracticeOption] = []
        if let optionsArray = json["options"] as? [[String: Any]] {
            for opt in optionsArray {
                let value = opt["value"] as? String ?? ""
                let text = opt["text"] as? String ?? ""
                options.append(NotePracticeOption(value: value, text: text))
            }
        }

        return NotePracticeQuestion(stem: stem, options: options, answer: answer, type: type)
    }

    /// 解析解题记录内容（提取 answer 字段）
    private func parseSolvingContent(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return content
        }

        // 提取 answer 字段
        if let answer = json["answer"] as? String {
            return answer
        }

        // 如果没有 answer，尝试其他字段
        if let text = json["text"] as? String {
            return text
        }

        return content
    }

    /// 解析摘录/高亮内容（提取 text 字段）
    private func parseHighlightContent(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return content
        }

        if let text = json["text"] as? String {
            return text
        }

        return content
    }

    /// 解析用户笔记内容
    private func parseUserNoteContent(_ content: String) -> (text: String, isDrawing: Bool) {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (content, false)
        }

        // 检查是否是手写批注
        if json["drawingData"] != nil {
            return ("手写内容", true)
        }

        // 提取文本
        if let text = json["text"] as? String {
            return (text, false)
        }

        return (content, false)
    }

    /// 解析 AI 内容
    private func parseAIContent(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return content
        }

        // 尝试各种可能的字段
        if let answer = json["answer"] as? String {
            return answer
        }
        if let text = json["text"] as? String {
            return text
        }
        if let response = json["response"] as? String {
            return response
        }
        if let content = json["content"] as? String {
            return content
        }

        return content
    }

    /// 解析通用内容
    private func parseGenericContent(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return content
        }

        // 按优先级尝试各种字段
        if let text = json["text"] as? String {
            return text
        }
        if let answer = json["answer"] as? String {
            return answer
        }
        if let content = json["content"] as? String {
            return content
        }

        // 如果是手写数据，返回提示
        if json["drawingData"] != nil {
            return "手写批注内容"
        }

        return content
    }
}

// MARK: - 笔记卡片练习题数据结构

struct NotePracticeQuestion {
    let stem: String
    let options: [NotePracticeOption]
    let answer: String
    let type: String
}

struct NotePracticeOption {
    let value: String
    let text: String
}

// MARK: - ReadingNote 扩展

extension ReadingNote {
    /// 解析 createdAt 为 Date
    var parsedCreatedAt: Date? {
        guard let createdAt = createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            return date
        }
        // 尝试不带毫秒
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }

    /// 相对时间字符串
    var relativeTimeString: String {
        guard let date = parsedCreatedAt else { return "" }

        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            if day == 1 {
                return "昨天"
            } else if day < 7 {
                return "\(day)天前"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                return formatter.string(from: date)
            }
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        AllNotesView()
    }
}

// MARK: - 练习题 HTML 渲染视图

import WebKit

struct PracticeHTMLView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = wrapHTMLWithStyle(htmlContent)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    // 包装 HTML 添加样式
    private func wrapHTMLWithStyle(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 15px;
                    line-height: 1.6;
                    color: #1a1a1a;
                    background: transparent;
                    margin: 0;
                    padding: 12px;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e5e5e5;
                        background: transparent;
                    }
                    .question-card {
                        background: #2c2c2e !important;
                        border-color: #3a3a3c !important;
                    }
                    input, textarea {
                        background: #1c1c1e !important;
                        color: #e5e5e5 !important;
                        border-color: #3a3a3c !important;
                    }
                    .answer-box {
                        background: #1c1c1e !important;
                    }
                }

                /* 题目样式 */
                .question-card {
                    background: #f8f9fa;
                    border: 1px solid #e9ecef;
                    border-radius: 12px;
                    padding: 16px;
                    margin-bottom: 12px;
                }
                .question-title {
                    font-weight: 600;
                    margin-bottom: 12px;
                    color: #495057;
                }
                .question-content {
                    margin-bottom: 16px;
                }

                /* 选项样式 */
                .options {
                    display: flex;
                    flex-direction: column;
                    gap: 8px;
                }
                .option {
                    display: flex;
                    align-items: center;
                    padding: 12px 16px;
                    background: white;
                    border: 2px solid #dee2e6;
                    border-radius: 8px;
                    cursor: pointer;
                    transition: all 0.2s;
                }
                .option:hover {
                    border-color: #7c3aed;
                    background: #f5f3ff;
                }
                .option.selected {
                    border-color: #7c3aed;
                    background: #ede9fe;
                }
                .option.correct {
                    border-color: #10b981;
                    background: #d1fae5;
                }
                .option.wrong {
                    border-color: #ef4444;
                    background: #fee2e2;
                }
                .option-label {
                    font-weight: 600;
                    margin-right: 12px;
                    color: #6366f1;
                    min-width: 24px;
                }

                /* 填空题样式 */
                .blank-input {
                    display: inline-block;
                    min-width: 80px;
                    padding: 4px 12px;
                    border: none;
                    border-bottom: 2px solid #7c3aed;
                    background: transparent;
                    font-size: 15px;
                    text-align: center;
                    outline: none;
                }
                .blank-input:focus {
                    border-bottom-color: #5b21b6;
                }

                /* 答案区域 */
                .answer-box {
                    background: #f0fdf4;
                    border-left: 4px solid #10b981;
                    padding: 12px 16px;
                    margin-top: 12px;
                    border-radius: 0 8px 8px 0;
                }
                .answer-label {
                    font-weight: 600;
                    color: #10b981;
                    margin-bottom: 4px;
                }

                /* 解析区域 */
                .explanation-box {
                    background: #eff6ff;
                    border-left: 4px solid #3b82f6;
                    padding: 12px 16px;
                    margin-top: 12px;
                    border-radius: 0 8px 8px 0;
                }
                .explanation-label {
                    font-weight: 600;
                    color: #3b82f6;
                    margin-bottom: 4px;
                }

                /* 按钮 */
                .btn {
                    display: inline-block;
                    padding: 10px 20px;
                    border: none;
                    border-radius: 8px;
                    font-size: 14px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.2s;
                }
                .btn-primary {
                    background: #7c3aed;
                    color: white;
                }
                .btn-primary:hover {
                    background: #6d28d9;
                }
                .btn-secondary {
                    background: #e5e7eb;
                    color: #374151;
                }

                /* 数学公式 */
                .math {
                    font-family: "Times New Roman", serif;
                    font-style: italic;
                }

                /* 隐藏/显示答案 */
                .hidden {
                    display: none;
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
}

// MARK: - 可交互练习题视图（WebView）

struct InteractivePracticeView: UIViewRepresentable {
    let jsonContent: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateInteractiveHTML(from: jsonContent)
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// 从JSON生成可交互的HTML
    private func generateInteractiveHTML(from json: String) -> String {
        // 解析JSON
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 如果已经是HTML，直接使用
            if json.contains("<") && json.contains(">") {
                return wrapWithInteractiveStyle(json)
            }
            return wrapWithInteractiveStyle("<p>\(json)</p>")
        }

        // 提取题目数据
        var questionData: [String: Any] = [:]
        if let question = parsed["question"] as? [String: Any] {
            questionData = question
        } else if parsed["stem"] != nil {
            questionData = parsed
        } else {
            return wrapWithInteractiveStyle("<p>\(json)</p>")
        }

        let stem = questionData["stem"] as? String ?? ""
        let answer = questionData["answer"] as? String ?? ""
        let type = questionData["type"] as? String ?? "choice"
        let explanation = questionData["explanation"] as? String ?? ""
        let options = questionData["options"] as? [[String: Any]] ?? []

        // 生成HTML
        var html = "<div class=\"question-card\">"

        // 题目
        html += "<div class=\"question-stem\">\(stem)</div>"

        // 根据类型生成不同内容
        if type == "choice" && !options.isEmpty {
            html += "<div class=\"options\" id=\"options\">"
            for opt in options {
                let value = opt["value"] as? String ?? ""
                let text = opt["text"] as? String ?? ""
                html += """
                <div class="option" data-value="\(value)" onclick="selectOption(this, '\(value)')">
                    <span class="option-label">\(value)</span>
                    <span class="option-text">\(text)</span>
                </div>
                """
            }
            html += "</div>"
        } else if type == "fill" || type == "blank" {
            // 填空题
            html += """
            <div class="fill-area">
                <input type="text" class="blank-input" id="fillAnswer" placeholder="请输入答案">
            </div>
            """
        }

        // 操作按钮
        html += """
        <div class="actions">
            <button class="btn btn-primary" onclick="checkAnswer('\(answer)')">检查答案</button>
            <button class="btn btn-secondary" onclick="toggleExplanation()">显示解析</button>
            <button class="btn btn-secondary" onclick="resetQuestion()">重做</button>
        </div>
        """

        // 结果显示区
        html += "<div id=\"result\" class=\"result-box hidden\"></div>"

        // 答案区（默认隐藏）
        html += """
        <div id="answerBox" class="answer-box hidden">
            <div class="answer-label">正确答案</div>
            <div class="answer-content">\(answer)</div>
        </div>
        """

        // 解析区（默认隐藏）
        if !explanation.isEmpty {
            html += """
            <div id="explanationBox" class="explanation-box hidden">
                <div class="explanation-label">解析</div>
                <div class="explanation-content">\(explanation)</div>
            </div>
            """
        }

        html += "</div>"

        return wrapWithInteractiveStyle(html)
    }

    /// 包装HTML添加交互样式和脚本
    private func wrapWithInteractiveStyle(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #1a1a1a;
                    background: #f8f9fa;
                    margin: 0;
                    padding: 16px;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e5e5e5; background: #1c1c1e; }
                    .question-card { background: #2c2c2e !important; }
                    .option { background: #3a3a3c !important; border-color: #4a4a4c !important; }
                    .option:hover { background: #4a4a4c !important; }
                    .blank-input { color: #e5e5e5 !important; background: #2c2c2e !important; }
                    .answer-box { background: #1a2e1a !important; }
                    .explanation-box { background: #1a1a2e !important; }
                }
                .question-card {
                    background: white;
                    border-radius: 16px;
                    padding: 20px;
                }
                .question-stem {
                    font-size: 17px;
                    font-weight: 500;
                    margin-bottom: 20px;
                    line-height: 1.7;
                }
                .options { display: flex; flex-direction: column; gap: 12px; margin-bottom: 20px; }
                .option {
                    display: flex;
                    align-items: center;
                    padding: 14px 18px;
                    background: #f8f9fa;
                    border: 2px solid #e0e0e0;
                    border-radius: 12px;
                    cursor: pointer;
                    transition: all 0.2s;
                }
                .option:hover { border-color: #7c3aed; background: #f5f3ff; }
                .option.selected { border-color: #7c3aed; background: #ede9fe; }
                .option.correct { border-color: #10b981 !important; background: #d1fae5 !important; }
                .option.wrong { border-color: #ef4444 !important; background: #fee2e2 !important; }
                .option-label {
                    font-weight: 700;
                    margin-right: 14px;
                    color: #7c3aed;
                    min-width: 28px;
                    font-size: 17px;
                }
                .option-text { flex: 1; }
                .fill-area { margin-bottom: 20px; }
                .blank-input {
                    width: 100%;
                    padding: 14px 18px;
                    border: 2px solid #e0e0e0;
                    border-radius: 12px;
                    font-size: 16px;
                    outline: none;
                    transition: border-color 0.2s;
                }
                .blank-input:focus { border-color: #7c3aed; }
                .blank-input.correct { border-color: #10b981; background: #d1fae5; }
                .blank-input.wrong { border-color: #ef4444; background: #fee2e2; }
                .actions {
                    display: flex;
                    gap: 10px;
                    flex-wrap: wrap;
                    margin-bottom: 16px;
                }
                .btn {
                    padding: 12px 20px;
                    border: none;
                    border-radius: 10px;
                    font-size: 15px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.2s;
                }
                .btn-primary { background: #7c3aed; color: white; }
                .btn-primary:hover { background: #6d28d9; }
                .btn-secondary { background: #e5e7eb; color: #374151; }
                .btn-secondary:hover { background: #d1d5db; }
                .result-box {
                    padding: 14px 18px;
                    border-radius: 12px;
                    margin-bottom: 12px;
                    font-weight: 600;
                }
                .result-box.correct { background: #d1fae5; color: #065f46; }
                .result-box.wrong { background: #fee2e2; color: #991b1b; }
                .answer-box {
                    background: #f0fdf4;
                    border-left: 4px solid #10b981;
                    padding: 14px 18px;
                    margin-bottom: 12px;
                    border-radius: 0 12px 12px 0;
                }
                .answer-label { font-weight: 700; color: #10b981; margin-bottom: 6px; }
                .explanation-box {
                    background: #eff6ff;
                    border-left: 4px solid #3b82f6;
                    padding: 14px 18px;
                    border-radius: 0 12px 12px 0;
                }
                .explanation-label { font-weight: 700; color: #3b82f6; margin-bottom: 6px; }
                .hidden { display: none; }
            </style>
        </head>
        <body>
            \(content)
            <script>
                var selectedOption = null;
                var isChecked = false;
                var correctAnswer = '';

                function selectOption(el, value) {
                    if (isChecked) return; // 已检查后不能再选
                    // 清除之前选择
                    document.querySelectorAll('.option').forEach(opt => opt.classList.remove('selected'));
                    // 选中当前
                    el.classList.add('selected');
                    selectedOption = value;
                }

                function checkAnswer(answer) {
                    correctAnswer = answer;
                    var resultBox = document.getElementById('result');
                    var answerBox = document.getElementById('answerBox');

                    // 填空题
                    var fillInput = document.getElementById('fillAnswer');
                    if (fillInput) {
                        var userAnswer = fillInput.value.trim();
                        if (!userAnswer) {
                            resultBox.className = 'result-box wrong';
                            resultBox.textContent = '请先输入答案';
                            resultBox.classList.remove('hidden');
                            return;
                        }
                        isChecked = true;
                        if (userAnswer === answer || userAnswer.toLowerCase() === answer.toLowerCase()) {
                            fillInput.classList.add('correct');
                            resultBox.className = 'result-box correct';
                            resultBox.textContent = '✓ 回答正确！';
                        } else {
                            fillInput.classList.add('wrong');
                            resultBox.className = 'result-box wrong';
                            resultBox.textContent = '✗ 回答错误';
                            answerBox.classList.remove('hidden');
                        }
                        resultBox.classList.remove('hidden');
                        return;
                    }

                    // 选择题
                    if (!selectedOption) {
                        resultBox.className = 'result-box wrong';
                        resultBox.textContent = '请先选择一个答案';
                        resultBox.classList.remove('hidden');
                        return;
                    }

                    isChecked = true;
                    document.querySelectorAll('.option').forEach(opt => {
                        var val = opt.getAttribute('data-value');
                        if (val === answer) {
                            opt.classList.add('correct');
                        } else if (val === selectedOption && val !== answer) {
                            opt.classList.add('wrong');
                        }
                    });

                    if (selectedOption === answer) {
                        resultBox.className = 'result-box correct';
                        resultBox.textContent = '✓ 回答正确！';
                    } else {
                        resultBox.className = 'result-box wrong';
                        resultBox.textContent = '✗ 回答错误';
                        answerBox.classList.remove('hidden');
                    }
                    resultBox.classList.remove('hidden');
                }

                function toggleExplanation() {
                    var box = document.getElementById('explanationBox');
                    var answerBox = document.getElementById('answerBox');
                    if (box) box.classList.toggle('hidden');
                    if (answerBox) answerBox.classList.remove('hidden');
                }

                function resetQuestion() {
                    selectedOption = null;
                    isChecked = false;
                    document.querySelectorAll('.option').forEach(opt => {
                        opt.classList.remove('selected', 'correct', 'wrong');
                    });
                    var fillInput = document.getElementById('fillAnswer');
                    if (fillInput) {
                        fillInput.value = '';
                        fillInput.classList.remove('correct', 'wrong');
                    }
                    document.getElementById('result').classList.add('hidden');
                    document.getElementById('answerBox').classList.add('hidden');
                    var explBox = document.getElementById('explanationBox');
                    if (explBox) explBox.classList.add('hidden');
                }
            </script>
        </body>
        </html>
        """
    }
}

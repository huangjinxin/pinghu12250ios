//
//  DiaryListView.swift
//  pinghu12250
//
//  日记列表 - 记录每一天的成长
//

import SwiftUI
import Combine
import UIKit

struct DiaryListView: View {
    @StateObject private var diaryService = DiaryService.shared
    @StateObject private var draftManager = DiaryDraftManager.shared
    @StateObject private var aiService = DiaryAIService.shared
    @State private var showCreateSheet = false
    @State private var showDraftsSheet = false
    @State private var selectedMood: String? = nil
    @State private var editingDiary: DiaryData? = nil
    @State private var editingDraft: DiaryDraft? = nil  // 编辑草稿
    @State private var viewingDiary: DiaryData? = nil  // 用于查看详情
    @State private var searchText = ""
    @State private var showAIAnalysisSheet = false  // AI 分析结果弹窗
    @State private var analyzingDiary: DiaryData? = nil  // 当前分析的日记
    @State private var hasLoadedDiaries = false  // 跟踪是否已加载日记
    @State private var showThisWeekAnalyzeAlert = false  // 分析本周确认弹窗
    @State private var showLastWeekAnalyzeAlert = false  // 分析上周确认弹窗

    // Tab 切换
    @State private var selectedTab = 0  // 0: 我的日记, 1: AI分析记录, 2: 成就

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab 切换栏
                tabBar

                // Tab 内容
                TabView(selection: $selectedTab) {
                    // 我的日记 Tab
                    diaryContent
                        .tag(0)

                    // AI 分析记录 Tab
                    DiaryAIHistoryTabView(aiService: aiService)
                        .tag(1)

                    // 成就 Tab
                    DiaryAchievementsTabView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的日记")
            .toolbar {
                // 草稿箱按钮
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDraftsSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "folder")
                            if !draftManager.drafts.isEmpty {
                                Text("\(draftManager.drafts.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }

                // 写日记按钮
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingDiary = nil
                        editingDraft = nil
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                DiaryEditorSheet(
                    diary: editingDiary,
                    draft: editingDraft,
                    onSave: {
                        Task { await diaryService.loadDiaries(refresh: true, mood: selectedMood) }
                    },
                    onDraftDeleted: { draftId in
                        draftManager.deleteDraft(id: draftId)
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showDraftsSheet) {
                DiaryDraftsSheet(onSelectDraft: { draft in
                    showDraftsSheet = false
                    editingDiary = nil
                    editingDraft = draft
                    showCreateSheet = true
                })
            }
            .sheet(item: $viewingDiary) { diary in
                DiaryDetailSheet(diary: diary, onEdit: {
                    viewingDiary = nil
                    editingDraft = nil
                    editingDiary = diary
                    showCreateSheet = true
                }, onAnalyze: {
                    viewingDiary = nil
                    // 立即显示分析弹窗
                    showAIAnalysisSheet = true
                    Task {
                        await aiService.analyzeDiary(diary)
                    }
                })
            }
            .sheet(isPresented: $showAIAnalysisSheet) {
                DiaryAIAnalysisSheet(aiService: aiService, onComplete: {
                    // 分析完成后不需要手动刷新，Tab视图会自动处理
                })
            }
            .alert("提示", isPresented: .constant(diaryService.errorMessage != nil)) {
                Button("确定") { diaryService.errorMessage = nil }
            } message: {
                Text(diaryService.errorMessage ?? "")
            }
            .alert("AI 分析", isPresented: .constant(aiService.errorMessage != nil && !showAIAnalysisSheet)) {
                Button("确定") { aiService.errorMessage = nil }
            } message: {
                Text(aiService.errorMessage ?? "")
            }
            .alert("分析本周日记", isPresented: $showThisWeekAnalyzeAlert) {
                Button("取消", role: .cancel) { }
                Button("开始分析") {
                    Task {
                        await analyzeBatch(period: "this_week")
                    }
                }
            } message: {
                Text("预计需要至少2分钟进行分析，期间请不要退出页面。确定要开始吗？")
            }
            .alert("分析上周日记", isPresented: $showLastWeekAnalyzeAlert) {
                Button("取消", role: .cancel) { }
                Button("开始分析") {
                    Task {
                        await analyzeBatch(period: "last_week")
                    }
                }
            } message: {
                Text("预计需要至少2分钟进行分析，期间请不要退出页面。确定要开始吗？")
            }
        }
        .task {
            // 只在首次加载
            if !hasLoadedDiaries {
                hasLoadedDiaries = true
                await diaryService.loadDiaries(refresh: true, mood: selectedMood)
            }
        }
    }

    // MARK: - Tab 切换栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "我的日记", isSelected: selectedTab == 0) {
                withAnimation { selectedTab = 0 }
            }
            TabButton(title: "AI分析记录", isSelected: selectedTab == 1) {
                withAnimation { selectedTab = 1 }
            }
            TabButton(title: "成就", isSelected: selectedTab == 2) {
                withAnimation { selectedTab = 2 }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 日记内容

    private var diaryContent: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            // 筛选栏
            filterBar

            // 分页信息栏
            if !diaryService.diaries.isEmpty {
                paginationBar
            }

            // 日记列表
            if diaryService.isLoading && diaryService.diaries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredDiaries.isEmpty {
                emptyView
            } else {
                diaryList
            }
        }
        .refreshable {
            await diaryService.loadDiaries(refresh: true, mood: selectedMood)
        }
    }

    // 根据搜索文本过滤日记
    private var filteredDiaries: [DiaryData] {
        if searchText.isEmpty {
            return diaryService.diaries
        }
        return diaryService.diaries.filter { diary in
            diary.title.localizedCaseInsensitiveContains(searchText) ||
            diary.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索日记标题或内容...", text: $searchText)
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
        .padding(.top, 8)
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        VStack(spacing: 8) {
            // 心情筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    MoodFilterChip(mood: nil, label: "全部", selected: selectedMood == nil) {
                        selectedMood = nil
                        Task { await diaryService.loadDiaries(refresh: true, mood: nil) }
                    }

                    ForEach(DiaryData.moodOptions, id: \.value) { mood in
                        MoodFilterChip(mood: mood.value, label: mood.emoji, selected: selectedMood == mood.value) {
                            selectedMood = mood.value
                            Task { await diaryService.loadDiaries(refresh: true, mood: mood.value) }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // AI 分析按钮栏
            HStack(spacing: 12) {
                Spacer()

                Button {
                    showThisWeekAnalyzeAlert = true
                } label: {
                    if aiService.analyzingType == .thisWeek {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("分析本周", systemImage: "sparkles")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(aiService.isAnalyzing)

                Button {
                    showLastWeekAnalyzeAlert = true
                } label: {
                    if aiService.analyzingType == .lastWeek {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("分析上周", systemImage: "sparkles")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(aiService.isAnalyzing)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 批量分析

    private func analyzeBatch(period: String) async {
        // 获取本周/上周的日记
        let calendar = Calendar.current
        let now = Date()
        var start: Date
        var end: Date

        if period == "this_week" {
            // 本周：从周一到周日
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = (weekday + 5) % 7  // 将周日(1)转换为偏移6，周一(2)转换为偏移0
            start = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            end = calendar.date(byAdding: .day, value: 6, to: start)!
        } else {
            // 上周
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = (weekday + 5) % 7
            let thisWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            start = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)!
            end = calendar.date(byAdding: .day, value: 6, to: start)!
        }

        // 筛选日期范围内的日记
        let targetDiaries = diaryService.diaries.filter { diary in
            guard let createdDate = diary.createdDate else { return false }
            return createdDate >= start && createdDate <= end
        }

        // 先检查是否有日记，没有则显示错误（不展示弹窗）
        if targetDiaries.isEmpty {
            aiService.errorMessage = period == "this_week" ? "本周还没有日记" : "上周没有日记"
            return
        }

        // 有日记才显示分析弹窗，然后开始分析
        showAIAnalysisSheet = true
        await aiService.analyzeBatch(period: period, diaries: targetDiaries)
    }

    // MARK: - 分页信息栏

    private var paginationBar: some View {
        HStack {
            // 总数统计
            Text("共 \(filteredDiaries.count) 篇日记")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // 翻页控制
            HStack(spacing: 16) {
                Button {
                    // 刷新第一页
                    Task { await diaryService.loadDiaries(refresh: true, mood: selectedMood) }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }

                if diaryService.hasMore {
                    Button {
                        Task { await diaryService.loadDiaries(mood: selectedMood) }
                    } label: {
                        HStack(spacing: 4) {
                            Text("加载更多")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.appPrimary)
                    }
                    .disabled(diaryService.isLoading)
                } else {
                    Text("已全部加载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 日记列表

    private var diaryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredDiaries) { diary in
                    DiaryCardView(diary: diary, onEdit: {
                        editingDiary = diary
                        showCreateSheet = true
                    }, onDelete: {
                        Task { await diaryService.deleteDiary(id: diary.id) }
                    }, onAnalyze: {
                        // 立即显示分析弹窗，防止误触
                        showAIAnalysisSheet = true
                        Task {
                            await aiService.analyzeDiary(diary)
                        }
                    }, isAnalyzing: aiService.isAnalyzing)
                    .onTapGesture {
                        viewingDiary = diary
                    }
                    .onAppear {
                        // 自动加载更多：当最后第3个项出现时触发
                        if diary.id == diaryService.diaries.suffix(3).first?.id {
                            Task { await diaryService.loadDiaries(mood: selectedMood) }
                        }
                    }
                }

                // 底部状态
                if diaryService.isLoading && !diaryService.diaries.isEmpty {
                    ProgressView()
                        .padding()
                } else if !diaryService.hasMore && !diaryService.diaries.isEmpty {
                    Text("— 没有更多了 —")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有日记")
                .foregroundColor(.secondary)

            Button("写一篇日记") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab 按钮

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
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
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 筛选按钮

struct MoodFilterChip: View {
    let mood: String?
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 日记卡片

struct DiaryCardView: View {
    let diary: DiaryData
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onAnalyze: (() -> Void)? = nil
    var isAnalyzing: Bool = false

    @State private var showDeleteAlert = false
    @State private var showCopiedToast = false
    @State private var showAnalyzeAlert = false

    // 获取 Web 端地址
    private var webURL: String {
        // 使用生产环境地址
        "https://pinghu.706tech.cn/diary/\(diary.id)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：日期时间和心情
            HStack {
                if let date = diary.createdDate {
                    Text(date.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(diary.moodEmoji)
                Text(diary.weatherEmoji)

                Spacer()

                // 字数等级标签
                Text("\(diary.wordCount)字 · \(diary.wordLevel.text)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(diary.wordLevel.color)
                    .cornerRadius(10)
            }

            // 标题
            Text(diary.title)
                .font(.headline)

            // 内容预览
            Text(diary.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)

            // 操作栏
            HStack {
                Spacer()

                // 操作菜单：合并分享、编辑、删除、智能分析
                Menu {
                    // 智能分析
                    Button {
                        showAnalyzeAlert = true
                    } label: {
                        Label("智能分析", systemImage: "sparkles")
                    }
                    .disabled(isAnalyzing)

                    Divider()

                    // 分享
                    Button {
                        UIPasteboard.general.string = webURL
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                        }
                    } label: {
                        Label("分享链接", systemImage: "square.and.arrow.up")
                    }

                    // 编辑
                    Button {
                        onEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Divider()

                    // 删除
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Label("操作", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(alignment: .center) {
            if showCopiedToast {
                Text("链接已复制")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这篇日记吗？")
        }
        .alert("AI 智能分析", isPresented: $showAnalyzeAlert) {
            Button("取消", role: .cancel) { }
            Button("开始分析") {
                onAnalyze?()
            }
        } message: {
            Text("预计需要至少2分钟进行分析，期间请不要退出页面。确定要开始吗？")
        }
    }
}

// MARK: - 日记编辑器

struct DiaryEditorSheet: View {
    let diary: DiaryData?
    let draft: DiaryDraft?
    let onSave: () -> Void
    let onDraftDeleted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var diaryService = DiaryService.shared
    @StateObject private var draftManager = DiaryDraftManager.shared
    @State private var title = ""
    @State private var content = ""
    @State private var mood = "happy"
    @State private var weather = "sunny"
    @State private var isSaving = false
    @State private var isFullscreen = false
    @State private var showTemplateAlert = false
    @State private var currentDraftId: String?

    var body: some View {
        Group {
            if isFullscreen {
                // 窗口内全屏模式 - 简化 UI，最大化编辑区域
                fullscreenEditor
            } else {
                // 普通模式 - 带导航栏
                NavigationStack {
                    normalEditor
                        .navigationTitle(diary == nil ? "写日记" : "编辑日记")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("返回") {
                                    handleBack()
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Button {
                                    withAnimation {
                                        isFullscreen.toggle()
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                HStack(spacing: 12) {
                                    Button("暂存") {
                                        handleSaveDraft()
                                    }
                                    .disabled(title.isEmpty && content.isEmpty)

                                    Button("提交") {
                                        Task { await saveDiary() }
                                    }
                                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                                    .fontWeight(.bold)
                                }
                            }
                        }
                }
            }
        }
        .alert("使用参考模版", isPresented: $showTemplateAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                content = DiaryTemplate.timelineTemplate
            }
        } message: {
            Text("将会删除当前日记内容，替换成模版内容，确定吗？")
        }
        .onAppear {
            if let diary = diary {
                // 编辑已有日记
                title = diary.title
                content = diary.content
                mood = diary.mood ?? "happy"
                weather = diary.weather ?? "sunny"
                currentDraftId = nil
            } else if let draft = draft {
                // 从草稿继续编辑
                title = draft.title
                content = draft.content
                mood = draft.mood
                weather = draft.weather
                currentDraftId = draft.id
            }
        }
    }

    // MARK: - 普通编辑器

    private var normalEditor: some View {
        Form {
            Section("基本信息") {
                TextField("标题", text: $title)

                Picker("心情", selection: $mood) {
                    ForEach(DiaryData.moodOptions, id: \.value) { option in
                        Text("\(option.emoji) \(option.label)").tag(option.value)
                    }
                }

                Picker("天气", selection: $weather) {
                    ForEach(DiaryData.weatherOptions, id: \.value) { option in
                        Text("\(option.emoji) \(option.label)").tag(option.value)
                    }
                }
            }

            Section {
                HStack {
                    Text("内容")
                    Spacer()
                    Button {
                        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            content = DiaryTemplate.timelineTemplate
                        } else {
                            showTemplateAlert = true
                        }
                    } label: {
                        Label("参考模版", systemImage: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                TextEditor(text: $content)
                    .frame(minHeight: 200)
            }

            // 字数统计
            Section("字数统计") {
                WordCountView(content: content)
            }
        }
    }

    // MARK: - 全屏编辑器

    private var fullscreenEditor: some View {
        VStack(spacing: 0) {
            // 顶部工具栏（窗口内全屏模式）
            HStack {
                // 返回按钮
                Button {
                    handleBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .foregroundColor(.appPrimary)
                }

                Spacer()

                // 退出全屏按钮
                Button {
                    withAnimation {
                        isFullscreen = false
                    }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 暂存和提交按钮
                HStack(spacing: 12) {
                    Button("暂存") {
                        handleSaveDraft()
                    }
                    .disabled(title.isEmpty && content.isEmpty)
                    .foregroundColor(.secondary)

                    Button("提交") {
                        Task { await saveDiary() }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                    .fontWeight(.bold)
                    .foregroundColor(title.isEmpty || content.isEmpty || isSaving ? .gray : .appPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // 信息栏（标题、心情、天气）
            HStack {
                TextField("标题", text: $title)
                    .font(.headline)

                Spacer()

                Menu {
                    ForEach(DiaryData.moodOptions, id: \.value) { option in
                        Button {
                            mood = option.value
                        } label: {
                            Text("\(option.emoji) \(option.label)")
                        }
                    }
                } label: {
                    Text(DiaryData.moodOptions.first { $0.value == mood }?.emoji ?? "😊")
                }

                Menu {
                    ForEach(DiaryData.weatherOptions, id: \.value) { option in
                        Button {
                            weather = option.value
                        } label: {
                            Text("\(option.emoji) \(option.label)")
                        }
                    }
                } label: {
                    Text(DiaryData.weatherOptions.first { $0.value == weather }?.emoji ?? "☀️")
                }

                Button {
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        content = DiaryTemplate.timelineTemplate
                    } else {
                        showTemplateAlert = true
                    }
                } label: {
                    Image(systemName: "doc.text")
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // 内容编辑区
            TextEditor(text: $content)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 底部字数统计
            HStack {
                let stats = contentStats
                Text("文字: \(stats.chars)")
                Text("总字符: \(stats.total)")
                Spacer()
                Text(stats.levelText)
                    .foregroundColor(stats.levelColor)
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 字数统计

    private var contentStats: (total: Int, chars: Int, levelText: String, levelColor: Color) {
        let total = content.count
        let spaces = content.filter { $0.isWhitespace }.count
        let punctuationChars = CharacterSet(charactersIn: #"，。！？；：、""''《》【】（）,.!?;:'"<>(){}[]"#)
        let punctuation = content.unicodeScalars.filter { punctuationChars.contains($0) }.count
        let chars = total - spaces - punctuation

        let (levelText, levelColor): (String, Color) = switch chars {
        case 2000...: ("大师等级", .red)
        case 1500..<2000: ("卓越等级", .orange)
        case 1200..<1500: ("优秀等级", .blue)
        case 1000..<1200: ("良好等级", .green)
        case 800..<1000: ("入门等级", .green)
        default: ("还需\(800-chars)字入门", .gray)
        }

        return (total, chars, levelText, levelColor)
    }

    // MARK: - 操作

    private func handleBack() {
        // 如果有内容则自动保存草稿
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let draft = DiaryDraft(
                id: currentDraftId ?? UUID().uuidString,
                title: title,
                content: content,
                mood: mood,
                weather: weather
            )
            draftManager.saveDraft(draft)
        }
        dismiss()
    }

    private func handleSaveDraft() {
        let draft = DiaryDraft(
            id: currentDraftId ?? UUID().uuidString,
            title: title,
            content: content,
            mood: mood,
            weather: weather
        )
        draftManager.saveDraft(draft)
        currentDraftId = draft.id
    }

    private func saveDiary() async {
        isSaving = true
        var success = false

        if let diary = diary {
            // 更新
            success = await diaryService.updateDiary(
                id: diary.id,
                title: title,
                content: content,
                mood: mood,
                weather: weather
            )
        } else {
            // 创建
            success = await diaryService.createDiary(
                title: title,
                content: content,
                mood: mood,
                weather: weather
            )
        }

        isSaving = false
        if success {
            // 提交成功后删除对应草稿
            if let draftId = currentDraftId {
                onDraftDeleted(draftId)
            }
            onSave()
            dismiss()
        }
    }
}

// MARK: - 草稿箱视图

struct DiaryDraftsSheet: View {
    let onSelectDraft: (DiaryDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var draftManager = DiaryDraftManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if draftManager.drafts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无草稿")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(draftManager.drafts) { draft in
                            Button {
                                onSelectDraft(draft)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(draft.title.isEmpty ? "无标题" : draft.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(draft.content.prefix(100) + (draft.content.count > 100 ? "..." : ""))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)

                                    HStack {
                                        Text(draft.savedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text("·")
                                            .foregroundColor(.secondary)

                                        Text("\(draft.wordCount)字")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                draftManager.deleteDraft(id: draftManager.drafts[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("草稿箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if !draftManager.drafts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("清空", role: .destructive) {
                            draftManager.clearAllDrafts()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 字数统计视图

struct WordCountView: View {
    let content: String

    private var stats: (total: Int, chars: Int, punctuation: Int, spaces: Int) {
        let total = content.count
        let spaces = content.filter { $0.isWhitespace }.count
        let punctuationChars = CharacterSet(charactersIn: #"，。！？；：、""''《》【】（）,.!?;:'"<>(){}[]"#)
        let punctuation = content.unicodeScalars.filter { punctuationChars.contains($0) }.count
        let chars = total - spaces - punctuation
        return (total, chars, punctuation, spaces)
    }

    private var level: (level: Int, text: String, progress: Double, color: Color) {
        let chars = stats.chars
        switch chars {
        case 2000...: return (5, "大师等级", 1.0, .red)
        case 1500..<2000: return (4, "卓越等级，还需\(2000-chars)字达到大师", Double(chars-1500)/500, .orange)
        case 1200..<1500: return (3, "优秀等级，还需\(1500-chars)字达到卓越", Double(chars-1200)/300, .blue)
        case 1000..<1200: return (2, "良好等级，还需\(1200-chars)字达到良好", Double(chars-1000)/200, .green)
        case 800..<1000: return (1, "入门等级，还需\(1000-chars)字达到良好", Double(chars-800)/200, .green)
        default: return (0, "还需\(800-chars)字达到入门", Double(chars)/800, .gray)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 统计数据
            HStack(spacing: 20) {
                DiaryStatItem(label: "总字符", value: "\(stats.total)")
                DiaryStatItem(label: "文字", value: "\(stats.chars)", color: .appPrimary)
                DiaryStatItem(label: "标点", value: "\(stats.punctuation)")
                DiaryStatItem(label: "空格", value: "\(stats.spaces)")
            }

            // 等级进度
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(["入门", "良好", "优秀", "卓越", "大师"], id: \.self) { name in
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(levelColor(for: name))
                    }
                }

                ProgressView(value: level.progress)
                    .tint(level.color)

                Text(level.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func levelColor(for name: String) -> Color {
        let index = ["入门", "良好", "优秀", "卓越", "大师"].firstIndex(of: name) ?? 0
        return level.level > index ? .appPrimary : .gray
    }
}

struct DiaryStatItem: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - 日记详情弹窗

struct DiaryDetailSheet: View {
    let diary: DiaryData
    let onEdit: () -> Void
    var onAnalyze: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showAnalyzeAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题和情绪
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(diary.moodEmoji)
                                .font(.largeTitle)
                            Text(diary.weatherEmoji)
                                .font(.largeTitle)
                            Spacer()
                        }

                        Text(diary.title)
                            .font(.title)
                            .fontWeight(.bold)

                        if let date = diary.createdDate {
                            Text(date.formatted(date: .complete, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 朗读播放器
                    SpeechPlayerView(text: diary.content, title: diary.title)

                    Divider()

                    // 正文内容（可选择朗读）
                    SelectableText(
                        text: diary.content,
                        font: .preferredFont(forTextStyle: .body),
                        textColor: .label
                    )

                    Divider()

                    // 字数统计
                    VStack(alignment: .leading, spacing: 12) {
                        Text("写作统计")
                            .font(.headline)

                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("\(diary.wordCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appPrimary)
                                Text("字数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(spacing: 4) {
                                Text(diary.wordLevel.text)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(diary.wordLevel.color)
                                Text("等级")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("日记详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAnalyzeAlert = true
                        } label: {
                            Label("智能分析", systemImage: "sparkles")
                        }

                        Divider()

                        Button {
                            dismiss()
                            onEdit()
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("AI 智能分析", isPresented: $showAnalyzeAlert) {
                Button("取消", role: .cancel) { }
                Button("开始分析") {
                    dismiss()
                    onAnalyze?()
                }
            } message: {
                Text("预计需要至少2分钟进行分析，期间请不要退出页面。确定要开始吗？")
            }
        }
    }
}

// MARK: - AI 分析结果弹窗

struct DiaryAIAnalysisSheet: View {
    @ObservedObject var aiService: DiaryAIService
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginalDiary = false

    var body: some View {
        NavigationStack {
            Group {
                if aiService.isAnalyzing {
                    // 加载中状态 - 全屏遮罩防止误触
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(aiService.loadingText)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text("请稍候，AI正在分析中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if let result = aiService.currentAnalysisResult {
                    // 分析结果
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 顶部信息栏
                            analysisHeaderView(result: result)

                            // 朗读播放器
                            SpeechPlayerView(text: result.analysis, title: "AI分析")

                            // AI 分析结果（主角）
                            SelectableMarkdownView(content: result.analysis, fontSize: 16, lineSpacing: 10, theme: .warm)

                            // 元数据
                            if let responseTime = result.responseTime {
                                HStack {
                                    if let modelName = result.modelName {
                                        Label(modelName, systemImage: "cpu")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Label("\(String(format: "%.1f", Double(responseTime) / 1000.0))秒", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 4)
                            }

                            // 原日记（折叠，放在最后）
                            if !result.isBatch, let diary = result.diary {
                                originalDiarySection(diary: diary)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onAppear {
                        onComplete?()
                    }
                } else {
                    // 无结果
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无分析结果")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(aiService.isAnalyzing)  // 分析中禁止关闭
                }
            }
            .interactiveDismissDisabled(aiService.isAnalyzing)  // 分析中禁止下滑关闭
        }
    }

    private func getTitle() -> String {
        if aiService.isAnalyzing {
            return "AI 分析中..."
        }
        if let result = aiService.currentAnalysisResult {
            if result.isBatch {
                return "\(result.period ?? "")日记分析"
            }
            return "AI 日记分析"
        }
        return "AI 分析"
    }

    // MARK: - 顶部信息栏

    private func analysisHeaderView(result: DiaryAIService.AnalysisResult) -> some View {
        HStack(spacing: 12) {
            // 类型标签
            HStack(spacing: 6) {
                Image(systemName: result.isBatch ? "doc.on.doc.fill" : "sparkles")
                    .font(.caption)
                Text(result.isBatch ? "批量分析" : "智能分析")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.purple.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)

            if result.isBatch {
                Text("\(result.period ?? "") · \(result.diaryCount)篇")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - 原日记折叠区

    private func originalDiarySection(diary: DiaryData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠按钮
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showOriginalDiary.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showOriginalDiary ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    Image(systemName: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("查看原日记")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(diary.moodEmoji)
                    Text(diary.weatherEmoji)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // 折叠内容
            if showOriginalDiary {
                VStack(alignment: .leading, spacing: 12) {
                    // 标题和日期
                    HStack {
                        Text(diary.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        if let date = diary.createdDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 日记正文（可选择）
                    SelectableText(
                        text: diary.content,
                        font: .preferredFont(forTextStyle: .body),
                        textColor: .label
                    )
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - AI 分析历史 Tab 视图（内嵌版本）

struct DiaryAIHistoryTabView: View {
    @ObservedObject var aiService: DiaryAIService  // 使用传入的service避免创建多个观察者
    @State private var selectedFilter: String = ""
    @State private var selectedRecord: DiaryAnalysisData? = nil
    @State private var hasInitiallyLoaded = false  // 跟踪初始加载

    var body: some View {
        VStack(spacing: 0) {
            // 筛选栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    DiaryFilterChip(title: "全部", selected: selectedFilter == "") {
                        selectedFilter = ""
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: nil) }
                    }
                    DiaryFilterChip(title: "单条分析", selected: selectedFilter == "single") {
                        selectedFilter = "single"
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: "single") }
                    }
                    DiaryFilterChip(title: "批量分析", selected: selectedFilter == "batch") {
                        selectedFilter = "batch"
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: "batch") }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))

            // 列表
            if aiService.isLoadingHistory && aiService.analysisHistory.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if aiService.analysisHistory.isEmpty && hasInitiallyLoaded {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("暂无分析记录")
                        .foregroundColor(.secondary)
                    Text("使用上方的\"分析本周\"或\"分析上周\"按钮开始分析")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasInitiallyLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(aiService.analysisHistory.enumerated()), id: \.offset) { index, record in
                            DiaryAnalysisCard(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRecord = record
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await aiService.deleteAnalysisRecord(id: record.id)
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }

                        // 加载更多
                        if aiService.historyHasMore {
                            Button {
                                Task { await aiService.loadAnalysisHistory(filterType: selectedFilter.isEmpty ? nil : selectedFilter) }
                            } label: {
                                HStack {
                                    if aiService.isLoadingHistory {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("加载更多")
                                            .font(.subheadline)
                                    }
                                }
                                .foregroundColor(.appPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .disabled(aiService.isLoadingHistory)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await aiService.loadAnalysisHistory(refresh: true, filterType: selectedFilter.isEmpty ? nil : selectedFilter)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedRecord) { record in
            DiaryAnalysisDetailSheet(record: record)
        }
        .task {
            // 使用 task 确保只在首次出现时加载一次
            if !hasInitiallyLoaded {
                await aiService.loadAnalysisHistory(refresh: true, filterType: nil)
                hasInitiallyLoaded = true
            }
        }
    }
}

// MARK: - 筛选芯片

private struct DiaryFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(selected ? .medium : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分析记录卡片

private struct DiaryAnalysisCard: View {
    let record: DiaryAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：类型标签和日期
            HStack {
                // 类型标签
                HStack(spacing: 4) {
                    Image(systemName: record.isBatch ? "doc.on.doc.fill" : "doc.text.fill")
                        .font(.caption2)
                    Text(record.isBatch ? "批量 · \(record.period ?? "")" : "单条")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(record.isBatch ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                .foregroundColor(record.isBatch ? .blue : .green)
                .cornerRadius(12)

                Text("\(record.diaryCount) 篇日记")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 日记标题摘要
            Text(record.diarySnapshot?.titleSummary ?? "无标题")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            // 分析内容预览
            Text(record.analysis.replacingOccurrences(of: "#", with: "").prefix(100) + "...")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .lineSpacing(2)

            // 元数据
            HStack(spacing: 16) {
                if let modelName = record.modelName {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                        Text(modelName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                if let time = record.responseTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", Double(time) / 1000.0))s")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                if let tokens = record.tokensUsed {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(tokens)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - AI 分析历史弹窗

struct DiaryAIHistoryView: View {
    @ObservedObject var aiService: DiaryAIService  // 使用传入的service
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: String = ""
    @State private var selectedRecord: DiaryAnalysisData? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选栏
                HStack(spacing: 12) {
                    FilterButton(title: "全部", selected: selectedFilter == "") {
                        selectedFilter = ""
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: nil) }
                    }
                    FilterButton(title: "单条", selected: selectedFilter == "single") {
                        selectedFilter = "single"
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: "single") }
                    }
                    FilterButton(title: "批量", selected: selectedFilter == "batch") {
                        selectedFilter = "batch"
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: "batch") }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))

                // 列表
                if aiService.isLoadingHistory && aiService.analysisHistory.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if aiService.analysisHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无分析记录")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(aiService.analysisHistory) { record in
                            DiaryAnalysisHistoryRow(record: record)
                                .onTapGesture {
                                    selectedRecord = record
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                Task {
                                    await aiService.deleteAnalysisRecord(id: aiService.analysisHistory[index].id)
                                }
                            }
                        }

                        // 加载更多
                        if aiService.historyHasMore {
                            Button {
                                Task { await aiService.loadAnalysisHistory(filterType: selectedFilter.isEmpty ? nil : selectedFilter) }
                            } label: {
                                HStack {
                                    Spacer()
                                    if aiService.isLoadingHistory {
                                        ProgressView()
                                    } else {
                                        Text("加载更多")
                                            .foregroundColor(.appPrimary)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(aiService.isLoadingHistory)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI 分析记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await aiService.loadAnalysisHistory(refresh: true, filterType: selectedFilter.isEmpty ? nil : selectedFilter) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(aiService.isLoadingHistory)
                }
            }
            .sheet(item: $selectedRecord) { record in
                DiaryAnalysisDetailSheet(record: record)
            }
        }
        // 移除 .task 避免重复加载，由调用方控制加载时机
    }
}

// MARK: - 筛选按钮

private struct FilterButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 历史记录行

private struct DiaryAnalysisHistoryRow: View {
    let record: DiaryAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 类型标签
                Text(record.isBatch ? "批量 · \(record.period ?? "")" : "单条")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(record.isBatch ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(record.isBatch ? .blue : .green)
                    .cornerRadius(8)

                Text("\(record.diaryCount) 篇日记")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 日记标题摘要
            Text(record.diarySnapshot?.titleSummary ?? "无标题")
                .font(.subheadline)
                .lineLimit(1)

            // 分析内容预览
            Text(record.analysis)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 元数据
            HStack(spacing: 12) {
                if let modelName = record.modelName {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let time = record.responseTime {
                    Text("\(String(format: "%.1f", Double(time) / 1000.0))s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let tokens = record.tokensUsed {
                    Text("\(tokens) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 分析详情弹窗

private struct DiaryAnalysisDetailSheet: View {
    let record: DiaryAnalysisData
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginalDiaries = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 顶部信息栏
                    HStack(spacing: 12) {
                        // 类型标签
                        HStack(spacing: 6) {
                            Image(systemName: record.isBatch ? "doc.on.doc.fill" : "sparkles")
                                .font(.caption)
                            Text(record.isBatch ? "批量分析" : "智能分析")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)

                        if record.isBatch {
                            Text("\(record.period ?? "") · \(record.diaryCount)篇")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(record.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 朗读播放器
                    SpeechPlayerView(text: record.analysis, title: "AI分析")

                    // AI 分析结果（主角）
                    SelectableMarkdownView(content: record.analysis, fontSize: 16, lineSpacing: 10, theme: .warm)

                    // 元数据
                    HStack {
                        if let modelName = record.modelName {
                            Label(modelName, systemImage: "cpu")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let time = record.responseTime {
                            Label("\(String(format: "%.1f", Double(time) / 1000.0))秒", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    // 原日记（折叠，放在最后）
                    if let snapshot = record.diarySnapshot {
                        VStack(alignment: .leading, spacing: 0) {
                            // 折叠按钮
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showOriginalDiaries.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: showOriginalDiaries ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 16)

                                    Image(systemName: "doc.text")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text("查看原日记")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text("(\(record.diaryCount)篇)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            // 折叠内容
                            if showOriginalDiaries {
                                VStack(spacing: 12) {
                                    switch snapshot {
                                    case .single(let item):
                                        DiarySnapshotCard(item: item)
                                    case .batch(let items):
                                        ForEach(items.indices, id: \.self) { index in
                                            DiarySnapshotCard(item: items[index])
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("分析详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 日记快照卡片

private struct DiarySnapshotCard: View {
    let item: DiarySnapshotItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.moodEmoji)
                Text(item.weatherEmoji)
                if let createdAt = item.createdAt {
                    let isoFormatter = ISO8601DateFormatter()
                    if let date = isoFormatter.date(from: createdAt) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(item.title ?? "无标题")
                .font(.headline)

            if let content = item.content {
                SelectableText(
                    text: content,
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .secondaryLabel
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DiaryListView()
}

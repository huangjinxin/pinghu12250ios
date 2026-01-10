//
//  HomeworkListView.swift
//  pinghu12250
//
//  作业记录 - 记录每次作业完成情况
//

import SwiftUI
import Combine

struct HomeworkListView: View {
    @State private var homeworks: [Homework] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var selectedSubject: String? = nil
    @State private var viewingHomework: Homework? = nil  // 用于查看详情
    @State private var searchText = ""
    @State private var hasMore = true

    // 固定四列布局
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                searchBar

                // 筛选栏
                filterBar

                // 分页信息栏
                if !homeworks.isEmpty {
                    paginationBar
                }

                // 作业列表
                if isLoading && homeworks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredHomeworks.isEmpty {
                    emptyView
                } else {
                    homeworkGrid
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("作业记录")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadHomeworks()
            }
            .sheet(isPresented: $showCreateSheet) {
                HomeworkEditorSheet(onSave: {
                    Task { await loadHomeworks() }
                })
            }
            .sheet(item: $viewingHomework) { homework in
                HomeworkDetailSheet(homework: homework)
            }
        }
        .task {
            await loadHomeworks()
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索标题或内容...", text: $searchText)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SubjectFilterChip(subject: nil, label: "全部", selected: selectedSubject == nil) {
                    selectedSubject = nil
                }

                ForEach(Homework.subjectOptions, id: \.self) { subject in
                    SubjectFilterChip(subject: subject, label: subject, selected: selectedSubject == subject) {
                        selectedSubject = subject
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 分页信息栏

    private var paginationBar: some View {
        HStack {
            // 总数统计
            Text("共 \(filteredHomeworks.count) 条记录")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // 翻页控制
            HStack(spacing: 16) {
                Button {
                    Task { await loadHomeworks() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }

                if hasMore {
                    Button {
                        // 加载更多
                    } label: {
                        HStack(spacing: 4) {
                            Text("加载更多")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.appPrimary)
                    }
                    .disabled(isLoading)
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

    // MARK: - 作业网格 (四列布局)

    private var homeworkGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredHomeworks) { homework in
                    HomeworkCard(homework: homework, onDelete: {
                        Task { await deleteHomework(homework) }
                    })
                    .onTapGesture {
                        viewingHomework = homework
                    }
                }
            }
            .padding()
        }
    }

    private var filteredHomeworks: [Homework] {
        var result = homeworks

        // 科目筛选
        if let subject = selectedSubject {
            result = result.filter { $0.subject == subject }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { homework in
                homework.title.localizedCaseInsensitiveContains(searchText) ||
                homework.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有作业记录")
                .foregroundColor(.secondary)

            Button("记录作业") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 方法

    private func loadHomeworks() async {
        isLoading = true
        // 加载作业列表
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Mock data
        homeworks = [
            Homework(id: 1, title: "数学练习册第三章", subject: "数学", content: "完成第三章所有习题", difficulty: 4, timeSpent: 45, createdAt: Date()),
            Homework(id: 2, title: "英语单词背诵", subject: "英语", content: "背诵Unit5的新单词30个", difficulty: 2, timeSpent: 30, createdAt: Date().addingTimeInterval(-86400)),
            Homework(id: 3, title: "语文作文", subject: "语文", content: "写一篇关于春天的作文", difficulty: 3, timeSpent: 60, createdAt: Date().addingTimeInterval(-172800)),
            Homework(id: 4, title: "科学实验报告", subject: "科学", content: "完成植物生长观察实验报告", difficulty: 3, timeSpent: 40, createdAt: Date().addingTimeInterval(-259200)),
        ]
        isLoading = false
    }

    private func deleteHomework(_ homework: Homework) async {
        // 删除作业
        homeworks.removeAll { $0.id == homework.id }
    }
}

// MARK: - 作业模型

struct Homework: Identifiable {
    let id: Int
    var title: String
    var subject: String
    var content: String
    var difficulty: Int // 1-5
    var timeSpent: Int // 分钟
    var createdAt: Date

    static let subjectOptions = ["语文", "数学", "英语", "科学", "美术", "音乐", "体育", "其他"]

    var subjectColor: Color {
        switch subject {
        case "语文": return .red
        case "数学": return .blue
        case "英语": return .green
        case "科学": return .orange
        case "美术": return .purple
        case "音乐": return .pink
        case "体育": return .cyan
        default: return .gray
        }
    }
}

// MARK: - 科目筛选按钮

struct SubjectFilterChip: View {
    let subject: String?
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

// MARK: - 作业卡片

struct HomeworkCard: View {
    let homework: Homework
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：科目和日期
            HStack {
                Text(homework.subject)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(homework.subjectColor)
                    .cornerRadius(10)

                Spacer()

                Text(homework.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 标题
            Text(homework.title)
                .font(.headline)
                .lineLimit(2)

            // 内容
            Text(homework.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Divider()

            // 底部：难度和用时
            HStack {
                // 难度
                HStack(spacing: 4) {
                    Text("难度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DifficultyStars(rating: homework.difficulty)
                }

                Spacer()

                // 用时
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(homework.timeSpent)分钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 删除按钮
            HStack {
                Spacer()
                Button("删除", role: .destructive) {
                    showDeleteAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这条作业记录吗？")
        }
    }
}

// MARK: - 难度星级

struct DifficultyStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(index <= rating ? .yellow : .gray.opacity(0.3))
            }
        }
    }
}

// MARK: - 作业编辑器

struct HomeworkEditorSheet: View {
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var subject = "语文"
    @State private var content = ""
    @State private var difficulty = 3
    @State private var timeSpent = 30
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)

                    Picker("科目", selection: $subject) {
                        ForEach(Homework.subjectOptions, id: \.self) { sub in
                            Text(sub).tag(sub)
                        }
                    }
                }

                Section("作业内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }

                Section("完成情况") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("难度")
                            Spacer()
                            DifficultySelector(rating: $difficulty)
                        }

                        HStack {
                            Text("用时（分钟）")
                            Spacer()
                            Stepper("\(timeSpent)", value: $timeSpent, in: 1...300, step: 5)
                        }
                    }
                }
            }
            .navigationTitle("记录作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await saveHomework() }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveHomework() async {
        isSaving = true
        // 保存作业
        try? await Task.sleep(nanoseconds: 500_000_000)
        isSaving = false
        onSave()
        dismiss()
    }
}

// MARK: - 难度选择器

struct DifficultySelector: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    rating = index
                } label: {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(index <= rating ? .yellow : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 作业详情弹窗

struct HomeworkDetailSheet: View {
    let homework: Homework

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部信息
                    VStack(alignment: .leading, spacing: 12) {
                        // 科目标签
                        Text(homework.subject)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(homework.subjectColor)
                            .cornerRadius(20)

                        // 标题
                        Text(homework.title)
                            .font(.title)
                            .fontWeight(.bold)

                        // 日期
                        Text(homework.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 作业内容
                    VStack(alignment: .leading, spacing: 12) {
                        Text("作业内容")
                            .font(.headline)

                        Text(homework.content)
                            .font(.body)
                            .lineSpacing(6)
                    }

                    Divider()

                    // 完成情况
                    VStack(alignment: .leading, spacing: 16) {
                        Text("完成情况")
                            .font(.headline)

                        HStack(spacing: 40) {
                            // 难度
                            VStack(spacing: 8) {
                                DifficultyStars(rating: homework.difficulty)
                                Text("难度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // 用时
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.appPrimary)
                                    Text("\(homework.timeSpent)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.appPrimary)
                                    Text("分钟")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("用时")
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
            .navigationTitle("作业详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeworkListView()
}

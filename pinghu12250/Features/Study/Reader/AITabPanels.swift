//
//  AITabPanels.swift
//  pinghu12250
//
//  AI 辅助面板 - 5个Tab组件
//  与 Web 端对齐：探索/解析/练习/解题/笔记
//

import SwiftUI
import Combine

// MARK: - 探索 Tab（本地PDF搜索 - 聊天卡片模式）

struct ExploreTabView: View {
    @ObservedObject var state: ReaderState
    @State private var searchText: String = ""
    @State private var searchHistory: [ExploreMessage] = []  // 聊天历史记录
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 聊天内容区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if searchHistory.isEmpty {
                            // 欢迎提示
                            welcomeMessage
                        } else {
                            // 聊天卡片列表
                            ForEach(searchHistory) { message in
                                ExploreChatCard(
                                    message: message,
                                    onPageTap: { page in
                                        state.jumpToPage(page)
                                        isInputFocused = false
                                    }
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: searchHistory.count) { _, _ in
                    // 滚动到最新消息
                    if let lastMessage = searchHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 搜索输入区域
            searchInputArea
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.appPrimary)

            Text("分析教材内容")
                .font(.headline)

            Text("输入关键词，快速定位到对应页面")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 快捷搜索建议
            VStack(spacing: 8) {
                Text("试试搜索：")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    quickSearchButton("目录")
                    quickSearchButton("练习")
                    quickSearchButton("思考")
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    private func quickSearchButton(_ text: String) -> some View {
        Button {
            searchText = text
            performSearch()
        } label: {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appPrimary.opacity(0.1))
                .cornerRadius(16)
        }
    }

    private var searchInputArea: some View {
        UnifiedInputBar(
            mode: .search,
            text: $searchText,
            pendingImage: .constant(nil),
            isLoading: state.isSearching,
            onSend: { text, _ in
                searchText = text
                performSearch()
            }
        )
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        let query = searchText
        isInputFocused = false

        // 添加用户消息到历史
        let userMessage = ExploreMessage(
            role: .user,
            content: query,
            results: []
        )
        searchHistory.append(userMessage)

        // 清空输入框
        searchText = ""

        // 执行搜索
        Task {
            await state.searchPDF(query)

            // 添加搜索结果到历史
            let resultMessage = ExploreMessage(
                role: .assistant,
                content: state.searchResults.isEmpty ? "未找到「\(query)」相关内容" : "找到 \(state.searchResults.count) 个相关结果：",
                results: state.searchResults
            )
            searchHistory.append(resultMessage)
        }
    }
}

// MARK: - 探索消息模型

struct ExploreMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let results: [PDFSearchResult]
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - 探索聊天卡片

struct ExploreChatCard: View {
    let message: ExploreMessage
    let onPageTap: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // AI 头像
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // 消息内容
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(12)
                    .background(message.role == .user ? Color.appPrimary : Color(.systemGray6))
                    .cornerRadius(16)

                // 搜索结果列表（仅 AI 消息显示）
                if message.role == .assistant && !message.results.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(message.results) { result in
                            ExploreResultRow(
                                result: result,
                                onTap: { onPageTap(result.pageNumber) }
                            )
                        }
                    }
                }
            }

            if message.role == .user {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - 探索结果行

struct ExploreResultRow: View {
    let result: PDFSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 页码标签
                Text("P\(result.pageNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appPrimary)
                    .cornerRadius(6)

                // 匹配内容
                Text(result.contextText)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // 跳转指示
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 解析 Tab（重构：添加底部输入框和深入学习按钮）

struct AnalyzeTabView: View {
    @ObservedObject var state: ReaderState
    @State private var inputText: String = ""
    @State private var chatHistory: [AnalyzeChatMessage] = []
    @State private var isAnalyzing = false
    @State private var localPendingImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 聊天内容区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if chatHistory.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(chatHistory) { message in
                                AnalyzeChatBubble(message: message)
                                    .id(message.id)
                            }

                            // 加载中显示停止按钮
                            if isAnalyzing {
                                HStack {
                                    LoadingBubble()
                                    Spacer()
                                    StopButton {
                                        stopAnalyzing()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatHistory.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // 底部输入区
            UnifiedInputBar(
                mode: .chat,
                text: $inputText,
                pendingImage: $localPendingImage,
                isLoading: isAnalyzing,
                onSend: { text, image in
                    sendMessage(text: text, image: image)
                },
                onImagePick: {
                    // 从相册选择图片
                },
                onCurrentPageCapture: {
                    captureCurrentPage()
                },
                onRegionCapture: {
                    // 请求区域截图（触发PDF视图的框选模式）
                    state.requestRegionCapture()
                },
                specialButton: AnyView(
                    DeepLearnButton(isLoading: isAnalyzing) {
                        deepLearnCurrentPage()
                    }
                )
            )
        }
        .onAppear {
            // 同步state的pendingImage到本地
            if let image = state.pendingImage {
                localPendingImage = image
            }
        }
        .onChange(of: state.pendingImage) { _, newImage in
            if let image = newImage {
                localPendingImage = image
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.purple.opacity(0.6))

            Text("AI解析助手")
                .font(.headline)

            Text("选择PDF内容、截取区域，或直接输入问题")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 快捷操作提示
            VStack(spacing: 12) {
                quickHintRow(icon: "hand.tap", text: "选择文字或区域后自动识别")
                quickHintRow(icon: "book.pages", text: "点击「深入学习本页」分析当前页")
                quickHintRow(icon: "keyboard", text: "直接输入问题与AI对话")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    private func quickHintRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatHistory.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 操作方法

    private func captureCurrentPage() {
        Task {
            if let image = await state.captureCurrentPageAsync() {
                await MainActor.run {
                    localPendingImage = image
                }
            }
        }
    }

    private func deepLearnCurrentPage() {
        Task {
            if let image = await state.captureCurrentPageAsync() {
                await MainActor.run {
                    sendMessage(text: "请帮我分析这一页的内容，提取关键知识点", image: image)
                }
            }
        }
    }

    private func sendMessage(text: String, image: UIImage?) {
        // 添加用户消息
        let userMessage = AnalyzeChatMessage(
            role: .user,
            content: text.isEmpty ? "请分析这张图片" : text,
            image: image
        )
        chatHistory.append(userMessage)

        // 清空本地图片
        localPendingImage = nil
        state.pendingImage = nil

        // 调用AI
        isAnalyzing = true

        // 使用流式AI响应
        Task {
            do {
                var responseContent = ""

                // 使用真实AI服务
                for try await chunk in AIStudyService.shared.streamChatAsync(
                    textbookId: state.textbook.id,
                    message: text.isEmpty ? "请分析这张图片的内容，提取关键知识点" : text,
                    image: image,
                    page: state.currentPage,
                    subject: subjectCode(state.textbook.subject)
                ) {
                    responseContent += chunk

                    // 实时更新最后一条消息
                    await MainActor.run {
                        // 如果已有AI消息，更新它；否则创建新消息
                        if let lastIndex = chatHistory.indices.last,
                           chatHistory[lastIndex].role == .assistant {
                            // 替换最后一条消息
                            chatHistory[lastIndex] = AnalyzeChatMessage(
                                role: .assistant,
                                content: responseContent,
                                image: nil
                            )
                        } else {
                            // 创建新的AI消息
                            let assistantMessage = AnalyzeChatMessage(
                                role: .assistant,
                                content: responseContent,
                                image: nil
                            )
                            chatHistory.append(assistantMessage)
                        }
                    }
                }

                await MainActor.run {
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    // 显示错误消息
                    let errorMessage = AnalyzeChatMessage(
                        role: .assistant,
                        content: "抱歉，分析时出现错误：\(error.localizedDescription)",
                        image: nil
                    )
                    chatHistory.append(errorMessage)
                    isAnalyzing = false
                }
            }
        }
    }

    private func subjectCode(_ subject: String) -> String {
        switch subject {
        case "语文": return "CHINESE"
        case "数学": return "MATH"
        case "英语": return "ENGLISH"
        default: return "CHINESE"
        }
    }

    private func stopAnalyzing() {
        AIStudyService.shared.cancelCurrentRequest()
        isAnalyzing = false
        // 如果有未完成的AI消息，添加中断提示
        if let lastIndex = chatHistory.indices.last,
           chatHistory[lastIndex].role == .assistant {
            chatHistory[lastIndex] = AnalyzeChatMessage(
                role: .assistant,
                content: chatHistory[lastIndex].content + "\n\n[已中断]",
                image: nil
            )
        }
    }
}

// MARK: - 解析Tab聊天消息模型

struct AnalyzeChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let image: UIImage?
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - 解析Tab聊天气泡

struct AnalyzeChatBubble: View {
    let message: AnalyzeChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // 图片（如果有）
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .cornerRadius(8)
                }

                // 文本内容
                if message.role == .assistant {
                    RichContentView(text: message.content)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                } else {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.purple)
                        .cornerRadius(16)
                }
            }

            if message.role == .user {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - 练习 Tab

struct PracticeTabView: View {
    @ObservedObject var state: ReaderState
    @State private var questionCount: Int = 5
    @State private var questionTypes: Set<String> = ["choice"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if state.practiceQuestions.isEmpty {
                    // 生成设置
                    practiceSettingsCard

                    // 加载中显示停止按钮
                    if state.isPracticeLoading {
                        HStack {
                            LoadingBubble()
                            Spacer()
                            StopButton {
                                stopGenerating()
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // 练习题列表
                    ForEach(Array(state.practiceQuestions.enumerated()), id: \.offset) { index, question in
                        PracticeQuestionView(question: question, index: index)
                    }

                    // 重新生成按钮
                    Button {
                        state.practiceQuestions = []
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重新出题")
                        }
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func stopGenerating() {
        AIStudyService.shared.cancelCurrentRequest()
        state.isPracticeLoading = false
    }

    private var practiceSettingsCard: some View {
        VStack(spacing: 20) {
            // 标题
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text("根据当前页面生成练习题")
                    .font(.headline)
            }

            Divider()

            // 题目数量
            VStack(alignment: .leading, spacing: 8) {
                Text("题目数量")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $questionCount) {
                    Text("3题").tag(3)
                    Text("5题").tag(5)
                    Text("10题").tag(10)
                }
                .pickerStyle(.segmented)
            }

            // 题型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("题目类型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    typeToggle("choice", label: "选择题")
                    typeToggle("blank", label: "填空题")
                    typeToggle("judge", label: "判断题")
                }
            }

            // 生成按钮
            Button {
                generateQuestions()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("生成练习题")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(state.isPracticeLoading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }

    private func typeToggle(_ type: String, label: String) -> some View {
        Button {
            if questionTypes.contains(type) {
                questionTypes.remove(type)
            } else {
                questionTypes.insert(type)
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .foregroundColor(questionTypes.contains(type) ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(questionTypes.contains(type) ? Color.green : Color(.systemGray5))
                .cornerRadius(8)
        }
    }

    private func generateQuestions() {
        state.isPracticeLoading = true

        Task {
            do {
                // 先截取当前页面图片
                guard let pageImage = await state.captureCurrentPageAsync() else {
                    await MainActor.run {
                        state.isPracticeLoading = false
                    }
                    return
                }

                // 构建题型要求
                let typeNames = questionTypes.map { type -> String in
                    switch type {
                    case "choice": return "选择题"
                    case "blank": return "填空题"
                    case "judge": return "判断题"
                    default: return type
                    }
                }.joined(separator: "、")

                // 使用AI生成练习题
                let prompt = """
                【练习题生成请求】第\(state.currentPage)页

                请根据这张图片中的教材内容，生成\(questionCount)道练习题。
                题型要求：\(typeNames)
                要求：
                1. 题目难度适合小学生
                2. 每道题附带正确答案和解析

                严格按以下JSON格式输出（不要输出其他内容）：
                {
                  "questions": [
                    {
                      "type": "choice",
                      "stem": "题干文本",
                      "options": [{"value": "A", "text": "选项A"}, {"value": "B", "text": "选项B"}, {"value": "C", "text": "选项C"}, {"value": "D", "text": "选项D"}],
                      "answer": "B",
                      "analysis": "解析文本"
                    }
                  ]
                }

                题目类型说明：
                - choice: 选择题（必须有options）
                - blank: 填空题（answer为填空答案，不需要options）
                - judge: 判断题（answer为"对"或"错"，不需要options）
                """

                var responseContent = ""

                // 使用流式AI服务收集完整响应
                for try await chunk in AIStudyService.shared.streamChatAsync(
                    textbookId: state.textbook.id,
                    message: prompt,
                    image: pageImage,
                    page: state.currentPage,
                    subject: subjectCode(state.textbook.subject)
                ) {
                    responseContent += chunk
                }

                // 解析JSON响应
                let questions = parsePracticeQuestions(from: responseContent)

                await MainActor.run {
                    state.practiceQuestions = questions
                    state.isPracticeLoading = false
                }

            } catch {
                await MainActor.run {
                    #if DEBUG
                    print("生成练习题失败: \(error.localizedDescription)")
                    #endif
                    state.isPracticeLoading = false
                }
            }
        }
    }

    private func subjectCode(_ subject: String) -> String {
        switch subject {
        case "语文": return "CHINESE"
        case "数学": return "MATH"
        case "英语": return "ENGLISH"
        default: return "CHINESE"
        }
    }

    private func parsePracticeQuestions(from content: String) -> [PracticeQuestionData] {
        // 尝试找到JSON部分
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            return []
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }

        // 解析JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questionsArray = json["questions"] as? [[String: Any]] else {
            // 尝试解析为单个题目
            if let singleQuestion = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let stem = singleQuestion["stem"] as? String {
                return [parseSingleQuestion(singleQuestion)].compactMap { $0 }
            }
            return []
        }

        return questionsArray.compactMap { parseSingleQuestion($0) }
    }

    private func parseSingleQuestion(_ item: [String: Any]) -> PracticeQuestionData? {
        guard let stem = item["stem"] as? String,
              let answer = item["answer"] as? String else {
            return nil
        }

        let type = (item["type"] as? String) ?? "choice"
        let analysis = (item["analysis"] as? String) ?? ""

        // 解析选项
        var options: [PracticeQuestionData.QuestionOption]?
        if let optionsArray = item["options"] as? [[String: Any]] {
            options = optionsArray.compactMap { opt in
                guard let value = opt["value"] as? String,
                      let text = opt["text"] as? String else { return nil }
                return PracticeQuestionData.QuestionOption(value: value, text: text)
            }
        }

        return PracticeQuestionData(
            stem: stem,
            type: type,
            options: options,
            answer: answer,
            analysis: analysis
        )
    }
}

// MARK: - 解题 Tab（重构：添加底部输入框，使用解题专用提示词）

struct SolvingTabView: View {
    @ObservedObject var state: ReaderState
    @State private var inputText: String = ""
    @State private var chatHistory: [SolvingChatMessage] = []
    @State private var isSolving = false
    @State private var localPendingImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 聊天内容区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if chatHistory.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(chatHistory) { message in
                                SolvingChatBubble(
                                    message: message,
                                    onSaveToNotes: {
                                        saveToNotes(message)
                                    }
                                )
                                .id(message.id)
                            }

                            // 加载中显示停止按钮
                            if isSolving {
                                HStack {
                                    LoadingBubble()
                                    Spacer()
                                    StopButton {
                                        stopSolving()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatHistory.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // 底部输入区
            UnifiedInputBar(
                mode: .chat,
                text: $inputText,
                pendingImage: $localPendingImage,
                isLoading: isSolving,
                onSend: { text, image in
                    sendSolvingRequest(text: text, image: image)
                },
                onImagePick: {
                    // 从相册选择图片
                },
                onCurrentPageCapture: {
                    captureCurrentPage()
                },
                onRegionCapture: {
                    // 请求区域截图（触发PDF视图的框选模式）
                    state.requestRegionCapture()
                }
            )
        }
        .onAppear {
            if let image = state.pendingImage {
                localPendingImage = image
            }
        }
        .onChange(of: state.pendingImage) { _, newImage in
            if let image = newImage {
                localPendingImage = image
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange.opacity(0.8))

            Text("AI解题助手")
                .font(.headline)

            Text("截取题目或输入问题，AI帮你解答")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 使用提示
            VStack(alignment: .leading, spacing: 12) {
                Text("使用方法")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .overlay(Text("1").font(.caption2).foregroundColor(.white))
                    Text("在左侧PDF中框选题目区域，或点击图片按钮截取当前页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .overlay(Text("2").font(.caption2).foregroundColor(.white))
                    Text("输入问题描述（可选），点击发送获取解答")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .overlay(Text("3").font(.caption2).foregroundColor(.white))
                    Text("查看详细解题步骤，可保存到笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatHistory.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 操作方法

    private func captureCurrentPage() {
        Task {
            if let image = await state.captureCurrentPageAsync() {
                await MainActor.run {
                    localPendingImage = image
                }
            }
        }
    }

    private func sendSolvingRequest(text: String, image: UIImage?) {
        // 添加用户消息
        let userMessage = SolvingChatMessage(
            role: .user,
            content: text.isEmpty ? "请帮我解答这道题" : text,
            image: image
        )
        chatHistory.append(userMessage)

        // 清空本地图片
        localPendingImage = nil
        state.pendingImage = nil

        // 使用解题专用提示词
        let solvingPrompt = """
        【解题请求】
        你是一位专业的解题老师，请帮助学生解答题目。
        要求：
        1. 分析题目类型和考查知识点
        2. 给出详细的解题步骤
        3. 提供答案和解析
        4. 总结相关知识点

        学生的问题：\(text.isEmpty ? "请帮我解答图片中的题目" : text)
        """

        // 调用AI
        isSolving = true

        Task {
            do {
                var responseContent = ""

                // 使用真实AI服务
                for try await chunk in AIStudyService.shared.streamChatAsync(
                    textbookId: state.textbook.id,
                    message: solvingPrompt,
                    image: image,
                    page: state.currentPage,
                    subject: subjectCode(state.textbook.subject)
                ) {
                    responseContent += chunk

                    // 实时更新最后一条消息
                    await MainActor.run {
                        if let lastIndex = chatHistory.indices.last,
                           chatHistory[lastIndex].role == .assistant {
                            chatHistory[lastIndex] = SolvingChatMessage(
                                role: .assistant,
                                content: responseContent,
                                image: nil
                            )
                        } else {
                            let assistantMessage = SolvingChatMessage(
                                role: .assistant,
                                content: responseContent,
                                image: nil
                            )
                            chatHistory.append(assistantMessage)
                        }
                    }
                }

                await MainActor.run {
                    isSolving = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = SolvingChatMessage(
                        role: .assistant,
                        content: "抱歉，解题时出现错误：\(error.localizedDescription)",
                        image: nil
                    )
                    chatHistory.append(errorMessage)
                    isSolving = false
                }
            }
        }
    }

    private func subjectCode(_ subject: String) -> String {
        switch subject {
        case "语文": return "CHINESE"
        case "数学": return "MATH"
        case "英语": return "ENGLISH"
        default: return "CHINESE"
        }
    }

    private func stopSolving() {
        AIStudyService.shared.cancelCurrentRequest()
        isSolving = false
        // 如果有未完成的AI消息，添加中断提示
        if let lastIndex = chatHistory.indices.last,
           chatHistory[lastIndex].role == .assistant {
            chatHistory[lastIndex] = SolvingChatMessage(
                role: .assistant,
                content: chatHistory[lastIndex].content + "\n\n[已中断]",
                image: nil
            )
        }
    }

    private func saveToNotes(_ message: SolvingChatMessage) {
        // 使用 NotesManager 保存到笔记
        Task {
            let note = StudyNote(
                textbookId: state.textbook.id,
                pageIndex: state.currentPage - 1,  // 转为0索引
                title: "解题记录",
                content: message.content,
                type: .question,
                tags: ["解题"]
            )
            await NotesManager.shared.createNote(note)
            #if DEBUG
            print("解题记录已保存到笔记")
            #endif
        }
    }
}

// MARK: - 解题Tab聊天消息模型

struct SolvingChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let image: UIImage?
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - 解题Tab聊天气泡

struct SolvingChatBubble: View {
    let message: SolvingChatMessage
    var onSaveToNotes: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 32, height: 32)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // 图片（如果有）
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .cornerRadius(8)
                }

                // 文本内容
                if message.role == .assistant {
                    VStack(alignment: .leading, spacing: 8) {
                        RichContentView(text: message.content)

                        // 保存按钮
                        if let onSave = onSaveToNotes {
                            HStack {
                                Spacer()
                                Button(action: onSave) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bookmark")
                                        Text("保存到笔记")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                } else {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.orange)
                        .cornerRadius(16)
                }
            }

            if message.role == .user {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - 笔记 Tab（重构：添加输入框，同步Web端API，支持语音笔记）

struct NotesTabView: View {
    @ObservedObject var state: ReaderState
    @State private var inputText: String = ""
    @State private var notes: [ReadingNote] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var localPendingImage: UIImage? = nil
    @State private var showDeleteConfirm = false
    @State private var noteToDelete: ReadingNote? = nil

    // 语音笔记相关
    @State private var showVoiceRecording = false
    @StateObject private var voiceService = VoiceInputService.shared

    // 按页码分组的笔记
    private var currentPageNotes: [ReadingNote] {
        notes.filter { $0.page == state.currentPage }
    }

    private var otherNotes: [ReadingNote] {
        notes.filter { $0.page != state.currentPage }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 笔记列表区域
            ScrollView {
                LazyVStack(spacing: 12) {
                    if notes.isEmpty && !isLoading {
                        emptyStateView
                    } else {
                        // 当前页笔记
                        if !currentPageNotes.isEmpty {
                            notesSection(
                                title: "当前页笔记 (第\(state.currentPage)页)",
                                notes: currentPageNotes,
                                isCurrentPage: true
                            )
                        }

                        // 其他笔记
                        if !otherNotes.isEmpty {
                            notesSection(
                                title: "其他笔记",
                                notes: otherNotes,
                                isCurrentPage: false
                            )
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await loadNotes()
            }

            Divider()

            // 底部输入区
            UnifiedInputBar(
                mode: .note,
                text: $inputText,
                pendingImage: $localPendingImage,
                isLoading: isSaving,
                onSend: { text, image in
                    Task {
                        await addNote(text: text, image: image)
                    }
                },
                onImagePick: {
                    // 从相册选择图片
                },
                onCurrentPageCapture: {
                    captureCurrentPage()
                },
                onRegionCapture: {
                    // 请求区域截图（触发PDF视图的框选模式）
                    state.requestRegionCapture()
                },
                onVoiceNote: {
                    showVoiceRecording = true
                }
            )
        }
        .task {
            await loadNotes()
        }
        .alert("删除笔记", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let note = noteToDelete {
                    Task { await deleteNote(note) }
                }
            }
        } message: {
            Text("确定要删除这条笔记吗？")
        }
        .sheet(isPresented: $showVoiceRecording) {
            VoiceNoteRecordingSheet(
                service: voiceService,
                onSave: { result, editedText in
                    Task {
                        await saveVoiceNote(result: result, text: editedText)
                    }
                    showVoiceRecording = false
                },
                onCancel: {
                    voiceService.cancel()
                    showVoiceRecording = false
                }
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 50))
                .foregroundColor(.orange.opacity(0.6))

            Text("学习笔记")
                .font(.headline)

            Text("在下方输入内容添加笔记，笔记会关联到当前页面")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 提示
            VStack(spacing: 12) {
                noteHintRow(icon: "mic.fill", text: "点击麦克风录制语音笔记")
                noteHintRow(icon: "text.cursor", text: "输入文字记录学习心得")
                noteHintRow(icon: "photo", text: "添加截图保存重要内容")
                noteHintRow(icon: "icloud.and.arrow.up", text: "笔记自动同步到云端")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    private func noteHintRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func notesSection(title: String, notes: [ReadingNote], isCurrentPage: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)

                Spacer()

                Text("\(notes.count)条")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            ForEach(notes) { note in
                NoteCardEditable(
                    note: note,
                    isCurrentPage: isCurrentPage,
                    onTap: {
                        // 跳转到笔记所在页面
                        if let page = note.page, page != state.currentPage {
                            state.jumpToPage(page)
                        }
                    },
                    onDelete: {
                        noteToDelete = note
                        showDeleteConfirm = true
                    }
                )
            }
        }
    }

    // MARK: - 操作方法

    private func captureCurrentPage() {
        Task {
            if let image = await state.captureCurrentPageAsync() {
                await MainActor.run {
                    localPendingImage = image
                }
            }
        }
    }

    private func loadNotes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 调用真实API获取笔记
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "?textbookId=\(state.textbook.id)") else {
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            if let token = await MainActor.run(body: { APIService.shared.authToken }) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            // 解析响应
            let decoder = JSONDecoder()
            if let apiResponse = try? decoder.decode(ReadingNotesAPIResponse.self, from: data) {
                await MainActor.run {
                    notes = apiResponse.allNotes
                }
            }

        } catch {
            #if DEBUG
            print("加载笔记失败: \(error)")
            #endif
        }
    }

    private func addNote(text: String, image: UIImage?) async {
        isSaving = true
        defer { isSaving = false }

        // 如果有图片，先上传图片
        var imageUrl: String?
        if let image = image {
            imageUrl = await uploadImage(image)
        }

        // 使用 NotesManager 保存笔记
        let note = StudyNote(
            textbookId: state.textbook.id,
            pageIndex: state.currentPage - 1,  // 转为0索引
            title: String(text.prefix(50)),
            content: text,
            type: imageUrl != nil ? .highlight : .text,
            tags: imageUrl != nil ? ["截图"] : []
        )

        await MainActor.run {
            NotesManager.shared.createNote(note)
        }

        // 添加到本地列表用于立即显示
        let newNote = ReadingNote(
            id: note.id.uuidString,
            userId: "",
            textbookId: state.textbook.id,
            sessionId: nil,
            sourceType: "user_note",
            query: String(text.prefix(50)),
            content: nil,
            snippet: String(text.prefix(100)),
            page: state.currentPage,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        )

        await MainActor.run {
            notes.insert(newNote, at: 0)
        }
    }

    private func uploadImage(_ image: UIImage) async -> String? {
        // 压缩图片
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.upload) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = await MainActor.run(body: { APIService.shared.authToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 创建multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"note_image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                return nil
            }

            // 解析返回的URL
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let imageUrl = json["url"] as? String {
                return imageUrl
            }
        } catch {
            #if DEBUG
            print("上传图片失败: \(error)")
            #endif
        }

        return nil
    }

    private func deleteNote(_ note: ReadingNote) async {
        do {
            // 调用真实API删除笔记
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "/\(note.id)") else {
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            if let token = await MainActor.run(body: { APIService.shared.authToken }) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                #if DEBUG
                print("删除笔记失败: HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                #endif
                return
            }

            // 从本地列表移除
            await MainActor.run {
                notes.removeAll { $0.id == note.id }
            }

        } catch {
            #if DEBUG
            print("删除笔记失败: \(error)")
            #endif
        }
    }

    // MARK: - 保存语音笔记

    private func saveVoiceNote(result: VoiceNoteResult, text: String) async {
        isSaving = true
        defer { isSaving = false }

        // 上传音频文件
        var audioUrl: String? = nil
        do {
            audioUrl = try await uploadAudioFile(url: result.audioFileURL)
        } catch {
            #if DEBUG
            print("上传音频失败: \(error)")
            #endif
        }

        // 创建语音笔记
        let voiceNoteData = VoiceNoteData(
            localURL: result.audioFileURL,
            transcribedText: text,
            duration: result.duration,
            isOffline: result.isOfflineRecognized
        )

        // 使用 NotesManager 保存
        let note = StudyNote(
            textbookId: state.textbook.id,
            pageIndex: state.currentPage - 1,
            title: String(text.prefix(30)),
            content: text,
            type: .text,  // 使用文本类型，通过附件区分
            tags: ["语音笔记"],
            attachments: audioUrl != nil ? [.voiceNote(url: audioUrl!, duration: result.duration)] : []
        )

        await MainActor.run {
            NotesManager.shared.createNote(note)
        }

        // 添加到本地列表
        let newNote = ReadingNote(
            id: note.id.uuidString,
            userId: "",
            textbookId: state.textbook.id,
            sessionId: nil,
            sourceType: "voice_note",
            query: String(text.prefix(50)),
            content: nil,
            snippet: String(text.prefix(100)),
            page: state.currentPage,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        )

        await MainActor.run {
            notes.insert(newNote, at: 0)
        }

        #if DEBUG
        print("[NotesTab] 语音笔记已保存: \(text.prefix(30))...")
        #endif
    }

    private func uploadAudioFile(url: URL) async throws -> String? {
        guard let uploadURL = URL(string: APIConfig.baseURL + APIConfig.Endpoints.upload) else {
            return nil
        }

        let audioData = try Data(contentsOf: url)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"

        if let token = await MainActor.run(body: { APIService.shared.authToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"voice_note.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            return nil
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let audioUrl = json["url"] as? String {
            return audioUrl
        }

        return nil
    }
}

// MARK: - 笔记卡片组件（可删除）

struct NoteCardEditable: View {
    let note: ReadingNote
    let isCurrentPage: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 头部信息
                HStack {
                    Image(systemName: note.typeIcon)
                        .foregroundColor(note.typeColor)
                        .font(.system(size: 14))

                    Text(note.typeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let page = note.page {
                        Text("P\(page)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isCurrentPage ? Color.orange : Color.gray)
                            .cornerRadius(4)
                    }

                    // 删除按钮
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }

                // 笔记内容
                if let snippet = note.snippet {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // 图片预览（如果有）
                if let imageUrl = note.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 100)
                            .cornerRadius(8)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 60)
                            .overlay(
                                ProgressView()
                            )
                    }
                }

                // 时间
                if let createdAt = note.createdAtDate {
                    Text(createdAt.relativeDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 辅助组件

struct ChatBubble: View {
    let message: ReaderChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .cornerRadius(8)
                }

                if message.role == .assistant {
                    RichContentView(text: message.content)
                } else {
                    Text(message.content)
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(message.role == .user ? Color.appPrimary : Color(.systemGray6))
            .cornerRadius(16)

            if message.role == .user {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct LoadingBubble: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(.appPrimary)
                .frame(width: 32, height: 32)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 8, height: 8)
                        .opacity(dotCount == i ? 1 : 0.3)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    dotCount = (dotCount + 1) % 3
                }
            }

            Spacer()
        }
    }
}

// MARK: - 停止按钮

struct StopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "stop.fill")
                    .font(.caption)
                Text("停止")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

struct NoteCardCompact: View {
    let note: ReadingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.typeIcon)
                    .foregroundColor(note.typeColor)
                Text(note.typeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let page = note.page {
                    Text("P\(page)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let snippet = note.snippet {
                Text(snippet)
                    .font(.subheadline)
                    .lineLimit(3)
            }

            Text(note.createdAt?.relativeDescription ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

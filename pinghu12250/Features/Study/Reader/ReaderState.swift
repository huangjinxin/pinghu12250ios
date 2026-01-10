//
//  ReaderState.swift
//  pinghu12250
//
//  统一状态管理器 - 教材阅读器核心状态
//

import SwiftUI
@preconcurrency import PDFKit
import Combine
import AVFoundation

// MARK: - 阅读器模式

enum ReaderMode: Equatable {
    case pureReading    // 纯阅读模式（竖屏）
    case aiAssist       // AI辅助模式（横屏）
}

// MARK: - 内容类型

enum ContentType: Equatable {
    case pdf
    case epub
}

// MARK: - 内容位置（统一 PDF/EPUB 定位）

enum ContentPosition: Equatable {
    case pdf(page: Int)
    case epub(chapterId: String, paragraphId: String?, textRange: TextRangeData?)

    /// 获取用于显示的位置描述
    var displayText: String {
        switch self {
        case .pdf(let page):
            return "P\(page)"
        case .epub(let chapterId, _, _):
            return chapterId
        }
    }
}

// MARK: - AI Tab 类型（与 Web 端对齐）
// 顺序：探索 → 解析 → 练习 → 解题 → 笔记

enum AITab: String, CaseIterable, Identifiable {
    case explore = "探索"      // 本地PDF搜索
    case analyze = "解析"      // 内容解析 + AI对话
    case practice = "练习"     // 出题练习
    case solving = "解题"      // 解题辅助
    case notes = "笔记"        // 笔记管理

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .explore: return "magnifyingglass"
        case .analyze: return "doc.text.magnifyingglass"
        case .practice: return "checklist"
        case .solving: return "lightbulb"
        case .notes: return "note.text"
        }
    }

    var description: String {
        switch self {
        case .explore: return "搜索教材内容"
        case .analyze: return "AI分析并解释内容"
        case .practice: return "根据内容生成练习题"
        case .solving: return "AI帮助解答题目"
        case .notes: return "管理学习笔记"
        }
    }

    /// 是否需要底部输入框
    var needsInputBar: Bool {
        switch self {
        case .explore, .analyze, .solving, .notes:
            return true
        case .practice:
            return false
        }
    }
}

// MARK: - 选中内容类型

enum SelectionType: Equatable {
    case none
    case text(String)           // 选中文本
    case region(UIImage)        // 框选区域截图
    case page                   // 整页截图

    var isNone: Bool {
        if case .none = self { return true }
        return false
    }

    var hasContent: Bool {
        !isNone
    }

    static func == (lhs: SelectionType, rhs: SelectionType) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.text(let a), .text(let b)):
            return a == b
        case (.page, .page):
            return true
        case (.region, .region):
            return true  // UIImage 比较不实用，简单返回 true
        default:
            return false
        }
    }
}

// MARK: - 统一状态管理器

@MainActor
final class ReaderState: ObservableObject {
    // MARK: - 教材信息

    let textbook: Textbook

    // MARK: - 内容类型

    @Published var contentType: ContentType = .pdf

    // MARK: - PDF 状态

    @Published var pdfDocument: PDFDocument?
    @Published var totalPages: Int = 0
    @Published var isLoading = true
    @Published var loadError: String?

    // MARK: - EPUB 状态

    @Published var chapters: [EPUBChapter] = []
    @Published var currentChapterId: String = ""
    @Published var currentChapterHtml: String = ""
    @Published var currentChapterIndex: Int = 0
    @Published var isLoadingChapter = false

    // MARK: - 高频状态（内部使用，View 不应直接订阅）
    // 使用 _ 前缀标记，View 应使用节流后的版本

    @Published private(set) var _currentPage: Int = 1
    @Published private(set) var _pdfScale: CGFloat = 1.0
    @Published private(set) var _streamingText: String = ""

    // MARK: - 节流状态发布器（View 应订阅这些）

    /// 节流后的页码（120ms 节流，防止快速翻页时过度刷新）
    lazy var throttledPage: PageNumberThrottle = {
        PageNumberThrottle(initialPage: 1, intervalMs: 120)
    }()

    /// 节流后的缩放比例（100ms 节流）
    lazy var throttledScale: ThrottledState<CGFloat> = {
        ThrottledState(initial: 1.0, intervalMs: 100)
    }()

    /// AI 流式输出节流器（80ms 节流）
    lazy var streamingThrottle: StreamingTextThrottle = {
        StreamingTextThrottle(intervalMs: 80)
    }()

    // MARK: - 页码访问器（同时更新内部值和节流值）

    var currentPage: Int {
        get { _currentPage }
        set {
            guard newValue != _currentPage else { return }
            _currentPage = newValue
            throttledPage.updatePage(newValue)
        }
    }

    var pdfScale: CGFloat {
        get { _pdfScale }
        set {
            guard newValue != _pdfScale else { return }
            _pdfScale = newValue
            throttledScale.update(newValue)
        }
    }

    // MARK: - 模式状态

    @Published var readerMode: ReaderMode = .pureReading
    @Published var selectedTab: AITab = .explore  // 默认选中探索Tab
    @Published var showToolbar = true
    @Published var isFullscreen = false  // 全屏模式
    @Published var isUserDragging = false  // 用户正在手势翻页

    // MARK: - 选中状态

    @Published var selection: SelectionType = .none
    @Published var selectionRect: CGRect?

    // MARK: - AI 对话状态

    @Published var messages: [ReaderChatMessage] = []
    @Published var isStreaming = false
    @Published var pendingInput: String = ""
    @Published var pendingImage: UIImage?

    // MARK: - 练习状态

    @Published var practiceQuestions: [PracticeQuestionData] = []
    @Published var isPracticeLoading = false

    // MARK: - 笔记状态

    @Published var currentPageNotes: [ReadingNote] = []
    @Published var isNotesLoading = false

    // MARK: - PDF 搜索状态

    @Published var searchResults: [PDFSearchResult] = []
    @Published var isSearching = false

    // MARK: - 词典查询状态

    @Published var dictionaryWord: String?  // 当前查询的词
    @Published var showDictionaryPanel = false  // 是否显示词典面板

    // MARK: - 标注状态

    @Published var isAnnotationMode = false
    @Published var annotationMode: AnnotationMode = .none
    @Published var annotationColor: CanvasColor = CanvasColor.presets[0]
    @Published var annotationLineWidth: CGFloat = 3.0
    @Published var annotationTool: CanvasTool = .pen
    @Published var annotationAllowsFingerDrawing = true

    // MARK: - 私有属性

    private let downloadManager = DownloadManager.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init(textbook: Textbook) {
        self.textbook = textbook
        // 根据教材类型设置内容类型
        if textbook.isEpub {
            self.contentType = .epub
            self.chapters = textbook.chapters
            // EPUB 与 PDF 一样：竖屏为纯阅读模式，横屏为 AI 辅助模式
            // 初始默认为纯阅读模式，后续由 updateMode 根据屏幕方向调整
            self.readerMode = .pureReading
        } else {
            self.contentType = .pdf
        }
        setupNotifications()
        setupThrottledBindings()
    }

    /// 设置节流绑定
    private func setupThrottledBindings() {
        // 当节流后的页码变化时，触发预加载
        throttledPage.$displayPage
            .removeDuplicates()
            .sink { [weak self] page in
                guard let self = self, let doc = self.pdfDocument else { return }
                // 触发 PDF 缓存预加载
                PDFPageCache.shared.preloadPages(
                    around: page - 1,
                    totalPages: doc.pageCount,
                    size: CGSize(width: 800, height: 1200)
                )
            }
            .store(in: &cancellables)
    }

    private func setupNotifications() {
        // 监听页面跳转通知
        NotificationCenter.default.addObserver(
            forName: .textbookJumpToPage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let page = notification.userInfo?["page"] as? Int {
                Task { @MainActor [weak self] in
                    self?.jumpToPage(page)
                }
            }
        }
    }

    /// 清理资源（在 View 的 onDisappear 中调用）
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        streamingThrottle.reset()
    }

    // MARK: - AI 流式输出控制

    /// 开始 AI 流式输出
    func startStreaming() {
        isStreaming = true
        streamingThrottle.startStream()
    }

    /// 追加流式输出内容（自动节流）
    func appendStreamingChunk(_ chunk: String) {
        streamingThrottle.append(chunk)
    }

    /// 结束 AI 流式输出
    func endStreaming() {
        streamingThrottle.endStream()
        isStreaming = false
    }

    /// 取消 AI 流式输出
    func cancelStreaming() {
        streamingThrottle.reset()
        isStreaming = false
    }

    // MARK: - PDF 加载

    func loadPDF() async {
        isLoading = true
        loadError = nil

        guard let url = textbook.pdfFullURL else {
            loadError = "未找到 PDF 文件"
            isLoading = false
            return
        }

        do {
            let localURL = try await downloadManager.downloadPDF(url: url, textbookId: textbook.id)
            let document = await loadPDFInBackground(url: localURL)

            if let document = document {
                pdfDocument = document
                totalPages = document.pageCount
                isLoading = false
            } else {
                loadError = "PDF 文件格式无效"
                isLoading = false
            }
        } catch {
            loadError = "加载失败: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func loadPDFInBackground(url: URL) async -> PDFDocument? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let document = PDFDocument(url: url)
                continuation.resume(returning: document)
            }
        }
    }

    // MARK: - EPUB 加载

    /// 加载 EPUB（加载第一个章节）
    func loadEPUB() async {
        isLoading = true
        loadError = nil

        // 确保有章节
        guard !chapters.isEmpty else {
            loadError = "EPUB 章节列表为空"
            isLoading = false
            return
        }

        // 加载第一个章节
        let firstChapter = chapters[0]
        await loadChapter(firstChapter.id)

        isLoading = false
    }

    /// 加载指定章节（支持离线缓存）
    func loadChapter(_ chapterId: String) async {
        guard !chapterId.isEmpty else { return }

        isLoadingChapter = true

        // 1. 先检查本地缓存
        if let cachedHtml = CacheService.shared.getCachedEPUBChapter(textbookId: textbook.id, chapterId: chapterId) {
            currentChapterId = chapterId
            currentChapterHtml = cachedHtml
            currentChapterIndex = chapters.firstIndex { $0.id == chapterId } ?? 0
            isLoadingChapter = false
            return
        }

        // 2. 从 API 获取
        do {
            let html = try await fetchChapterContent(chapterId)
            currentChapterId = chapterId
            currentChapterHtml = html
            currentChapterIndex = chapters.firstIndex { $0.id == chapterId } ?? 0

            // 3. 缓存到本地（后台执行，不阻塞UI）
            Task.detached { [textbookId = textbook.id] in
                await MainActor.run {
                    CacheService.shared.cacheEPUBChapter(textbookId: textbookId, chapterId: chapterId, html: html)
                }
            }
        } catch {
            print("加载章节失败: \(error)")
            loadError = "加载章节失败"
        }

        isLoadingChapter = false
    }

    /// 从 API 获取章节内容
    private func fetchChapterContent(_ chapterId: String) async throws -> String {
        let urlString = "\(APIConfig.baseURL)/textbooks/\(textbook.id)/epub/chapter/\(chapterId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 添加认证 token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // 解析响应
        let decoder = JSONDecoder()
        struct ChapterResponse: Decodable {
            let success: Bool?
            let html: String?
            let chapterId: String?
        }

        let result = try decoder.decode(ChapterResponse.self, from: data)
        return result.html ?? ""
    }

    // MARK: - EPUB 章节导航

    /// 当前章节标题
    var currentChapterTitle: String {
        chapters.first { $0.id == currentChapterId }?.title ?? ""
    }

    /// 是否有上一章
    var hasPreviousChapter: Bool {
        currentChapterIndex > 0
    }

    /// 是否有下一章
    var hasNextChapter: Bool {
        currentChapterIndex < chapters.count - 1
    }

    /// 跳转到上一章
    func previousChapter() async {
        guard hasPreviousChapter else { return }
        let prevChapter = chapters[currentChapterIndex - 1]
        await loadChapter(prevChapter.id)
    }

    /// 跳转到下一章
    func nextChapter() async {
        guard hasNextChapter else { return }
        let nextChapter = chapters[currentChapterIndex + 1]
        await loadChapter(nextChapter.id)
    }

    /// 跳转到指定章节
    func goToChapter(_ chapterId: String) async {
        await loadChapter(chapterId)
    }

    // MARK: - 统一内容加载

    /// 根据内容类型加载内容
    func loadContent() async {
        switch contentType {
        case .pdf:
            await loadPDF()
        case .epub:
            await loadEPUB()
        }
    }

    // MARK: - 页面操作

    func jumpToPage(_ page: Int) {
        guard page >= 1, page <= totalPages else { return }
        currentPage = page
    }

    func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
        }
    }

    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
        }
    }

    // MARK: - 截图功能

    /// 截图状态
    @Published var isCapturing = false

    /// 请求区域截图（由 AI 面板触发，AssistModeView 响应）
    @Published var shouldStartRegionCapture = false

    /// 请求区域截图
    func requestRegionCapture() {
        shouldStartRegionCapture = true
    }

    /// 重置区域截图请求
    func clearRegionCaptureRequest() {
        shouldStartRegionCapture = false
    }

    /// 异步截取当前页面（在后台线程渲染，避免阻塞UI）
    func captureCurrentPageAsync() async -> UIImage? {
        guard let document = pdfDocument,
              let page = document.page(at: currentPage - 1) else {
            return nil
        }

        // 设置截图状态
        await MainActor.run { isCapturing = true }
        defer { Task { @MainActor in isCapturing = false } }

        // 在后台线程执行渲染
        // 提前在主线程获取 page 的属性，避免在后台线程访问 PDFPage
        let pageRect = page.bounds(for: .mediaBox)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)

                let image = renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(pageRect)

                    context.cgContext.translateBy(x: 0, y: pageRect.height)
                    context.cgContext.scaleBy(x: 1, y: -1)

                    page.draw(with: .mediaBox, to: context.cgContext)
                }

                continuation.resume(returning: image)
            }
        }
    }

    /// 同步截取当前页面（仅在必要时使用，会阻塞主线程）
    func captureCurrentPage() -> UIImage? {
        guard let document = pdfDocument,
              let page = document.page(at: currentPage - 1) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)

            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1, y: -1)

            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    /// 异步截取区域（在后台线程处理）
    func captureRegionAsync(_ rect: CGRect, from viewSize: CGSize) async -> UIImage? {
        // 设置截图状态
        await MainActor.run { isCapturing = true }
        defer { Task { @MainActor in isCapturing = false } }

        guard let fullImage = await captureCurrentPageAsync() else { return nil }

        // 在后台线程裁剪
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 计算缩放比例
                let scaleX = fullImage.size.width / viewSize.width
                let scaleY = fullImage.size.height / viewSize.height

                let scaledRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: rect.origin.y * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )

                guard let cgImage = fullImage.cgImage?.cropping(to: scaledRect) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    /// 同步截取区域（仅在必要时使用）
    func captureRegion(_ rect: CGRect, from viewSize: CGSize) -> UIImage? {
        guard let fullImage = captureCurrentPage() else { return nil }

        // 计算缩放比例
        let scaleX = fullImage.size.width / viewSize.width
        let scaleY = fullImage.size.height / viewSize.height

        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        guard let cgImage = fullImage.cgImage?.cropping(to: scaledRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - 选中操作

    func selectText(_ text: String, rect: CGRect) {
        selection = .text(text)
        selectionRect = rect
    }

    func selectRegion(_ image: UIImage) {
        selection = .region(image)
        pendingImage = image
    }

    func selectPage() {
        if let image = captureCurrentPage() {
            selection = .page
            pendingImage = image
        }
    }

    func clearSelection() {
        selection = .none
        selectionRect = nil
    }

    // MARK: - 语音朗读

    func speak(_ text: String) {
        // 停止当前朗读
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // 优先使用增强版中文语音（类似 Siri）
        if let enhancedVoice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.zh-CN.Tingting") {
            utterance.voice = enhancedVoice
        } else if let premiumVoice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.zh-CN.Tingting") {
            utterance.voice = premiumVoice
        } else if let compactVoice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Ting-Ting-compact") {
            utterance.voice = compactVoice
        } else {
            // 回退到默认中文语音
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        }

        // 调整语速和音调，使朗读更自然
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9  // 稍慢于默认速度
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        speechSynthesizer.speak(utterance)
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - PDF 全文搜索

    /// 在PDF中搜索文本
    func searchPDF(_ query: String) async {
        guard !query.isEmpty, let document = pdfDocument else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = []

        // 在后台线程执行搜索
        let results = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var foundResults: [PDFSearchResult] = []

                // 使用 PDFDocument 的 findString 方法
                let selections = document.findString(query, withOptions: .caseInsensitive)

                for selection in selections {
                    guard let page = selection.pages.first else { continue }
                    let pageIndex = document.index(for: page)

                    // 获取匹配文本
                    let matchText = selection.string ?? query

                    // 获取上下文文本（扩展选区获取更多内容）
                    var contextText = matchText
                    if let extendedSelection = selection.copy() as? PDFSelection {
                        extendedSelection.extend(atStart: 30)
                        extendedSelection.extend(atEnd: 30)
                        if let extended = extendedSelection.string {
                            // 清理并格式化上下文
                            contextText = extended
                                .replacingOccurrences(of: "\n", with: " ")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }

                    let result = PDFSearchResult(
                        pageNumber: pageIndex + 1,
                        matchText: matchText,
                        contextText: contextText,
                        selection: selection
                    )
                    foundResults.append(result)
                }

                continuation.resume(returning: foundResults)
            }
        }

        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }

    /// 清除搜索结果
    func clearSearch() {
        searchResults = []
    }

    // MARK: - 词典查询

    /// 判断是否为单个词（用于决定是否显示词典面板）
    func isWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 简单判断：不包含空格且长度小于15个字符
        return !trimmed.contains(" ") && trimmed.count <= 15 && trimmed.count >= 1
    }

    /// 设置词典查询词
    func setDictionaryWord(_ word: String) {
        if isWord(word) {
            dictionaryWord = word
            showDictionaryPanel = true
        } else {
            clearDictionaryWord()
        }
    }

    /// 清除词典查询
    func clearDictionaryWord() {
        dictionaryWord = nil
        showDictionaryPanel = false
    }

    // MARK: - 模式切换

    func updateMode(for size: CGSize) {
        // EPUB 和 PDF 都根据屏幕方向切换模式：竖屏纯阅读，横屏 AI 辅助
        let newMode: ReaderMode = size.width > size.height ? .aiAssist : .pureReading
        if readerMode != newMode {
            withAnimation(.easeInOut(duration: 0.3)) {
                readerMode = newMode
            }
        }
    }

    // MARK: - 批注模式控制（最小化实现）

    /// 进入批注模式
    /// 关键：只设置一个状态，不触发额外更新
    func enterAnnotationMode() {
        isAnnotationMode = true
    }

    /// 退出批注模式
    func exitAnnotationMode() {
        isAnnotationMode = false
    }

    /// 切换批注模式
    func toggleAnnotationMode() {
        isAnnotationMode.toggle()
    }
}

// MARK: - PDF 搜索结果模型

struct PDFSearchResult: Identifiable {
    let id = UUID()
    let pageNumber: Int      // 页码（1-based）
    let matchText: String    // 匹配的文本
    let contextText: String  // 上下文文本
    let selection: PDFSelection?

    /// 高亮显示匹配文本
    func highlightedContext(query: String) -> AttributedString {
        var result = AttributedString(contextText)
        if let range = result.range(of: query, options: .caseInsensitive) {
            result[range].foregroundColor = .orange
            result[range].font = .boldSystemFont(ofSize: 14)
        }
        return result
    }
}

// MARK: - 聊天消息模型

struct ReaderChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    var image: UIImage?
    let timestamp = Date()
    var tab: AITab  // 关联的Tab

    enum MessageRole: Equatable {
        case user
        case assistant
    }

    static func == (lhs: ReaderChatMessage, rhs: ReaderChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 横屏布局管理器

@MainActor
final class ReaderLayoutManager: ObservableObject {
    @Published var splitRatio: CGFloat = 0.55
    @Published var isPanelVisible: Bool = true
    @Published var isPanelMinimized: Bool = false

    // 预设布局
    enum LayoutPreset: String, CaseIterable {
        case reading = "阅读为主"      // 70% PDF
        case balanced = "均衡"         // 55% PDF
        case assistant = "助手为主"    // 40% PDF

        var ratio: CGFloat {
            switch self {
            case .reading: return 0.7
            case .balanced: return 0.55
            case .assistant: return 0.4
            }
        }
    }

    func applyPreset(_ preset: LayoutPreset) {
        withAnimation(.easeInOut(duration: 0.3)) {
            splitRatio = preset.ratio
            isPanelVisible = true
            isPanelMinimized = false
        }
    }

    func togglePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if isPanelMinimized {
                isPanelMinimized = false
                isPanelVisible = true
            } else if isPanelVisible {
                isPanelMinimized = true
            } else {
                isPanelVisible = true
            }
        }
    }

    func minimizePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPanelMinimized = true
        }
    }

    func expandPanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPanelMinimized = false
            isPanelVisible = true
        }
    }
}

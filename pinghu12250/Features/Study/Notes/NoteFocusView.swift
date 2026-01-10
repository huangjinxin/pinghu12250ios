//
//  NoteFocusView.swift
//  pinghu12250
//
//  笔记专注模式 - 沉浸式阅读和编辑笔记
//

import SwiftUI
import Combine
import WebKit

// MARK: - 专注模式视图

struct NoteFocusView: View {
    let note: ReadingNote
    @Environment(\.dismiss) var dismiss
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var showTextbookReader = false
    @State private var fontSize: CGFloat = 18
    @State private var showControls = true

    // 阅读进度
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()

            // 主内容
            VStack(spacing: 0) {
                // 顶部导航栏
                if showControls {
                    focusNavigationBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 笔记内容区域（根据类型渲染）
                noteContentArea

                // 底部工具栏
                if showControls {
                    focusBottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onAppear {
            // 编辑时使用纯文本
            editedContent = HTMLHelper.stripHTML(note.contentString ?? "")
        }
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

    // MARK: - 笔记内容区域（根据类型渲染）

    private var noteContentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 类型标签
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: note.typeIcon)
                        Text(note.typeLabel)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(note.typeColor)
                    .cornerRadius(16)

                    Spacer()

                    if let page = note.page {
                        Text("P\(page)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                // 根据笔记类型渲染不同内容
                switch note.sourceType {
                case "dict":
                    dictFocusContent
                case "practice", "exercise":
                    practiceFocusContent
                case "solving":
                    solvingFocusContent
                default:
                    defaultFocusContent
                }

                // 来源教材
                if let textbook = note.textbook {
                    textbookSourceSection(textbook)
                }

                // 时间戳
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(note.createdAt?.relativeDescription ?? "")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 16)
            }
            .padding(24)
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                }
        )
    }

    // MARK: - 查字典专注内容

    private var dictFocusContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 查询的字（大字居中显示）
            if let query = note.query, !query.isEmpty {
                HStack {
                    Spacer()
                    Text(query)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 120, height: 120)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)
                    Spacer()
                }
            }

            // 字典详情
            if let content = note.contentString, !content.isEmpty {
                let dictInfo = parseDictContent(content)

                VStack(alignment: .leading, spacing: 16) {
                    if let pinyin = dictInfo.pinyin {
                        HStack(spacing: 12) {
                            Text("拼音")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(pinyin)
                                .font(.title2)
                                .foregroundColor(.appPrimary)
                        }
                        Divider()
                    }

                    if let radical = dictInfo.radical {
                        HStack(spacing: 12) {
                            Text("部首")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(radical)
                                .font(.title3)
                        }
                        Divider()
                    }

                    if let strokes = dictInfo.strokes {
                        HStack(spacing: 12) {
                            Text("笔画")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text("\(strokes) 画")
                                .font(.title3)
                        }
                        Divider()
                    }

                    if !dictInfo.definitions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("释义")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(Array(dictInfo.definitions.enumerated()), id: \.offset) { index, def in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .font(.system(size: fontSize))
                                        .foregroundColor(.appPrimary)
                                        .frame(width: 24, alignment: .trailing)
                                    SelectableText(
                                        text: def,
                                        font: .systemFont(ofSize: fontSize),
                                        textColor: .label
                                    )
                                }
                            }
                        }
                    }

                    // 原始内容（如果没有解析出结构化数据）
                    if dictInfo.pinyin == nil && dictInfo.definitions.isEmpty {
                        SelectableText(
                            text: content,
                            font: .systemFont(ofSize: fontSize),
                            textColor: .label
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
    }

    // MARK: - 练习题专注内容（可交互 WebView）

    private var practiceFocusContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            if let query = note.query, !query.isEmpty {
                Text(query)
                    .font(.system(size: fontSize + 2, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // 使用可交互 WebView 渲染练习题
            if let content = note.contentString, !content.isEmpty {
                FocusInteractivePracticeView(jsonContent: content, fontSize: fontSize)
                    .frame(minHeight: 400)
                    .cornerRadius(16)
            } else if let snippet = note.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: fontSize))
                    .foregroundColor(.primary)
                    .lineSpacing(8)
            }
        }
    }

    // MARK: - 解析练习题 JSON

    private func parsePracticeQuestion(_ content: String) -> FocusPracticeQuestion {
        guard let data = content.data(using: .utf8) else {
            return FocusPracticeQuestion(stem: content, options: [], answer: "", type: "text")
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 直接是 question 对象
                if let stem = json["stem"] as? String {
                    return parseQuestionJSON(json)
                }
                // 嵌套在 question 字段中
                if let questionDict = json["question"] as? [String: Any] {
                    return parseQuestionJSON(questionDict)
                }
            }
        } catch {
            // 不是 JSON，返回原始内容
        }

        return FocusPracticeQuestion(stem: content, options: [], answer: "", type: "text")
    }

    private func parseQuestionJSON(_ json: [String: Any]) -> FocusPracticeQuestion {
        let stem = json["stem"] as? String ?? ""
        let answer = json["answer"] as? String ?? ""
        let type = json["type"] as? String ?? "choice"

        var options: [FocusPracticeOption] = []
        if let optionsArray = json["options"] as? [[String: Any]] {
            for opt in optionsArray {
                let value = opt["value"] as? String ?? ""
                let text = opt["text"] as? String ?? ""
                options.append(FocusPracticeOption(value: value, text: text))
            }
        }

        return FocusPracticeQuestion(stem: stem, options: options, answer: answer, type: type)
    }

    // MARK: - 解题专注内容（解析 JSON 渲染）

    private var solvingFocusContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            if let query = note.query, !query.isEmpty {
                Text(query)
                    .font(.system(size: fontSize + 2, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // 解析 JSON 内容渲染
            if let content = note.contentString, !content.isEmpty {
                let question = parsePracticeQuestion(content)

                // 如果解析出题目
                if !question.stem.isEmpty {
                    // 题目
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.cyan)
                            Text("解题")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        Text(question.stem)
                            .font(.system(size: fontSize))
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cyan.opacity(0.08))
                    .cornerRadius(16)

                    // 选项
                    if !question.options.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(question.options, id: \.value) { option in
                                HStack(alignment: .top, spacing: 14) {
                                    Text(option.value)
                                        .font(.system(size: fontSize, weight: .bold))
                                        .foregroundColor(.cyan)
                                        .frame(width: 28)
                                    Text(option.text)
                                        .font(.system(size: fontSize))
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    option.value == question.answer ?
                                        Color.green.opacity(0.15) : Color(.systemGray6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(option.value == question.answer ? Color.green : Color.clear, lineWidth: 3)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }

                    // 答案
                    if !question.answer.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("答案: \(question.answer)")
                                .font(.system(size: fontSize, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                    }
                } else {
                    // 非 JSON 内容，使用富文本显示
                    RichContentView(text: content, fontSize: fontSize)
                }
            }
        }
    }

    // MARK: - 默认专注内容

    private var defaultFocusContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 查询/标题
            if let query = note.query, !query.isEmpty {
                Text(query)
                    .font(.system(size: fontSize + 4, weight: .bold))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            }

            // 摘录内容
            if let snippet = note.snippet, !snippet.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("摘录")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SelectableText(
                        text: snippet,
                        font: .systemFont(ofSize: fontSize),
                        textColor: .label
                    )
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        Rectangle()
                            .fill(note.typeColor)
                            .frame(width: 4)
                            .cornerRadius(2),
                        alignment: .leading
                    )
                }
            }

            // 详细内容
            if let content = note.contentString, !content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("详细内容")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isEditing {
                        TextEditor(text: $editedContent)
                            .font(.system(size: fontSize))
                            .lineSpacing(8)
                            .frame(minHeight: 200)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        SelectableMarkdownView(content: HTMLHelper.convertToReadableText(content), fontSize: fontSize, lineSpacing: 8)
                    }
                }
            }
        }
    }

    // MARK: - 来源教材区块

    private func textbookSourceSection(_ textbook: Textbook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("来源教材")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                showTextbookReader = true
            } label: {
                HStack {
                    // 教材图标
                    RoundedRectangle(cornerRadius: 6)
                        .fill(textbook.subjectColor.opacity(0.2))
                        .frame(width: 40, height: 50)
                        .overlay(
                            Text(textbook.subjectIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(textbook.subjectColor)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(textbook.displayTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(textbook.gradeName) · \(textbook.semester)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.appPrimary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 解析字典内容

    private func parseDictContent(_ content: String) -> (pinyin: String?, radical: String?, strokes: Int?, definitions: [String]) {
        // 尝试解析 JSON 格式
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let pinyin = json["pinyin"] as? String
            let radical = json["radical"] as? String
            let strokes = json["strokes"] as? Int
            let definitions = json["definitions"] as? [String] ?? []
            return (pinyin, radical, strokes, definitions)
        }

        // 尝试从文本中提取
        var definitions: [String] = []
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            definitions.append(line)
        }

        return (nil, nil, nil, definitions)
    }

    // MARK: - 顶部导航栏

    private var focusNavigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            Spacer()

            Text("专注阅读")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // 编辑按钮（仅对非 HTML 类型显示）
            if !["practice", "exercise", "solving"].contains(note.sourceType) {
                Button {
                    withAnimation {
                        isEditing.toggle()
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isEditing ? .white : .primary)
                        .frame(width: 36, height: 36)
                        .background(isEditing ? Color.appPrimary : Color(.systemGray6))
                        .clipShape(Circle())
                }
            } else {
                // 占位，保持布局对称
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - 底部工具栏

    private var focusBottomToolbar: some View {
        HStack(spacing: 24) {
            // 字体大小调节
            HStack(spacing: 12) {
                Button {
                    if fontSize > 14 {
                        fontSize -= 2
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 18))
                        .foregroundColor(fontSize <= 14 ? .secondary : .primary)
                }
                .disabled(fontSize <= 14)

                Text("\(Int(fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                Button {
                    if fontSize < 28 {
                        fontSize += 2
                    }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 18))
                        .foregroundColor(fontSize >= 28 ? .secondary : .primary)
                }
                .disabled(fontSize >= 28)
            }

            Divider()
                .frame(height: 24)

            // 分享
            Button {
                shareNote()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }

            // 收藏
            Button {
                // 收藏笔记
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }

            Spacer()

            // 跳转教材
            if note.textbook != nil {
                Button {
                    showTextbookReader = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                        Text("查看教材")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appPrimary)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
                .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
        )
    }

    // MARK: - 分享功能

    private func shareNote() {
        var shareText = ""
        if let query = note.query, !query.isEmpty {
            shareText += "\(query)\n\n"
        }
        if let snippet = note.snippet, !snippet.isEmpty {
            shareText += "\(snippet)\n\n"
        }
        if let content = note.contentString, !content.isEmpty {
            shareText += "\(content)\n\n"
        }
        shareText += "—— 来自苹湖少儿空间"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - 专注模式练习题数据结构

struct FocusPracticeQuestion {
    let stem: String
    let options: [FocusPracticeOption]
    let answer: String
    let type: String
}

struct FocusPracticeOption {
    let value: String
    let text: String
}

// MARK: - 专注模式 HTML 渲染视图

struct FocusPracticeHTMLView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = wrapHTMLWithStyle(htmlContent)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    private func wrapHTMLWithStyle(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 17px;
                    line-height: 1.7;
                    color: #1a1a1a;
                    background: #f5f5f5;
                    margin: 0;
                    padding: 16px;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e5e5e5; background: #1c1c1e; }
                    .question-card { background: #2c2c2e !important; border-color: #3a3a3c !important; }
                    input, textarea { background: #1c1c1e !important; color: #e5e5e5 !important; }
                }
                .question-card {
                    background: white;
                    border: 1px solid #e0e0e0;
                    border-radius: 16px;
                    padding: 20px;
                    margin-bottom: 16px;
                }
                .options { display: flex; flex-direction: column; gap: 12px; }
                .option {
                    display: flex;
                    align-items: center;
                    padding: 14px 18px;
                    background: #f8f9fa;
                    border: 2px solid #e0e0e0;
                    border-radius: 12px;
                    transition: all 0.2s;
                }
                .option.selected { border-color: #7c3aed; background: #ede9fe; }
                .option.correct { border-color: #10b981; background: #d1fae5; }
                .option.wrong { border-color: #ef4444; background: #fee2e2; }
                .option-label { font-weight: 600; margin-right: 14px; color: #6366f1; }
                .blank-input {
                    min-width: 100px;
                    padding: 6px 14px;
                    border: none;
                    border-bottom: 2px solid #7c3aed;
                    background: transparent;
                    font-size: 17px;
                    text-align: center;
                }
                .answer-box {
                    background: #f0fdf4;
                    border-left: 4px solid #10b981;
                    padding: 14px 18px;
                    margin-top: 16px;
                    border-radius: 0 12px 12px 0;
                }
                .explanation-box {
                    background: #eff6ff;
                    border-left: 4px solid #3b82f6;
                    padding: 14px 18px;
                    margin-top: 12px;
                    border-radius: 0 12px 12px 0;
                }
                .btn {
                    display: inline-block;
                    padding: 12px 24px;
                    border: none;
                    border-radius: 10px;
                    font-size: 15px;
                    font-weight: 600;
                    cursor: pointer;
                }
                .btn-primary { background: #7c3aed; color: white; }
            </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

// MARK: - 专注模式可交互练习题视图

struct FocusInteractivePracticeView: UIViewRepresentable {
    let jsonContent: String
    let fontSize: CGFloat

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
                return wrapWithStyle(json)
            }
            return wrapWithStyle("<p>\(json)</p>")
        }

        // 提取题目数据
        var questionData: [String: Any] = [:]
        if let question = parsed["question"] as? [String: Any] {
            questionData = question
        } else if parsed["stem"] != nil {
            questionData = parsed
        } else {
            return wrapWithStyle("<p>\(json)</p>")
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

        // 答案区
        html += """
        <div id="answerBox" class="answer-box hidden">
            <div class="answer-label">正确答案</div>
            <div class="answer-content">\(answer)</div>
        </div>
        """

        // 解析区
        if !explanation.isEmpty {
            html += """
            <div id="explanationBox" class="explanation-box hidden">
                <div class="explanation-label">解析</div>
                <div class="explanation-content">\(explanation)</div>
            </div>
            """
        }

        html += "</div>"
        return wrapWithStyle(html)
    }

    private func wrapWithStyle(_ content: String) -> String {
        let size = Int(fontSize)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: \(size)px;
                    line-height: 1.7;
                    color: #1a1a1a;
                    background: #f5f5f5;
                    margin: 0;
                    padding: 20px;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e5e5e5; background: #1c1c1e; }
                    .question-card { background: #2c2c2e !important; }
                    .option { background: #3a3a3c !important; border-color: #4a4a4c !important; }
                    .blank-input { color: #e5e5e5 !important; background: #2c2c2e !important; }
                    .answer-box { background: #1a2e1a !important; }
                    .explanation-box { background: #1a1a2e !important; }
                }
                .question-card {
                    background: white;
                    border-radius: 20px;
                    padding: 24px;
                }
                .question-stem {
                    font-size: \(size + 1)px;
                    font-weight: 500;
                    margin-bottom: 24px;
                    line-height: 1.8;
                }
                .options { display: flex; flex-direction: column; gap: 14px; margin-bottom: 24px; }
                .option {
                    display: flex;
                    align-items: center;
                    padding: 16px 20px;
                    background: #f8f9fa;
                    border: 3px solid #e0e0e0;
                    border-radius: 14px;
                    cursor: pointer;
                    transition: all 0.2s;
                }
                .option:hover { border-color: #7c3aed; background: #f5f3ff; }
                .option.selected { border-color: #7c3aed; background: #ede9fe; }
                .option.correct { border-color: #10b981 !important; background: #d1fae5 !important; }
                .option.wrong { border-color: #ef4444 !important; background: #fee2e2 !important; }
                .option-label {
                    font-weight: 700;
                    margin-right: 16px;
                    color: #7c3aed;
                    min-width: 32px;
                    font-size: \(size + 2)px;
                }
                .option-text { flex: 1; font-size: \(size)px; }
                .fill-area { margin-bottom: 24px; }
                .blank-input {
                    width: 100%;
                    padding: 16px 20px;
                    border: 3px solid #e0e0e0;
                    border-radius: 14px;
                    font-size: \(size)px;
                    outline: none;
                }
                .blank-input:focus { border-color: #7c3aed; }
                .blank-input.correct { border-color: #10b981; background: #d1fae5; }
                .blank-input.wrong { border-color: #ef4444; background: #fee2e2; }
                .actions { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 20px; }
                .btn {
                    padding: 14px 24px;
                    border: none;
                    border-radius: 12px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                }
                .btn-primary { background: #7c3aed; color: white; }
                .btn-secondary { background: #e5e7eb; color: #374151; }
                .result-box {
                    padding: 16px 20px;
                    border-radius: 14px;
                    margin-bottom: 14px;
                    font-weight: 600;
                    font-size: \(size)px;
                }
                .result-box.correct { background: #d1fae5; color: #065f46; }
                .result-box.wrong { background: #fee2e2; color: #991b1b; }
                .answer-box {
                    background: #f0fdf4;
                    border-left: 5px solid #10b981;
                    padding: 16px 20px;
                    margin-bottom: 14px;
                    border-radius: 0 14px 14px 0;
                }
                .answer-label { font-weight: 700; color: #10b981; margin-bottom: 8px; }
                .explanation-box {
                    background: #eff6ff;
                    border-left: 5px solid #3b82f6;
                    padding: 16px 20px;
                    border-radius: 0 14px 14px 0;
                }
                .explanation-label { font-weight: 700; color: #3b82f6; margin-bottom: 8px; }
                .hidden { display: none; }
            </style>
        </head>
        <body>
            \(content)
            <script>
                var selectedOption = null;
                var isChecked = false;

                function selectOption(el, value) {
                    if (isChecked) return;
                    document.querySelectorAll('.option').forEach(opt => opt.classList.remove('selected'));
                    el.classList.add('selected');
                    selectedOption = value;
                }

                function checkAnswer(answer) {
                    var resultBox = document.getElementById('result');
                    var answerBox = document.getElementById('answerBox');
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

                    if (!selectedOption) {
                        resultBox.className = 'result-box wrong';
                        resultBox.textContent = '请先选择一个答案';
                        resultBox.classList.remove('hidden');
                        return;
                    }

                    isChecked = true;
                    document.querySelectorAll('.option').forEach(opt => {
                        var val = opt.getAttribute('data-value');
                        if (val === answer) opt.classList.add('correct');
                        else if (val === selectedOption) opt.classList.add('wrong');
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

// MARK: - 预览

#Preview {
    NoteFocusView(
        note: ReadingNote(
            id: "preview",
            type: "ai_analysis",
            content: "光合作用是植物利用阳光、水和二氧化碳制造食物的过程。",
            snippet: "绿色植物通过光合作用，把二氧化碳和水合成有机物。",
            page: 42,
            createdAt: Date()
        )
    )
}

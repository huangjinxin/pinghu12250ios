//
//  SelectableMarkdownView.swift
//  pinghu12250
//
//  可选择的 Markdown 渲染视图
//  使用 UITextView 实现系统级文本选择和朗读
//  温暖米色主题，阅读友好
//

import SwiftUI
import UIKit

/// 可选择的 Markdown 视图
/// 使用 UITextView 实现，支持系统级文本选择和朗读
struct SelectableMarkdownView: UIViewRepresentable {
    let content: String
    var fontSize: CGFloat = 16
    var lineSpacing: CGFloat = 10
    var theme: MarkdownTheme = .warm

    enum MarkdownTheme {
        case warm      // 温暖米色
        case light     // 简洁白底
        case dark      // 深色模式

        var backgroundColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)  // 米色
            case .light: return .systemBackground
            case .dark: return UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
            }
        }

        var textColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1.0)  // 深棕色
            case .light: return .label
            case .dark: return UIColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1.0)
            }
        }

        var secondaryColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.5, green: 0.45, blue: 0.38, alpha: 1.0)
            case .light: return .secondaryLabel
            case .dark: return UIColor(red: 0.6, green: 0.6, blue: 0.58, alpha: 1.0)
            }
        }

        var accentColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.76, green: 0.49, blue: 0.32, alpha: 1.0)  // 暖橙色
            case .light: return .systemBlue
            case .dark: return UIColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1.0)
            }
        }

        var headingColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.55, green: 0.35, blue: 0.22, alpha: 1.0)  // 棕色
            case .light: return .label
            case .dark: return UIColor(red: 0.95, green: 0.95, blue: 0.93, alpha: 1.0)
            }
        }

        var quoteBackground: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1.0)
            case .light: return UIColor.systemGray6
            case .dark: return UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
            }
        }

        var dividerColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 1.0)
            case .light: return .separator
            case .dark: return UIColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0)
            }
        }
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // 核心配置：可选择但不可编辑
        textView.isEditable = false
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true

        // 布局配置
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = theme.backgroundColor

        // 圆角
        textView.layer.cornerRadius = 16
        textView.clipsToBounds = true

        // 自动布局优先级
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        // 禁用数据检测和链接
        textView.dataDetectorTypes = []
        textView.linkTextAttributes = [:]

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = parseMarkdown(content)
        textView.backgroundColor = theme.backgroundColor
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    // MARK: - Markdown 解析

    private func parseMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = lineSpacing * 0.8

        let bodyFont = UIFont.systemFont(ofSize: fontSize)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 空行
            if trimmed.isEmpty {
                if index > 0 {
                    result.append(NSAttributedString(string: "\n", attributes: [
                        .font: UIFont.systemFont(ofSize: fontSize * 0.5)
                    ]))
                }
                continue
            }

            // 分隔线
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let dividerStyle = NSMutableParagraphStyle()
                dividerStyle.alignment = .center
                dividerStyle.paragraphSpacing = lineSpacing

                let divider = NSAttributedString(string: "· · · · · · · · · · · · · · ·\n", attributes: [
                    .foregroundColor: theme.dividerColor,
                    .font: UIFont.systemFont(ofSize: 12),
                    .paragraphStyle: dividerStyle
                ])
                result.append(divider)
                continue
            }

            // 标题
            if let (level, headingText) = parseHeading(trimmed) {
                appendHeading(to: result, text: headingText, level: level)
                continue
            }

            // 引用
            if trimmed.hasPrefix(">") {
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                appendQuote(to: result, text: quoteText)
                continue
            }

            // 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let itemText = String(trimmed.dropFirst(2))
                appendListItem(to: result, text: itemText, ordered: false, number: 0)
                continue
            }

            // 有序列表
            if let match = trimmed.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                let numberStr = trimmed[trimmed.startIndex..<match.lowerBound]
                let itemText = String(trimmed[match.upperBound...])
                let number = Int(String(trimmed[..<match.upperBound]).replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                appendListItem(to: result, text: itemText, ordered: true, number: number)
                continue
            }

            // 普通段落
            appendParagraph(to: result, text: trimmed)
        }

        return result
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        if line.hasPrefix("#### ") {
            return (4, String(line.dropFirst(5)))
        } else if line.hasPrefix("### ") {
            return (3, String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return (2, String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return (1, String(line.dropFirst(2)))
        }
        return nil
    }

    private func appendHeading(to result: NSMutableAttributedString, text: String, level: Int) {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = level == 1 ? 8 : 16
        headingStyle.paragraphSpacing = 8
        headingStyle.lineSpacing = 4

        let headingFont: UIFont
        switch level {
        case 1:
            headingFont = UIFont.systemFont(ofSize: fontSize + 8, weight: .bold)
        case 2:
            headingFont = UIFont.systemFont(ofSize: fontSize + 5, weight: .semibold)
        case 3:
            headingFont = UIFont.systemFont(ofSize: fontSize + 3, weight: .semibold)
        default:
            headingFont = UIFont.systemFont(ofSize: fontSize + 1, weight: .medium)
        }

        let parsed = parseInlineMarkdown(text, baseFont: headingFont, baseColor: theme.headingColor)
        let mutableParsed = NSMutableAttributedString(attributedString: parsed)
        mutableParsed.addAttribute(.paragraphStyle, value: headingStyle, range: NSRange(location: 0, length: mutableParsed.length))

        result.append(mutableParsed)
        result.append(NSAttributedString(string: "\n"))

        // 一级标题下加装饰线
        if level == 1 {
            let underlineStyle = NSMutableParagraphStyle()
            underlineStyle.paragraphSpacing = 12
            result.append(NSAttributedString(string: "━━━━━━━━━━\n", attributes: [
                .foregroundColor: theme.accentColor,
                .font: UIFont.systemFont(ofSize: 8),
                .paragraphStyle: underlineStyle
            ]))
        }
    }

    private func appendQuote(to result: NSMutableAttributedString, text: String) {
        let quoteStyle = NSMutableParagraphStyle()
        quoteStyle.lineSpacing = lineSpacing * 0.8
        quoteStyle.paragraphSpacing = lineSpacing
        quoteStyle.firstLineHeadIndent = 16
        quoteStyle.headIndent = 16
        quoteStyle.tailIndent = -8

        // 引用符号
        result.append(NSAttributedString(string: "┃ ", attributes: [
            .foregroundColor: theme.accentColor,
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium)
        ]))

        // 引用内容
        let parsed = parseInlineMarkdown(text, baseFont: UIFont.italicSystemFont(ofSize: fontSize), baseColor: theme.secondaryColor)
        result.append(parsed)
        result.append(NSAttributedString(string: "\n\n"))
    }

    private func appendListItem(to result: NSMutableAttributedString, text: String, ordered: Bool, number: Int) {
        let listStyle = NSMutableParagraphStyle()
        listStyle.lineSpacing = lineSpacing * 0.6
        listStyle.paragraphSpacing = lineSpacing * 0.5
        listStyle.firstLineHeadIndent = 8
        listStyle.headIndent = 28

        // 列表符号
        if ordered {
            result.append(NSAttributedString(string: "  \(number). ", attributes: [
                .foregroundColor: theme.accentColor,
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .paragraphStyle: listStyle
            ]))
        } else {
            result.append(NSAttributedString(string: "  ● ", attributes: [
                .foregroundColor: theme.accentColor,
                .font: UIFont.systemFont(ofSize: fontSize * 0.7),
                .paragraphStyle: listStyle
            ]))
        }

        // 列表内容
        let parsed = parseInlineMarkdown(text, baseFont: UIFont.systemFont(ofSize: fontSize), baseColor: theme.textColor)
        result.append(parsed)
        result.append(NSAttributedString(string: "\n"))
    }

    private func appendParagraph(to result: NSMutableAttributedString, text: String) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = lineSpacing
        paraStyle.paragraphSpacing = lineSpacing * 0.8
        paraStyle.firstLineHeadIndent = 0

        let parsed = parseInlineMarkdown(text, baseFont: UIFont.systemFont(ofSize: fontSize), baseColor: theme.textColor)
        let mutableParsed = NSMutableAttributedString(attributedString: parsed)
        mutableParsed.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: mutableParsed.length))

        result.append(mutableParsed)
        result.append(NSAttributedString(string: "\n"))
    }

    private func parseInlineMarkdown(_ text: String, baseFont: UIFont, baseColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: baseColor
        ])

        // 粗体 **text** 或 __text__
        let boldPatterns = [#"\*\*(.+?)\*\*"#, #"__(.+?)__"#]
        for pattern in boldPatterns {
            applyPattern(pattern, to: result, transform: { range, _ in
                result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFont.pointSize), range: range)
            })
        }

        // 斜体 *text* 或 _text_
        let italicPatterns = [#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#]
        for pattern in italicPatterns {
            applyPattern(pattern, to: result, transform: { range, _ in
                result.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: baseFont.pointSize), range: range)
            })
        }

        // 行内代码 `code`
        applyPattern(#"`(.+?)`"#, to: result) { range, matchedText in
            result.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular), range: range)
            result.addAttribute(.backgroundColor, value: theme.quoteBackground, range: range)
        }

        return result
    }

    private func applyPattern(_ pattern: String, to attributedString: NSMutableAttributedString, transform: (NSRange, String) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let string = attributedString.string
        let nsRange = NSRange(string.startIndex..., in: string)
        let matches = regex.matches(in: string, range: nsRange)

        // 从后往前处理，避免范围偏移
        for match in matches.reversed() {
            guard let range = Range(match.range, in: string),
                  let groupRange = Range(match.range(at: 1), in: string) else { continue }

            let matchedText = String(string[groupRange])
            let fullMatchRange = match.range

            // 替换为不含标记的文本
            attributedString.replaceCharacters(in: fullMatchRange, with: matchedText)

            // 应用样式到新范围
            let newRange = NSRange(location: fullMatchRange.location, length: matchedText.count)
            transform(newRange, matchedText)
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SelectableMarkdownView(content: """
            # AI 日记分析

            ## 整体印象

            这是一篇充满童真的日记，小朋友用简单的语言记录了一天的生活，字里行间洋溢着快乐的情绪。

            ## 亮点

            - 观察力强，注意到了很多生活细节
            - 表达清晰，语句通顺流畅
            - 情感真挚，能感受到满满的快乐

            ## 建议

            1. 可以增加更多的感受描写
            2. 尝试使用一些比喻句让文章更生动
            3. 注意标点符号的正确使用

            > 总的来说，这是一篇很棒的日记！继续保持这份对生活的热爱！

            ---

            **整体评分：优秀** ⭐⭐⭐⭐⭐
            """, theme: .warm)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

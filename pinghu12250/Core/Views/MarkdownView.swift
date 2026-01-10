//
//  MarkdownView.swift
//  pinghu12250
//
//  简单的Markdown渲染视图
//

import SwiftUI

struct MarkdownView: View {
    let content: String
    var fontSize: CGFloat = 15
    var lineSpacing: CGFloat = 8
    var selectable: Bool = true  // 默认支持文本选择

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .textSelection(.enabled)  // 始终启用文本选择
    }

    // MARK: - Block Types

    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case listItem(text: String, ordered: Bool, number: Int?)
        case blockquote(text: String)
        case divider
        case empty
    }

    // MARK: - Parsing

    private func parseBlocks() -> [Block] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [Block] = []
        var listNumber = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                blocks.append(.empty)
                listNumber = 0
                continue
            }

            // 分隔线
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                continue
            }

            // 标题
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                continue
            }

            // 引用
            if trimmed.hasPrefix(">") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.blockquote(text: text))
                continue
            }

            // 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(.listItem(text: text, ordered: false, number: nil))
                continue
            }

            // 有序列表
            if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let text = String(trimmed[match.upperBound...])
                listNumber += 1
                blocks.append(.listItem(text: text, ordered: true, number: listNumber))
                continue
            }

            // 普通段落
            blocks.append(.paragraph(text: trimmed))
            listNumber = 0
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> Block? {
        if line.hasPrefix("#### ") {
            return .heading(level: 4, text: String(line.dropFirst(5)))
        } else if line.hasPrefix("### ") {
            return .heading(level: 3, text: String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return .heading(level: 2, text: String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return .heading(level: 1, text: String(line.dropFirst(2)))
        }
        return nil
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            renderParagraph(text: text)
        case .listItem(let text, let ordered, let number):
            renderListItem(text: text, ordered: ordered, number: number)
        case .blockquote(let text):
            renderBlockquote(text: text)
        case .divider:
            Divider()
                .padding(.vertical, 8)
        case .empty:
            Spacer()
                .frame(height: 4)
        }
    }

    private func renderHeading(level: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(parseInlineMarkdown(text))
                .font(headingFont(level: level))
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if level == 1 {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 2)
            }
        }
        .padding(.top, level == 1 ? 16 : 12)
        .padding(.bottom, 4)
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }

    private func renderParagraph(text: String) -> some View {
        Text(parseInlineMarkdown(text))
            .font(.system(size: fontSize))
            .foregroundColor(.primary.opacity(0.85))
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func renderListItem(text: String, ordered: Bool, number: Int?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if ordered, let num = number {
                Text("\(num).")
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("•")
                    .font(.system(size: fontSize + 2))
                    .foregroundColor(.appPrimary)
                    .frame(width: 16)
            }

            Text(parseInlineMarkdown(text))
                .font(.system(size: fontSize))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(lineSpacing - 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func renderBlockquote(text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.appPrimary)
                .frame(width: 4)

            Text(parseInlineMarkdown(text))
                .font(.system(size: fontSize, design: .serif))
                .italic()
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }

    // MARK: - Inline Markdown

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // 粗体 **text** 或 __text__
        let boldPatterns = [#"\*\*(.+?)\*\*"#, #"__(.+?)__"#]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: nsRange)

                for match in matches.reversed() {
                    if let range = Range(match.range, in: text),
                       let groupRange = Range(match.range(at: 1), in: text) {
                        let boldText = String(text[groupRange])
                        if let attrRange = result.range(of: String(text[range])) {
                            var boldAttr = AttributedString(boldText)
                            boldAttr.font = .system(size: fontSize, weight: .semibold)
                            result.replaceSubrange(attrRange, with: boldAttr)
                        }
                    }
                }
            }
        }

        // 斜体 *text* 或 _text_ (需要避免与粗体冲突)
        let italicPatterns = [#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#]
        for pattern in italicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let currentText = String(result.characters)
                let nsRange = NSRange(currentText.startIndex..., in: currentText)
                let matches = regex.matches(in: currentText, range: nsRange)

                for match in matches.reversed() {
                    if let range = Range(match.range, in: currentText),
                       let groupRange = Range(match.range(at: 1), in: currentText) {
                        let italicText = String(currentText[groupRange])
                        if let attrRange = result.range(of: String(currentText[range])) {
                            var italicAttr = AttributedString(italicText)
                            italicAttr.font = .system(size: fontSize).italic()
                            result.replaceSubrange(attrRange, with: italicAttr)
                        }
                    }
                }
            }
        }

        return result
    }
}

#Preview {
    ScrollView {
        MarkdownView(content: """
        # AI 日记分析

        ## 整体印象

        这是一篇充满童真的日记，小朋友用简单的语言记录了一天的生活。

        ### 亮点

        - 观察力强，注意到了很多细节
        - 表达清晰，语句通顺
        - 情感真挚，能感受到快乐

        ### 建议

        1. 可以增加更多的感受描写
        2. 尝试使用一些比喻句
        3. 注意标点符号的使用

        > 总的来说，这是一篇很棒的日记！继续保持！

        ---

        **整体评分：优秀**
        """)
        .padding()
    }
}

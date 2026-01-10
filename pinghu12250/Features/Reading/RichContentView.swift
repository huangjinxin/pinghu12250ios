//
//  RichContentView.swift
//  pinghu12250
//
//  富文本渲染组件 - 支持 Markdown 基础语法和 HTML 内容
//

import SwiftUI

// MARK: - 富文本渲染视图

struct RichContentView: View {
    let text: String
    var fontSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 先检测是否包含 HTML，如果是则转换为纯文本/Markdown
            let processedText = HTMLHelper.convertToReadableText(text)
            ForEach(Array(parseBlocks(processedText).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - 解析文本块

    private func parseBlocks(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentCodeBlock: [String] = []
        var inCodeBlock = false
        var codeLanguage = ""

        for line in lines {
            // 代码块开始/结束
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    blocks.append(.code(currentCodeBlock.joined(separator: "\n"), language: codeLanguage))
                    currentCodeBlock = []
                    inCodeBlock = false
                    codeLanguage = ""
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if inCodeBlock {
                currentCodeBlock.append(line)
                continue
            }

            // 空行
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.spacer)
                continue
            }

            // 标题
            if line.hasPrefix("####") {
                blocks.append(.heading(String(line.dropFirst(4).trimmingCharacters(in: .whitespaces)), level: 4))
            } else if line.hasPrefix("###") {
                blocks.append(.heading(String(line.dropFirst(3).trimmingCharacters(in: .whitespaces)), level: 3))
            } else if line.hasPrefix("##") {
                blocks.append(.heading(String(line.dropFirst(2).trimmingCharacters(in: .whitespaces)), level: 2))
            } else if line.hasPrefix("#") {
                blocks.append(.heading(String(line.dropFirst(1).trimmingCharacters(in: .whitespaces)), level: 1))
            }
            // 无序列表
            else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                let content = String(line.dropFirst(2))
                blocks.append(.listItem(content, ordered: false, index: 0))
            }
            // 有序列表
            else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let content = String(line[match.upperBound...])
                let numStr = line[..<match.upperBound].filter { $0.isNumber }
                let num = Int(numStr) ?? 1
                blocks.append(.listItem(content, ordered: true, index: num))
            }
            // 引用块
            else if line.hasPrefix(">") {
                let content = String(line.dropFirst().trimmingCharacters(in: .whitespaces))
                blocks.append(.quote(content))
            }
            // 分割线
            else if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
                blocks.append(.divider)
            }
            // 普通段落
            else {
                blocks.append(.paragraph(line))
            }
        }

        // 处理未闭合的代码块
        if inCodeBlock && !currentCodeBlock.isEmpty {
            blocks.append(.code(currentCodeBlock.joined(separator: "\n"), language: codeLanguage))
        }

        return blocks
    }

    // MARK: - 渲染块

    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block {
        case .heading(let text, let level):
            headingView(text, level: level)

        case .paragraph(let text):
            renderInlineText(text)
                .font(.system(size: fontSize))

        case .listItem(let text, let ordered, let index):
            HStack(alignment: .top, spacing: 8) {
                if ordered {
                    Text("\(index).")
                        .font(.system(size: fontSize))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                } else {
                    Text("•")
                        .font(.system(size: fontSize))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                renderInlineText(text)
                    .font(.system(size: fontSize))
            }

        case .quote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.appPrimary)
                    .frame(width: 3)
                renderInlineText(text)
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
            }
            .padding(.vertical, 4)

        case .code(let code, let language):
            codeBlockView(code, language: language)

        case .divider:
            Divider()
                .padding(.vertical, 8)

        case .spacer:
            Spacer()
                .frame(height: 8)
        }
    }

    // MARK: - 标题视图

    private func headingView(_ text: String, level: Int) -> some View {
        let fontSizes: [Int: CGFloat] = [1: 24, 2: 20, 3: 17, 4: 15]
        let weights: [Int: Font.Weight] = [1: .bold, 2: .bold, 3: .semibold, 4: .medium]

        return Text(text)
            .font(.system(size: fontSizes[level] ?? 15, weight: weights[level] ?? .regular))
            .foregroundColor(.primary)
            .padding(.top, level == 1 ? 8 : 4)
            .padding(.bottom, 2)
    }

    // MARK: - 代码块视图

    private func codeBlockView(_ code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 语言标签
            if !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
            }

            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(12)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - 渲染行内格式（粗体、斜体、行内代码、链接）

    private func renderInlineText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text

        while !remaining.isEmpty {
            // 粗体 **text**
            if let boldRange = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
                let before = String(remaining[..<boldRange.lowerBound])
                let match = String(remaining[boldRange])
                let content = String(match.dropFirst(2).dropLast(2))

                if !before.isEmpty {
                    result = result + Text(before)
                }
                result = result + Text(content).bold()
                remaining = String(remaining[boldRange.upperBound...])
            }
            // 斜体 *text* 或 _text_
            else if let italicRange = remaining.range(of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: .regularExpression) {
                let before = String(remaining[..<italicRange.lowerBound])
                let match = String(remaining[italicRange])
                let content = String(match.dropFirst(1).dropLast(1))

                if !before.isEmpty {
                    result = result + Text(before)
                }
                result = result + Text(content).italic()
                remaining = String(remaining[italicRange.upperBound...])
            }
            // 行内代码 `code`
            else if let codeRange = remaining.range(of: #"`([^`]+)`"#, options: .regularExpression) {
                let before = String(remaining[..<codeRange.lowerBound])
                let match = String(remaining[codeRange])
                let content = String(match.dropFirst(1).dropLast(1))

                if !before.isEmpty {
                    result = result + Text(before)
                }
                result = result + Text(content)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundColor(.orange)
                remaining = String(remaining[codeRange.upperBound...])
            }
            // 链接 [text](url) - 简化处理，只显示文本
            else if let linkRange = remaining.range(of: #"\[([^\]]+)\]\([^\)]+\)"#, options: .regularExpression) {
                let before = String(remaining[..<linkRange.lowerBound])
                let match = String(remaining[linkRange])

                // 提取链接文本
                if let textRange = match.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
                    let linkText = String(match[textRange].dropFirst(1).dropLast(1))

                    if !before.isEmpty {
                        result = result + Text(before)
                    }
                    result = result + Text(linkText).foregroundColor(.blue)
                }
                remaining = String(remaining[linkRange.upperBound...])
            }
            // 普通文本
            else {
                result = result + Text(remaining)
                break
            }
        }

        return result
    }
}

// MARK: - 内容块类型

private enum ContentBlock {
    case heading(String, level: Int)
    case paragraph(String)
    case listItem(String, ordered: Bool, index: Int)
    case quote(String)
    case code(String, language: String)
    case divider
    case spacer
}

// MARK: - 预览

#Preview("Markdown 渲染") {
    ScrollView {
        RichContentView(text: """
        # 标题一

        这是一段普通文本，包含**粗体**和*斜体*内容。

        ## 标题二

        这里有一些`行内代码`示例。

        ### 无序列表

        - 第一项
        - 第二项
        - 第三项

        ### 有序列表

        1. 步骤一
        2. 步骤二
        3. 步骤三

        > 这是一段引用文字，通常用于强调或引述。

        ```python
        def hello():
            #if DEBUG
            print("Hello, World!")
            #endif
        ```

        ---

        这是分割线后的内容。
        """)
        .padding()
    }
}

#Preview("AI 分析内容") {
    ScrollView {
        RichContentView(text: """
        ## 光合作用分析

        光合作用是植物利用阳光进行的**生化反应**。

        ### 反应方程式

        `6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂`

        ### 关键要素

        1. **光能** - 来自太阳
        2. **二氧化碳** - 来自空气
        3. **水** - 来自土壤

        > 注意：光合作用主要发生在叶绿体中。
        """)
        .padding()
    }
}

// MARK: - HTML 处理工具

struct HTMLHelper {
    /// 将 HTML 内容转换为可读文本
    static func convertToReadableText(_ text: String) -> String {
        // 如果不包含 HTML 标签，直接返回
        guard text.contains("<") && text.contains(">") else {
            return text
        }

        var result = text

        // 1. 处理常见的 HTML 实体
        let htmlEntities: [String: String] = [
            "&nbsp;": " ",
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&times;": "×",
            "&divide;": "÷",
            "&plusmn;": "±",
            "&frac12;": "½",
            "&frac14;": "¼",
            "&frac34;": "¾",
            "&deg;": "°",
            "&sup2;": "²",
            "&sup3;": "³",
        ]

        for (entity, char) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // 2. 处理数字实体 (&#xxx;)
        let numericPattern = try? NSRegularExpression(pattern: "&#(\\d+);", options: [])
        if let matches = numericPattern?.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let numRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    result.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }

        // 3. 将标题标签转换为 Markdown
        result = result.replacingOccurrences(of: "<h1[^>]*>", with: "\n# ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</h1>", with: "\n")
        result = result.replacingOccurrences(of: "<h2[^>]*>", with: "\n## ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</h2>", with: "\n")
        result = result.replacingOccurrences(of: "<h3[^>]*>", with: "\n### ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</h3>", with: "\n")
        result = result.replacingOccurrences(of: "<h4[^>]*>", with: "\n#### ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</h4>", with: "\n")

        // 4. 将粗体和斜体转换为 Markdown
        result = result.replacingOccurrences(of: "<strong[^>]*>", with: "**", options: .regularExpression)
        result = result.replacingOccurrences(of: "</strong>", with: "**")
        result = result.replacingOccurrences(of: "<b[^>]*>", with: "**", options: .regularExpression)
        result = result.replacingOccurrences(of: "</b>", with: "**")
        result = result.replacingOccurrences(of: "<em[^>]*>", with: "*", options: .regularExpression)
        result = result.replacingOccurrences(of: "</em>", with: "*")
        result = result.replacingOccurrences(of: "<i[^>]*>", with: "*", options: .regularExpression)
        result = result.replacingOccurrences(of: "</i>", with: "*")

        // 5. 处理换行和段落
        result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<br/>", with: "\n")
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "<p[^>]*>", with: "", options: .regularExpression)

        // 6. 处理列表
        result = result.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</li>", with: "\n")
        result = result.replacingOccurrences(of: "<ul[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</ul>", with: "\n")
        result = result.replacingOccurrences(of: "<ol[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</ol>", with: "\n")

        // 7. 处理代码块
        result = result.replacingOccurrences(of: "<code[^>]*>", with: "`", options: .regularExpression)
        result = result.replacingOccurrences(of: "</code>", with: "`")
        result = result.replacingOccurrences(of: "<pre[^>]*>", with: "```\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</pre>", with: "\n```")

        // 8. 处理引用
        result = result.replacingOccurrences(of: "<blockquote[^>]*>", with: "> ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</blockquote>", with: "\n")

        // 9. 处理分割线
        result = result.replacingOccurrences(of: "<hr[^>]*>", with: "\n---\n", options: .regularExpression)

        // 10. 处理 div 和 span
        result = result.replacingOccurrences(of: "<div[^>]*>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</div>", with: "\n")
        result = result.replacingOccurrences(of: "<span[^>]*>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</span>", with: "")

        // 11. 移除所有剩余的 HTML 标签
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 12. 清理多余的空白
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    /// 提取纯文本（用于编辑器）
    static func stripHTML(_ text: String) -> String {
        guard text.contains("<") && text.contains(">") else {
            return text
        }

        var result = text

        // 处理 HTML 实体
        let htmlEntities: [String: String] = [
            "&nbsp;": " ",
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
        ]

        for (entity, char) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // 处理换行
        result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n")

        // 移除所有 HTML 标签
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 清理多余空白
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

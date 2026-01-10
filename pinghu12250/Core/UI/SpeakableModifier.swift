//
//  SpeakableModifier.swift
//  pinghu12250
//
//  全局文本选择修饰符 - 支持系统朗读功能
//  适用于儿童应用，让所有文本都可选择和朗读
//

import SwiftUI
import UIKit

// MARK: - 可选择文本组件（基于 UITextView）

/// 真正可选择的文本组件
/// 使用 UITextView 实现，支持系统级文本选择和朗读
struct SelectableText: UIViewRepresentable {
    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label
    var textAlignment: NSTextAlignment = .natural
    var lineLimit: Int = 0  // 0 表示不限制

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // 核心配置：可选择但不可编辑
        textView.isEditable = false
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true  // 确保用户交互启用

        // 布局配置
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear

        // 自动布局优先级
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        // 禁用数据检测（避免干扰选择）
        textView.dataDetectorTypes = []

        // 禁用链接交互（避免干扰选择）
        textView.linkTextAttributes = [:]

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
        textView.font = font
        textView.textColor = textColor
        textView.textAlignment = textAlignment

        if lineLimit > 0 {
            textView.textContainer.maximumNumberOfLines = lineLimit
            textView.textContainer.lineBreakMode = .byTruncatingTail
        } else {
            textView.textContainer.maximumNumberOfLines = 0
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

// MARK: - SelectableText 便捷初始化

extension SelectableText {
    /// 使用 SwiftUI Font 初始化
    init(_ text: String, font: Font = .body, color: Color = .primary) {
        self.text = text
        self.font = UIFont.preferredFont(forTextStyle: font.toUIFontTextStyle())
        self.textColor = UIColor(color)
    }

    /// 标题样式
    static func title(_ text: String) -> SelectableText {
        SelectableText(
            text: text,
            font: .preferredFont(forTextStyle: .title1),
            textColor: .label
        )
    }

    /// 副标题样式
    static func headline(_ text: String) -> SelectableText {
        SelectableText(
            text: text,
            font: .preferredFont(forTextStyle: .headline),
            textColor: .label
        )
    }

    /// 正文样式
    static func body(_ text: String) -> SelectableText {
        SelectableText(
            text: text,
            font: .preferredFont(forTextStyle: .body),
            textColor: .label
        )
    }

    /// 次要文本样式
    static func secondary(_ text: String) -> SelectableText {
        SelectableText(
            text: text,
            font: .preferredFont(forTextStyle: .subheadline),
            textColor: .secondaryLabel
        )
    }

    /// 小标题样式
    static func caption(_ text: String) -> SelectableText {
        SelectableText(
            text: text,
            font: .preferredFont(forTextStyle: .caption1),
            textColor: .secondaryLabel
        )
    }
}

// MARK: - Font 转换扩展

private extension Font {
    func toUIFontTextStyle() -> UIFont.TextStyle {
        // 简单映射，根据需要扩展
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

// MARK: - 可选择文本视图修饰符

/// 将普通 Text 包装为可选择版本的 ViewModifier
struct SelectableTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textSelection(.enabled)
    }
}

extension View {
    /// 启用文本选择（仅对 Text 视图有效）
    func speakable() -> some View {
        self.modifier(SelectableTextModifier())
    }
}

// MARK: - SpeakableText（SelectableText 的别名）

/// SpeakableText 现在是 SelectableText 的别名
/// 直接使用系统原生的文本选择和朗读功能
/// 注意：不要添加 contextMenu，会干扰原生选择行为
typealias SpeakableText = SelectableText

// MARK: - 朗读引导视图

/// 朗读功能设置引导
struct SpeechSettingsGuideView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0

    private let steps = [
        GuideStep(
            icon: "gearshape.fill",
            title: "打开系统设置",
            description: "点击 iPhone/iPad 的「设置」应用"
        ),
        GuideStep(
            icon: "figure.stand",
            title: "进入辅助功能",
            description: "找到并点击「辅助功能」选项"
        ),
        GuideStep(
            icon: "text.bubble.fill",
            title: "朗读内容",
            description: "点击「朗读内容」进入设置"
        ),
        GuideStep(
            icon: "speaker.wave.2.fill",
            title: "开启朗读所选项",
            description: "打开「朗读所选项」开关\n选择文字后即可点击「朗读」"
        )
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.appPrimary)

                    Text("开启朗读功能")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("让文字「说话」，学习更轻松")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 步骤卡片
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepCard(step: step, number: index + 1)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 280)

                // 快捷跳转按钮
                if let url = URL(string: "App-Prefs:ACCESSIBILITY") {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("打开辅助功能设置")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // 提示
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.appPrimary)
                        Text("使用方法")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("长按任意文字 → 拖动选择范围 → 点击「朗读」")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("朗读设置引导")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func stepCard(step: GuideStep, number: Int) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: step.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.appPrimary)
            }

            Text("第 \(number) 步")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(step.title)
                .font(.headline)

            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.horizontal)
    }
}

private struct GuideStep {
    let icon: String
    let title: String
    let description: String
}

// MARK: - 预览

#Preview("可选择文本") {
    VStack(spacing: 20) {
        SelectableText.title("这是标题文字")
        SelectableText.headline("这是副标题")
        SelectableText.body("这是正文内容，可以长按选择任意文字，然后点击系统菜单中的「朗读」按钮来朗读选中的文字。")
        SelectableText.secondary("这是次要文字")
        SelectableText.caption("这是小标题文字")
    }
    .padding()
}

#Preview("朗读引导") {
    SpeechSettingsGuideView()
}

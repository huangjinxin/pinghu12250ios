//
//  LocalDictionaryService.swift
//  pinghu12250
//
//  本地词典和翻译服务 - 使用 iOS 系统内置功能
//

import SwiftUI
import UIKit

// MARK: - 字典查询结果模型

struct DictEntry: Codable {
    let character: String
    let pinyin: String
    let definition: String
    let strokes: String?
    let radicals: String?
}

struct DictResponse: Codable {
    let success: Bool
    let data: DictEntry?
}

// MARK: - LocalDictionaryService

/// 本地词典和翻译服务
/// 使用 iOS 系统内置的词典和翻译功能
final class LocalDictionaryService {
    static let shared = LocalDictionaryService()

    private init() {}

    // MARK: - 在线字典查询（调用后端API）

    /// 查询汉字拼音和释义
    func lookupCharacter(_ char: String) async -> DictEntry? {
        guard char.count == 1 else { return nil }

        do {
            let endpoint = "\(APIConfig.Endpoints.dict)/\(char.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? char)"
            let response: DictResponse = try await APIService.shared.get(endpoint)
            return response.data
        } catch {
            #if DEBUG
            print("[Dict] API查询失败: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - 词典查询

    /// 检查词典是否支持该词
    func canDefine(_ term: String) -> Bool {
        UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
    }

    /// 显示词典定义（使用 UIReferenceLibraryViewController）
    /// - Parameters:
    ///   - term: 要查询的词
    ///   - from: 从哪个视图控制器弹出
    func showDefinition(for term: String, from viewController: UIViewController? = nil) {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else { return }

        let definitionVC = UIReferenceLibraryViewController(term: cleanTerm)

        if let vc = viewController ?? Self.topViewController {
            if UIDevice.current.userInterfaceIdiom == .pad {
                definitionVC.modalPresentationStyle = .formSheet
            }
            vc.present(definitionVC, animated: true)
        }
    }

    /// 使用 SwiftUI 显示词典定义
    func showDefinition(for term: String) {
        showDefinition(for: term, from: Self.topViewController)
    }

    // MARK: - 翻译功能

    /// 显示系统翻译（iOS 15+）
    /// 使用系统的翻译 App
    @available(iOS 15.0, *)
    func showTranslation(for text: String, from viewController: UIViewController? = nil) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        // 使用系统分享来触发翻译
        // iOS 15+ 可以通过 ActivityViewController 的翻译选项
        let activityVC = UIActivityViewController(
            activityItems: [cleanText],
            applicationActivities: nil
        )

        // 在 iPad 上需要设置 popover
        if let vc = viewController ?? Self.topViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            vc.present(activityVC, animated: true)
        }
    }

    /// 使用系统翻译 URL Scheme（备用方案）
    func openInTranslateApp(text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty,
              let encoded = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "translate://?\(encoded)") else {
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 辅助方法

    /// 获取最顶层的视图控制器
    private static var topViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topVC = window.rootViewController else {
            return nil
        }

        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        return topVC
    }

    /// 判断是单词还是短语/句子
    static func isSingleWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 中文：少于等于4个字符视为单词
        // 英文：不包含空格视为单词
        if trimmed.range(of: "\\p{Han}", options: .regularExpression) != nil {
            // 包含中文
            return trimmed.count <= 4
        } else {
            // 纯英文或其他
            return !trimmed.contains(" ") && trimmed.count <= 20
        }
    }
}

// MARK: - SwiftUI 词典视图

/// SwiftUI 包装的词典视图
struct DictionaryView: UIViewControllerRepresentable {
    let term: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

// MARK: - 词典弹出修饰器

struct DictionaryPopoverModifier: ViewModifier {
    @Binding var isPresented: Bool
    let term: String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term) {
                    DictionaryView(term: term)
                } else {
                    // 词典中没有该词的定义
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("未找到「\(term)」的定义")
                            .font(.headline)

                        Text("请尝试查询其他词语")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("关闭") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                    .padding()
                }
            }
    }
}

extension View {
    /// 显示词典弹窗
    func dictionaryPopover(isPresented: Binding<Bool>, term: String) -> some View {
        modifier(DictionaryPopoverModifier(isPresented: isPresented, term: term))
    }
}

// MARK: - 翻译结果视图

/// 简易翻译结果展示（使用系统分享）
struct TranslationActionView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 原文
                VStack(alignment: .leading, spacing: 8) {
                    Text("原文")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                // 操作按钮
                VStack(spacing: 12) {
                    Button {
                        // 使用系统分享，用户可选择翻译
                        shareForTranslation()
                    } label: {
                        Label("使用系统翻译", systemImage: "globe")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button {
                        // 复制到剪贴板
                        UIPasteboard.general.string = text
                        dismiss()
                    } label: {
                        Label("复制文本", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareForTranslation() {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            topVC.present(activityVC, animated: true)
        }
    }
}

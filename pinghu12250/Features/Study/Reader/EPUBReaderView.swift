//
//  EPUBReaderView.swift
//  pinghu12250
//
//  EPUB 阅读器视图 - 使用 WKWebView 渲染章节 HTML
//

import SwiftUI
import WebKit
import Combine

// MARK: - EPUB 阅读器视图

struct EPUBReaderView: View {
    @ObservedObject var state: ReaderState
    let onTextSelected: (String, CGRect) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 章节导航栏
            chapterNavBar

            // 内容区域
            ZStack {
                if state.isLoadingChapter {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                } else if state.currentChapterHtml.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无内容")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    EPUBWebView(
                        html: state.currentChapterHtml,
                        onTextSelected: onTextSelected
                    )
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 章节导航栏

    private var chapterNavBar: some View {
        HStack(spacing: 12) {
            // 目录按钮
            Menu {
                ForEach(state.chapters) { chapter in
                    Button {
                        Task {
                            await state.goToChapter(chapter.id)
                        }
                    } label: {
                        HStack {
                            Text(chapter.title)
                            if chapter.id == state.currentChapterId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("目录")
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appPrimary.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            // 当前章节标题
            Text(state.currentChapterTitle)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // 章节导航按钮
            HStack(spacing: 8) {
                Button {
                    Task {
                        await state.previousChapter()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .foregroundColor(state.hasPreviousChapter ? .appPrimary : .gray)
                }
                .disabled(!state.hasPreviousChapter)

                Text("\(state.currentChapterIndex + 1)/\(state.chapters.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    Task {
                        await state.nextChapter()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(state.hasNextChapter ? .appPrimary : .gray)
                }
                .disabled(!state.hasNextChapter)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - EPUB WebView

struct EPUBWebView: UIViewRepresentable {
    let html: String
    let onTextSelected: (String, CGRect) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 添加消息处理器用于接收选区信息
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "textSelection")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .white
        webView.isOpaque = false

        // 禁用缩放
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 只有在 HTML 变化时才重新加载
        if context.coordinator.lastLoadedHtml != html {
            context.coordinator.lastLoadedHtml = html
            let fullHtml = wrapHtml(html)
            webView.loadHTMLString(fullHtml, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // 包装 HTML，添加样式和文本选区脚本
    private func wrapHtml(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    -webkit-touch-callout: none;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    font-size: 17px;
                    line-height: 1.8;
                    color: #333;
                    padding: 16px 20px;
                    margin: 0;
                    background: #fff;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin: 1.2em 0 0.6em;
                    font-weight: 600;
                    line-height: 1.4;
                }
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                p {
                    margin: 0.8em 0;
                    text-indent: 2em;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    margin: 1em 0;
                }
                a {
                    color: #1976d2;
                    text-decoration: none;
                }
                blockquote {
                    margin: 1em 0;
                    padding: 0.5em 1em;
                    border-left: 4px solid #ddd;
                    background: #f9f9f9;
                }
                pre, code {
                    font-family: Menlo, Monaco, monospace;
                    background: #f5f5f5;
                    border-radius: 4px;
                }
                pre {
                    padding: 1em;
                    overflow-x: auto;
                }
                code {
                    padding: 0.2em 0.4em;
                    font-size: 0.9em;
                }
                ::selection {
                    background: rgba(25, 118, 210, 0.3);
                }
            </style>
        </head>
        <body>
            \(content)

            <script>
                // 监听文本选区变化
                document.addEventListener('selectionchange', function() {
                    setTimeout(function() {
                        var selection = window.getSelection();
                        if (selection && !selection.isCollapsed) {
                            var text = selection.toString().trim();
                            if (text.length > 0) {
                                var range = selection.getRangeAt(0);
                                var rect = range.getBoundingClientRect();

                                window.webkit.messageHandlers.textSelection.postMessage({
                                    text: text,
                                    x: rect.x,
                                    y: rect.y,
                                    width: rect.width,
                                    height: rect.height
                                });
                            }
                        }
                    }, 100);
                });
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: EPUBWebView
        var lastLoadedHtml: String = ""

        init(_ parent: EPUBWebView) {
            self.parent = parent
        }

        // 处理来自 JavaScript 的文本选区消息
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "textSelection",
                  let body = message.body as? [String: Any],
                  let text = body["text"] as? String,
                  let x = body["x"] as? Double,
                  let y = body["y"] as? Double,
                  let width = body["width"] as? Double,
                  let height = body["height"] as? Double else {
                return
            }

            let rect = CGRect(x: x, y: y, width: width, height: height)
            DispatchQueue.main.async {
                self.parent.onTextSelected(text, rect)
            }
        }

        // 处理链接点击
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                // 外部链接在 Safari 中打开
                if url.scheme == "http" || url.scheme == "https" {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - 预览

#Preview {
    Text("EPUBReaderView Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
}

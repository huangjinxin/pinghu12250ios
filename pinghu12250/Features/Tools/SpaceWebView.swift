//
//  SpaceWebView.swift
//  pinghu12250
//
//  空间 Web - 单域名锁定的全屏浏览器
//

import SwiftUI
import WebKit
import Combine

struct SpaceWebView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = WebViewCoordinator()

    var body: some View {
        NavigationView {
            ZStack {
            WebContainer(coordinator: coordinator)
                .ignoresSafeArea()

            if coordinator.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .navigationTitle("苹湖空间")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        coordinator.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!coordinator.canGoBack)

                    Button {
                        coordinator.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!coordinator.canGoForward)

                    Button {
                        coordinator.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        }
        .navigationViewStyle(.stack)
    }
}

struct WebContainer: UIViewRepresentable {
    let coordinator: WebViewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = true

        coordinator.webView = webView

        if let url = URL(string: "https://kids.706tech.cn") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor
class WebViewCoordinator: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false

    weak var webView: WKWebView? {
        didSet {
            webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
            webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
            webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        }
    }

    private let allowedDomain = "kids.706tech.cn"

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.isLoading) {
            isLoading = webView?.isLoading ?? false
        } else if keyPath == #keyPath(WKWebView.canGoBack) {
            canGoBack = webView?.canGoBack ?? false
        } else if keyPath == #keyPath(WKWebView.canGoForward) {
            canGoForward = webView?.canGoForward ?? false
        }
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    private func isAllowedURL(_ url: URL?) -> Bool {
        guard let host = url?.host else { return false }
        return host == allowedDomain || host.hasSuffix(".\(allowedDomain)")
    }
}

extension WebViewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if isAllowedURL(navigationAction.request.url) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

extension WebViewCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, isAllowedURL(url) {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

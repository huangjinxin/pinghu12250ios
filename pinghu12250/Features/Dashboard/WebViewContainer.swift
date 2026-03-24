//
//  WebViewContainer.swift
//  pinghu12250
//
//  内嵌WebView容器
//

import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

struct WebViewSheet: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if let validUrl = URL(string: url) {
                    WebViewContainer(url: validUrl)
                } else {
                    Text("无效链接")
                }
            }
            .navigationTitle("进度看板")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

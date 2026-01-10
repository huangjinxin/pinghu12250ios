//
//  SimplePDFViewWrapper.swift
//  pinghu12250
//
//  简单的 PDF 阅读视图包装（无批注功能）
//

import SwiftUI
import PDFKit

struct SimplePDFViewWrapper: UIViewRepresentable {

    let document: PDFDocument?
    @Binding var currentPage: Int
    var onTextSelected: ((String, CGRect) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        // 基本配置
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.backgroundColor = .black

        // 设置文档
        pdfView.document = document

        // 监听页面变化
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // 监听文本选择
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // 更新文档
        if pdfView.document !== document {
            pdfView.document = document
        }

        // 同步页面（仅在用户未拖动时）
        if let doc = document,
           let currentPDFPage = pdfView.currentPage,
           doc.index(for: currentPDFPage) + 1 != currentPage,
           let targetPage = doc.page(at: currentPage - 1) {
            pdfView.go(to: targetPage)
        }
    }

    class Coordinator: NSObject {
        var parent: SimplePDFViewWrapper
        weak var pdfView: PDFView?

        init(_ parent: SimplePDFViewWrapper) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let doc = pdfView.document else { return }

            let index = doc.index(for: page)
            let newPage = index + 1

            if parent.currentPage != newPage {
                DispatchQueue.main.async {
                    self.parent.currentPage = newPage
                }
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection,
                  let text = selection.string,
                  !text.isEmpty,
                  let page = selection.pages.first else { return }

            let rect = selection.bounds(for: page)
            let convertedRect = pdfView.convert(rect, from: page)

            DispatchQueue.main.async {
                self.parent.onTextSelected?(text, convertedRect)
            }
        }
    }
}

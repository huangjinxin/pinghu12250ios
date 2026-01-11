//
//  TextbookDetailView.swift
//  pinghu12250
//
//  教材详情页面
//

import SwiftUI
import Combine
import UIKit

struct TextbookDetailView: View {
    let textbook: Textbook

    @ObservedObject private var textbookService = TextbookService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var isFavorite = false
    @State private var isDownloading = false
    @State private var downloadError: String?

    // 阅读器状态
    @State private var showReader = false

    // 导出状态
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 封面区域
                coverSection

                // 信息区域
                infoSection

                // 操作按钮
                actionButtons

                // 简介
                if let description = textbook.description, !description.isEmpty {
                    descriptionSection(description)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(textbook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .primary)
                }
            }
        }
        .onAppear {
            isFavorite = textbookService.isFavorite(textbookId: textbook.id)
        }
        .fullScreenCover(isPresented: $showReader) {
            TextbookReaderView(textbook: textbook)
        }
    }

    // MARK: - 封面区域

    private var coverSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(textbook.subjectColor.opacity(0.15))

            if let coverURL = textbook.coverImageURL {
                AsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundColor(textbook.subjectColor)

                    Text(textbook.subjectName)
                        .font(.headline)
                        .foregroundColor(textbook.subjectColor)
                }
            }
        }
        .frame(height: 280)
        .cornerRadius(16)
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(textbook.fullTitle)
                .font(.title2)
                .fontWeight(.bold)

            // 标签
            HStack(spacing: 8) {
                InfoTag(text: textbook.subjectName, color: textbook.subjectColor)
                InfoTag(text: textbook.gradeName, color: .blue)
                InfoTag(text: textbook.semester, color: .green)
            }

            // 详细信息
            HStack(spacing: 20) {
                if let publisher = textbook.publisher {
                    Label(publisher, systemImage: "building.2")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let totalPages = textbook.totalPages {
                    Label("\(totalPages)页", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let viewCount = textbook.viewCount {
                    Label("\(viewCount)次浏览", systemImage: "eye")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - 操作按钮

    /// 是否有可阅读内容（PDF 或 EPUB）
    private var hasReadableContent: Bool {
        textbook.hasPdf || textbook.hasEpub
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 开始阅读
            Button {
                showReader = true
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    Text("开始阅读")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(hasReadableContent ? Color.appPrimary : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!hasReadableContent)

            HStack(spacing: 12) {
                // 下载离线
                Button {
                    Task {
                        await downloadForOffline()
                    }
                } label: {
                    HStack {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        } else if offlineManager.isTextbookAvailableOffline(textbookId: textbook.id) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已下载")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("离线下载")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(offlineManager.isTextbookAvailableOffline(textbookId: textbook.id) ? Color.green.opacity(0.15) : Color(.systemGray5))
                    .foregroundColor(offlineManager.isTextbookAvailableOffline(textbookId: textbook.id) ? .green : .primary)
                    .cornerRadius(12)
                }
                .disabled(isDownloading || !textbook.hasPdf)

                // 保存到文件
                Button {
                    exportTextbook()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("保存文件")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .disabled(!hasReadableContent)
            }
        }
        .alert("下载失败", isPresented: .constant(downloadError != nil)) {
            Button("确定") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
        .alert("导出失败", isPresented: .constant(exportError != nil)) {
            Button("确定") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showExportSheet) {
            if let fileURL = exportFileURL {
                ActivityViewController(activityItems: [fileURL])
            }
        }
    }

    // MARK: - 下载离线

    private func downloadForOffline() async {
        guard let pdfUrl = textbook.pdfFullURL?.absoluteString else {
            downloadError = "未找到PDF文件"
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            try await offlineManager.downloadTextbookForOffline(textbookId: textbook.id, pdfUrl: pdfUrl)
        } catch {
            downloadError = error.localizedDescription
        }
    }

    // MARK: - 简介

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - 方法

    /// 导出教材文件
    private func exportTextbook() {
        // 清空之前的错误
        exportError = nil

        // 获取文件URL
        guard let fileURL = getTextbookFileURL() else {
            exportError = "文件未下载，请先下载教材"
            return
        }

        // 创建临时文件，使用中文教材名
        let fileName = "\(textbook.displayTitle).\(textbook.isEpub ? "epub" : "pdf")"
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            // 删除可能已存在的临时文件
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }

            // 复制文件到临时目录
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)

            // 设置文件URL并显示分享界面
            exportFileURL = tempFileURL
            showExportSheet = true

        } catch {
            exportError = "导出失败: \(error.localizedDescription)"
        }
    }

    /// 获取教材文件的本地URL
    private func getTextbookFileURL() -> URL? {
        // 优先处理EPUB
        if textbook.isEpub, let epubURL = textbook.epubFullURL {
            // 检查DownloadManager缓存
            let fileName = epubURL.lastPathComponent
            if let cachedURL = DownloadManager.shared.getCachedFileURL(for: epubURL, fileName: fileName) {
                return cachedURL
            }
        }

        // 处理PDF
        if textbook.hasPdf, let pdfURL = textbook.pdfFullURL {
            // 检查DownloadManager缓存
            let fileName = pdfURL.lastPathComponent
            if let cachedURL = DownloadManager.shared.getCachedFileURL(for: pdfURL, fileName: fileName) {
                return cachedURL
            }

            // 检查OfflineManager下载
            if offlineManager.isTextbookAvailableOffline(textbookId: textbook.id) {
                // OfflineManager使用coredata存储，需要获取实际文件路径
                // 假设文件存储在Documents/Textbooks目录
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let textbooksPath = documentsPath.appendingPathComponent("Textbooks", isDirectory: true)
                let localPDFPath = textbooksPath.appendingPathComponent("\(textbook.id).pdf")

                if FileManager.default.fileExists(atPath: localPDFPath.path) {
                    return localPDFPath
                }
            }
        }

        return nil
    }

    private func toggleFavorite() {
        Task {
            if isFavorite {
                let success = await textbookService.removeFavorite(textbookId: textbook.id)
                if success { isFavorite = false }
            } else {
                let success = await textbookService.addFavorite(textbookId: textbook.id)
                if success { isFavorite = true }
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - 信息标签

struct InfoTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        TextbookDetailView(textbook: .placeholder(
            id: "1",
            title: "语文三年级上册",
            subject: "语文",
            grade: 3,
            semester: "上册",
            version: "人教版"
        ))
    }
}

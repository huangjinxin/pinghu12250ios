//
//  TextbookDetailView.swift
//  pinghu12250
//
//  教材详情页面
//

import SwiftUI
import Combine

struct TextbookDetailView: View {
    let textbook: Textbook

    @ObservedObject private var textbookService = TextbookService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var isFavorite = false
    @State private var isDownloading = false
    @State private var downloadError: String?

    // 模式选择和阅读器状态
    @State private var showModeSelector = false
    @State private var showReader = false
    @State private var showAnnotationReader = false
    @State private var annotationTextbook: Textbook?

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
        // 模式选择器
        .sheet(isPresented: $showModeSelector) {
            if #available(iOS 16.0, *) {
                TextbookModeSelector(
                    textbook: textbook,
                    onSelectReading: {
                        showModeSelector = false
                        showReader = true
                    },
                    onSelectAnnotation: {
                        showModeSelector = false
                        annotationTextbook = textbook
                    },
                    onDismiss: {
                        showModeSelector = false
                    }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
        // 批注阅读器
        .fullScreenCover(item: $annotationTextbook) { book in
            if #available(iOS 16.0, *) {
                PDFAnnotationReaderView(
                    textbook: book,
                    initialPageIndex: nil,
                    onDismiss: {
                        annotationTextbook = nil
                    }
                )
            }
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
        HStack(spacing: 16) {
            // 开始阅读 - 显示模式选择器
            Button {
                showModeSelector = true
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
        }
        .alert("下载失败", isPresented: .constant(downloadError != nil)) {
            Button("确定") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
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

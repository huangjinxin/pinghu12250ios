//
//  CachedAsyncImage.swift
//  pinghu12250
//
//  带磁盘缓存的异步图片加载组件
//

import SwiftUI

/// 带持久化缓存的异步图片组件
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true

        Task {
            // 从缓存加载或下载
            if let image = await CacheService.shared.downloadImage(url: url.absoluteString) {
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

/// 简化版本 - 默认占位符
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}

/// 教材封面专用的缓存图片组件
struct CachedTextbookCover: View {
    let coverURL: URL?
    let subjectColor: Color
    let subjectIcon: String

    var body: some View {
        CachedAsyncImage(url: coverURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // 加载中或失败时显示占位符
            ZStack {
                LinearGradient(
                    colors: [subjectColor, subjectColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Text(subjectIcon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    VStack {
        CachedAsyncImage(
            url: URL(string: "https://example.com/image.jpg")
        ) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ProgressView()
        }
        .frame(width: 100, height: 150)
        .cornerRadius(8)

        CachedTextbookCover(
            coverURL: nil,
            subjectColor: .blue,
            subjectIcon: "数"
        )
        .frame(width: 100, height: 150)
        .cornerRadius(8)
    }
}

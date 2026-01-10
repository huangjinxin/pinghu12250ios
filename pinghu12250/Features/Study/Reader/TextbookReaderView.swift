//
//  TextbookReaderView.swift
//  pinghu12250
//
//  教材阅读器顶层路由 - 根据屏幕方向切换模式
//  竖屏 = 纯阅读模式（PureReaderView）
//  横屏 = AI辅助模式（AssistModeView）
//

import SwiftUI
import PDFKit
import Combine

struct TextbookReaderView: View {
    let textbook: Textbook

    @StateObject private var state: ReaderState
    @StateObject private var layoutManager = ReaderLayoutManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    init(textbook: Textbook) {
        self.textbook = textbook
        _state = StateObject(wrappedValue: ReaderState(textbook: textbook))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 根据模式切换视图
                switch state.readerMode {
                case .pureReading:
                    PureReaderView(state: state, onDismiss: { dismiss() })
                        .transition(.opacity)

                case .aiAssist:
                    AssistModeView(state: state, layoutManager: layoutManager, onDismiss: { dismiss() })
                        .transition(.opacity)
                }

                // 加载状态
                if state.isLoading {
                    LoadingOverlay(textbook: textbook, state: state, onDismiss: { dismiss() })
                }

                // 错误状态
                if let error = state.loadError {
                    ErrorOverlay(error: error, onRetry: {
                        Task { await state.loadContent() }
                    }, onDismiss: { dismiss() })
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                state.updateMode(for: newSize)
            }
            .onAppear {
                state.updateMode(for: geometry.size)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: state.isFullscreen)
        .task {
            await state.loadContent()
        }
    }
}

// MARK: - 加载覆盖层

private struct LoadingOverlay: View {
    let textbook: Textbook
    @ObservedObject var state: ReaderState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            // 返回按钮（左上角）
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 50)

                    Spacer()
                }
                Spacer()
            }

            VStack(spacing: 24) {
                // 封面预览
                if let coverURL = textbook.coverImageURL {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                        default:
                            bookPlaceholder
                        }
                    }
                } else {
                    bookPlaceholder
                }

                VStack(spacing: 12) {
                    Text(textbook.displayTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)

                    Text("正在加载...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var bookPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(textbook.subjectColor.opacity(0.3))
            .frame(width: 140, height: 200)
            .overlay(
                Text(textbook.subjectIcon)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(textbook.subjectColor)
            )
    }
}

// MARK: - 错误覆盖层

private struct ErrorOverlay: View {
    let error: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            // 返回按钮（左上角）
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 50)

                    Spacer()
                }
                Spacer()
            }

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("加载失败")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    // 简化预览，避免复杂依赖
    Text("TextbookReaderView Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}

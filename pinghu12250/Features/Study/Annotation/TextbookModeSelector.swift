//
//  TextbookModeSelector.swift
//  pinghu12250
//
//  教材模式选择器
//  用户点击教材时弹出选择：学习模式 / 批注模式
//

import SwiftUI

@available(iOS 16.0, *)
struct TextbookModeSelector: View {

    let textbook: Textbook
    let onSelectReading: () -> Void
    let onSelectAnnotation: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            VStack(spacing: 8) {
                Text(textbook.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("选择打开方式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal)

            // 选项
            VStack(spacing: 12) {
                // 学习模式
                ModeOptionButton(
                    icon: "book.fill",
                    title: "学习模式",
                    subtitle: "阅读、AI 辅助、笔记",
                    color: .blue
                ) {
                    onSelectReading()
                }

                // 批注模式
                ModeOptionButton(
                    icon: "pencil.tip.crop.circle",
                    title: "批注模式",
                    subtitle: "Apple Pencil 直接书写",
                    color: .orange
                ) {
                    onSelectAnnotation()
                }
            }
            .padding(20)

            Divider()

            // 取消
            Button {
                onDismiss()
            } label: {
                Text("取消")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.secondary)
            }
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
}

// MARK: - Mode Option Button

private struct ModeOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(12)

                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sheet Modifier

@available(iOS 16.0, *)
struct TextbookModeSelectorModifier: ViewModifier {

    @Binding var isPresented: Bool
    let textbook: Textbook?
    let onSelectReading: (Textbook) -> Void
    let onSelectAnnotation: (Textbook) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let textbook = textbook {
                    TextbookModeSelector(
                        textbook: textbook,
                        onSelectReading: {
                            isPresented = false
                            onSelectReading(textbook)
                        },
                        onSelectAnnotation: {
                            isPresented = false
                            onSelectAnnotation(textbook)
                        },
                        onDismiss: {
                            isPresented = false
                        }
                    )
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
                }
            }
    }
}

@available(iOS 16.0, *)
extension View {
    func textbookModeSelector(
        isPresented: Binding<Bool>,
        textbook: Textbook?,
        onSelectReading: @escaping (Textbook) -> Void,
        onSelectAnnotation: @escaping (Textbook) -> Void
    ) -> some View {
        modifier(TextbookModeSelectorModifier(
            isPresented: isPresented,
            textbook: textbook,
            onSelectReading: onSelectReading,
            onSelectAnnotation: onSelectAnnotation
        ))
    }
}

// MARK: - Full Screen Cover for Annotation Reader

@available(iOS 16.0, *)
struct AnnotationReaderPresenter: ViewModifier {

    @Binding var textbook: Textbook?
    @Binding var initialPageIndex: Int?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $textbook) { book in
                PDFAnnotationReaderView(
                    textbook: book,
                    initialPageIndex: initialPageIndex,
                    onDismiss: {
                        textbook = nil
                        initialPageIndex = nil
                    }
                )
            }
    }
}

@available(iOS 16.0, *)
extension View {
    func annotationReaderPresenter(
        textbook: Binding<Textbook?>,
        initialPageIndex: Binding<Int?>
    ) -> some View {
        modifier(AnnotationReaderPresenter(
            textbook: textbook,
            initialPageIndex: initialPageIndex
        ))
    }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        TextbookModeSelector(
            textbook: Textbook.preview,
            onSelectReading: {},
            onSelectAnnotation: {},
            onDismiss: {}
        )
    }
}

// MARK: - Preview Helper

extension Textbook {
    static var preview: Textbook {
        Textbook(
            id: "test",
            subject: "数学",
            grade: 5,
            semester: "上学期",
            version: "人教版",
            title: "数学五年级上册",
            pdfUrl: nil,
            coverImage: nil,
            totalPages: 100,
            pdfSize: nil,
            status: nil,
            isHidden: nil,
            createdBy: nil,
            createdAt: nil,
            updatedAt: nil,
            publisher: nil,
            description: nil,
            isPublic: nil,
            viewCount: nil,
            units: nil,
            contentType: "pdf",
            epubUrl: nil,
            epubMetadata: nil
        )
    }
}

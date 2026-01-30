//
//  PracticeSetupView.swift
//  pinghu12250
//
//  练习设置视图
//

import SwiftUI

struct PracticeSetupView: View {
    @ObservedObject var viewModel: WritingViewModel
    @State private var showCanvas = false
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部标题栏 + 开始练习按钮
                HStack {
                    Text("临摹练习")
                        .font(.title2.bold())

                    Spacer()

                    // 开始练习按钮放在右上角
                    Button {
                        isTextEditorFocused = false
                        viewModel.startPractice()
                        showCanvas = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.circle.fill")
                            Text("开始练习")
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(viewModel.practiceText.isEmpty ? Color.gray : Color.appPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .disabled(viewModel.practiceText.isEmpty)
                }
                .padding(.horizontal)

                // 文字输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("输入要练习的文字")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        if viewModel.practiceText.isEmpty {
                            Text("例如：永字八法、春夏秋冬...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                        }

                        TextEditor(text: $viewModel.practiceText)
                            .focused($isTextEditorFocused)
                            .frame(minHeight: 100, maxHeight: 150)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextEditorFocused ? Color.appPrimary : Color.gray.opacity(0.3), lineWidth: isTextEditorFocused ? 2 : 1)
                            )
                    }

                    // 字数统计
                    HStack {
                        Text("已输入 \(viewModel.practiceText.count) 字")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if isTextEditorFocused {
                            Button("完成") {
                                isTextEditorFocused = false
                            }
                            .font(.caption.bold())
                            .foregroundColor(.appPrimary)
                        }
                    }
                }
                .padding(.horizontal)

                // 字体选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择参考字体")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 系统字体
                            FontOption(
                                name: "系统字体",
                                fontName: nil,
                                isSelected: viewModel.selectedFont == nil,
                                onSelect: { viewModel.selectedFont = nil }
                            )

                            // 用户字体
                            ForEach(viewModel.fonts) { font in
                                FontOption(
                                    name: font.displayName,
                                    fontName: viewModel.registeredFontNames[font.id],
                                    isSelected: viewModel.selectedFont?.id == font.id,
                                    onSelect: { viewModel.selectedFont = font }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 预览
                if !viewModel.practiceText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("预览")
                                .font(.headline)
                            Text("(\(viewModel.practiceText.count)字)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(viewModel.practiceText.enumerated()), id: \.offset) { _, char in
                                    ZStack {
                                        GridBackgroundView(gridType: .mi, lineColor: .gray.opacity(0.2))
                                        ReferenceCharView(
                                            character: char,
                                            fontName: viewModel.selectedFont.flatMap { viewModel.registeredFontNames[$0.id] },
                                            opacity: 0.6
                                        )
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top)
        }
        .onTapGesture {
            isTextEditorFocused = false
        }
        .fullScreenCover(isPresented: $showCanvas) {
            CalligraphyCanvasView(viewModel: viewModel)
        }
    }
}

// MARK: - 字体选项

private struct FontOption: View {
    let name: String
    let fontName: String?  // 注册后的字体名称
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("永")
                    .font(fontForPreview)
                    .frame(width: 50, height: 50)

                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(8)
            .background(isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var fontForPreview: Font {
        if let fontName = fontName {
            return .custom(fontName, size: 30)
        }
        return .custom("STKaiti", size: 30)
    }
}

#Preview {
    PracticeSetupView(viewModel: WritingViewModel())
}

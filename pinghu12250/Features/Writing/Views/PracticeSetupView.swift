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

    var body: some View {
        VStack(spacing: 24) {
            // 文字输入
            VStack(alignment: .leading, spacing: 8) {
                Text("输入要练习的文字")
                    .font(.headline)

                TextField("例如：永字八法", text: $viewModel.practiceText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }
            .padding(.horizontal)

            // 字体选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择参考字体")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // 系统字体
                        FontOption(
                            name: "系统字体",
                            isSelected: viewModel.selectedFont == nil,
                            onSelect: { viewModel.selectedFont = nil }
                        )

                        // 用户字体
                        ForEach(viewModel.fonts) { font in
                            FontOption(
                                name: font.displayName,
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
                    Text("预览")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.practiceText.enumerated()), id: \.offset) { _, char in
                                ZStack {
                                    GridBackgroundView(gridType: .mi, lineColor: .gray.opacity(0.2))
                                    ReferenceCharView(character: char, opacity: 0.6)
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

            Spacer()

            // 开始按钮
            Button {
                viewModel.startPractice()
                showCanvas = true
            } label: {
                Text("开始练习")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.practiceText.isEmpty ? Color.gray : Color.appPrimary)
                    .cornerRadius(12)
            }
            .disabled(viewModel.practiceText.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .fullScreenCover(isPresented: $showCanvas) {
            CalligraphyCanvasView(viewModel: viewModel)
        }
    }
}

// MARK: - 字体选项

private struct FontOption: View {
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("永")
                    .font(.system(size: 30))
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
}

#Preview {
    PracticeSetupView(viewModel: WritingViewModel())
}

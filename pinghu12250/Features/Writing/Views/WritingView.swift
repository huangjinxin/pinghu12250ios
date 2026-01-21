//
//  WritingView.swift
//  pinghu12250
//
//  书写功能主容器视图
//

import SwiftUI

struct WritingView: View {
    @StateObject private var viewModel = WritingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab切换
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(WritingViewModel.Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区
            Group {
                switch viewModel.selectedTab {
                case .fonts:
                    FontManagerView(viewModel: viewModel)
                case .practice:
                    PracticeSetupView(viewModel: viewModel)
                case .gallery:
                    CalligraphyGalleryView(viewModel: viewModel)
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadFonts()
        }
    }
}

#Preview {
    WritingView()
}

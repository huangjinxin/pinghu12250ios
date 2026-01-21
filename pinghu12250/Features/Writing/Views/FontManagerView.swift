//
//  FontManagerView.swift
//  pinghu12250
//
//  字体管理视图
//

import SwiftUI
import UniformTypeIdentifiers

struct FontManagerView: View {
    @ObservedObject var viewModel: WritingViewModel
    @State private var showFilePicker = false
    @State private var fontName = ""
    @State private var selectedFontData: Data?
    @State private var selectedFileName = ""
    @State private var showNameSheet = false
    @State private var isUploading = false

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                // 添加字体按钮
                Button {
                    showFilePicker = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.appPrimary)
                        Text("添加字体")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // 字体列表
                ForEach(viewModel.fonts) { font in
                    FontCard(
                        font: font,
                        isSelected: viewModel.selectedFont?.id == font.id,
                        onSelect: { viewModel.selectedFont = font },
                        onSetDefault: { Task { await viewModel.setDefaultFont(font) } },
                        onDelete: { Task { await viewModel.deleteFont(font) } }
                    )
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoadingFonts {
                ProgressView()
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ttf")!, UTType(filenameExtension: "otf")!],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showNameSheet) {
            fontNameSheet
        }
    }

    private var fontNameSheet: some View {
        NavigationStack {
            Form {
                Section("字体名称") {
                    TextField("输入字体名称", text: $fontName)
                }
                Section {
                    Text("文件: \(selectedFileName)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加字体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showNameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("上传") {
                        Task { await uploadFont() }
                    }
                    .disabled(fontName.isEmpty || isUploading)
                }
            }
            .overlay {
                if isUploading {
                    ProgressView("上传中...")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            selectedFontData = try Data(contentsOf: url)
            selectedFileName = url.lastPathComponent
            fontName = url.deletingPathExtension().lastPathComponent
            showNameSheet = true
        } catch {
            viewModel.errorMessage = "读取字体文件失败"
            viewModel.showError = true
        }
    }

    private func uploadFont() async {
        guard let data = selectedFontData else { return }

        isUploading = true
        defer { isUploading = false }

        do {
            _ = try await WritingService.shared.uploadFont(data: data, filename: selectedFileName, name: fontName)
            showNameSheet = false
            await viewModel.loadFonts()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
    }
}

// MARK: - 字体卡片

private struct FontCard: View {
    let font: UserFont
    let isSelected: Bool
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 预览字
            Text("永")
                .font(.system(size: 50))
                .frame(height: 70)

            // 字体名
            Text(font.displayName)
                .font(.caption)
                .lineLimit(1)

            // 默认标记
            if font.isDefault == true {
                Text("默认")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary)
                    .cornerRadius(4)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
        .contextMenu {
            if font.isDefault != true {
                Button(action: onSetDefault) {
                    Label("设为默认", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

#Preview {
    FontManagerView(viewModel: WritingViewModel())
}

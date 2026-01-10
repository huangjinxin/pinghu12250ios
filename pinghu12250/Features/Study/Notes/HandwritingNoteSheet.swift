//
//  HandwritingNoteSheet.swift
//  pinghu12250
//
//  手写笔记预览与编辑界面
//  用户主动触发"保存到笔记"时显示
//

import SwiftUI
import PencilKit

struct HandwritingNoteSheet: View {
    @Environment(\.dismiss) private var dismiss

    let drawing: PKDrawing
    let textbookId: String
    let pageIndex: Int
    let onSave: () -> Void

    @State private var recognizedText: String = ""
    @State private var isRecognizing = true
    @State private var recognitionError: String?
    @State private var isSaving = false

    // 缩略图
    @State private var thumbnailImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 手写预览
                handwritingPreview

                Divider()

                // 识别结果
                recognitionSection

                Spacer()
            }
            .padding()
            .navigationTitle("保存手写笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("放弃") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveNote()
                    }
                    .disabled(isRecognizing || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await performRecognition()
        }
    }

    // MARK: - 手写预览

    private var handwritingPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pencil.tip.crop.circle")
                    .foregroundColor(.teal)
                Text("手写内容")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("P\(pageIndex + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            // 缩略图显示
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 100)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }

    // MARK: - 识别结果区域

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundColor(.blue)
                Text("识别结果")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()

                if isRecognizing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("识别中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let error = recognitionError {
                // 识别失败
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // 可编辑文本框
            TextEditor(text: $recognizedText)
                .font(.body)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            Text("可编辑识别结果，修正识别错误")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 识别逻辑

    private func performRecognition() async {
        // 生成缩略图
        let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        thumbnailImage = drawing.image(from: bounds, scale: 1.0)

        // 调用 OCR 服务
        if let text = await OCRService.shared.recognizeText(from: drawing) {
            recognizedText = text
        } else {
            recognizedText = ""
            recognitionError = "未能识别文字，可手动输入"
        }

        isRecognizing = false
    }

    // MARK: - 保存笔记

    private func saveNote() {
        isSaving = true

        // 准备附件数据
        let drawingData = drawing.dataRepresentation()
        let thumbnailData = thumbnailImage?.jpegData(compressionQuality: 0.6)

        var attachments: [NoteAttachment] = []

        // 添加原始绘图数据
        attachments.append(NoteAttachment(
            id: UUID(),
            type: .drawing,
            data: drawingData,
            url: nil
        ))

        // 添加缩略图
        if let thumbData = thumbnailData {
            attachments.append(NoteAttachment(
                id: UUID(),
                type: .image,
                data: thumbData,
                url: nil
            ))
        }

        // 创建笔记
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: pageIndex,
            title: generateTitle(),
            content: recognizedText,
            type: .handwriting,
            tags: ["手写"],
            attachments: attachments
        )

        NotesManager.shared.createNote(note)

        isSaving = false
        onSave()
        dismiss()
    }

    private func generateTitle() -> String {
        let firstLine = recognizedText.components(separatedBy: .newlines).first ?? ""
        if firstLine.isEmpty {
            return "手写笔记 P\(pageIndex + 1)"
        }
        return String(firstLine.prefix(20)) + (firstLine.count > 20 ? "..." : "")
    }
}

#Preview {
    HandwritingNoteSheet(
        drawing: PKDrawing(),
        textbookId: "test",
        pageIndex: 0,
        onSave: {}
    )
}

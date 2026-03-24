//
//  PhotosView.swift
//  pinghu12250
//
//  照片分享 - 对应 Web 端 Photos.vue
//

import SwiftUI
import PhotosUI

struct PhotosView: View {
    @StateObject private var viewModel = PhotosViewModel()
    @State private var showPublish = false
    @State private var selectedPhoto: PhotoItem?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("照片分享")
                    .font(.headline)
                Spacer()
                Button {
                    showPublish = true
                } label: {
                    Label("发布照片", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemBackground))

            // 照片列表
            ScrollView {
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.photos.isEmpty {
                    emptyPhotoState
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(viewModel.photos) { photo in
                            PhotoCard(photo: photo)
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }
                    }
                    .padding()
                }
            }
            .refreshable {
                await viewModel.loadPhotos(refresh: true)
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            if viewModel.photos.isEmpty {
                await viewModel.loadPhotos(refresh: true)
            }
        }
        .sheet(isPresented: $showPublish) {
            PhotoPublishSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailSheet(photo: photo, viewModel: viewModel)
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyPhotoState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("还没有照片分享，快来发布第一张吧")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - 照片卡片

struct PhotoCard: View {
    let photo: PhotoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 照片预览
            ZStack(alignment: .topTrailing) {
                if let imageUrl = photo.fullImageURL {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                        case .failure:
                            photoPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(height: 140)
                        @unknown default:
                            photoPlaceholder
                        }
                    }
                } else {
                    photoPlaceholder
                }

                // 照片数量
                if photo.images.count > 1 {
                    Text("+\(photo.images.count - 1)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(6)
                }

                // 心情标签
                if let mood = photo.mood {
                    Text(moodEmoji(mood))
                        .font(.title2)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(8)
                }
            }
            .cornerRadius(10)

            // 作者信息
            if let author = photo.author {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(author.avatarLetter)
                                .font(.system(size: 10))
                                .foregroundColor(.appPrimary)
                        )
                    Text(author.displayName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            // 内容
            if let content = photo.content, !content.isEmpty {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // 底部信息
            HStack {
                Text(photo.relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Label("\(photo.likesCount)", systemImage: photo.isLiked ? "heart.fill" : "heart")
                        .font(.caption2)
                        .foregroundColor(photo.isLiked ? .red : .secondary)
                    Label("\(photo.commentsCount)", systemImage: "bubble.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.systemGray5))
            .frame(height: 140)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            )
    }

    private func moodEmoji(_ mood: String) -> String {
        switch mood {
        case "happy": return "😄"
        case "excited": return "🤩"
        case "calm": return "😊"
        case "sad": return "😢"
        case "angry": return "😠"
        case "anxious": return "😰"
        default: return ""
        }
    }
}

// MARK: - 发布照片

struct PhotoPublishSheet: View {
    @ObservedObject var viewModel: PhotosViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var content = ""
    @State private var selectedMood: String?
    @State private var selectedPhotoType = "other"
    @State private var isPublic = true
    @State private var isPublishing = false

    let moodOptions = [
        ("happy", "😄", "开心"),
        ("excited", "🤩", "兴奋"),
        ("calm", "😊", "平静"),
        ("sad", "😢", "难过"),
        ("angry", "😠", "生气"),
        ("anxious", "😰", "焦虑")
    ]

    let photoTypeOptions = [
        ("selfie", "自拍"),
        ("scenery", "风景"),
        ("friends", "朋友"),
        ("food", "美食"),
        ("pet", "宠物"),
        ("activity", "活动"),
        ("other", "其他")
    ]

    var body: some View {
        NavigationStack {
            Form {
                // 照片选择
                Section("选择照片（最多9张）") {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 9, matching: .images) {
                        if selectedImages.isEmpty {
                            Label("选择照片", systemImage: "photo.on.rectangle.angled")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0..<selectedImages.count, id: \.self) { index in
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 9, matching: .images) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title2)
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: selectedItems) { _, newItems in
                        loadImages(from: newItems)
                    }
                }

                // 文字描述
                Section("说点什么（可选）") {
                    TextField("此刻的心情...", text: $content, axis: .vertical)
                        .lineLimit(2...4)
                }

                // 心情选择
                Section("此刻心情") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(moodOptions, id: \.0) { mood in
                            MoodButton(
                                emoji: mood.1,
                                label: mood.2,
                                isSelected: selectedMood == mood.0
                            ) {
                                selectedMood = selectedMood == mood.0 ? nil : mood.0
                            }
                        }
                    }
                }

                // 照片类型
                Section("这是一张") {
                    Picker("照片类型", selection: $selectedPhotoType) {
                        ForEach(photoTypeOptions, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 隐私设置
                Section("谁可以看") {
                    Toggle(isPublic ? "公开" : "仅自己", isOn: $isPublic)
                }
            }
            .navigationTitle("发布照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        publishPhoto()
                    }
                    .disabled(selectedImages.isEmpty || isPublishing)
                }
            }
            .overlay {
                if isPublishing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(ProgressView())
                }
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        selectedImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }

    private func publishPhoto() {
        isPublishing = true
        Task {
            let success = await viewModel.publishPhoto(
                images: selectedImages,
                content: content,
                mood: selectedMood,
                photoType: selectedPhotoType,
                isPublic: isPublic
            )
            isPublishing = false
            if success {
                dismiss()
            }
        }
    }
}

struct MoodButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.appPrimary.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 照片详情

struct PhotoDetailSheet: View {
    let photo: PhotoItem
    @ObservedObject var viewModel: PhotosViewModel
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var detailPhoto: PhotoItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 作者信息
                    if let author = photo.author {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(author.avatarLetter)
                                        .foregroundColor(.appPrimary)
                                        .fontWeight(.medium)
                                )
                            VStack(alignment: .leading) {
                                Text(author.displayName)
                                    .fontWeight(.medium)
                                Text(photo.relativeTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // 图片轮播
                    TabView {
                        ForEach(photo.allFullImageURLs, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure, .empty:
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                                .foregroundColor(.secondary)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)

                    // 标签
                    HStack(spacing: 8) {
                        if let mood = photo.mood {
                            Text("\(moodEmoji(mood)) \(moodLabel(mood))")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        if let photoType = photo.photoType {
                            Text(photoTypeLabel(photoType))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // 内容
                    if let content = photo.content, !content.isEmpty {
                        Text(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // 互动按钮
                    HStack(spacing: 24) {
                        Button {
                            Task { await viewModel.toggleLike(photo.id) }
                        } label: {
                            Label("\(detailPhoto?.likesCount ?? photo.likesCount)", systemImage: (detailPhoto?.isLiked ?? photo.isLiked) ? "heart.fill" : "heart")
                                .foregroundColor((detailPhoto?.isLiked ?? photo.isLiked) ? .red : .secondary)
                        }
                        .buttonStyle(.plain)

                        Label("\(detailPhoto?.commentsCount ?? photo.commentsCount)", systemImage: "bubble.right")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))

                    // 评论列表
                    if let comments = detailPhoto?.comments, !comments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.appPrimary.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(comment.author?.avatarLetter ?? "")
                                                .font(.system(size: 10))
                                                .foregroundColor(.appPrimary)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(comment.author?.displayName ?? "")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(comment.content)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 评论输入
                    HStack {
                        TextField("写评论...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                        Button("发送") {
                            Task {
                                if await viewModel.addComment(photo.id, content: commentText) {
                                    commentText = ""
                                    await loadDetail()
                                }
                            }
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("照片详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await loadDetail()
            }
        }
    }

    private func loadDetail() async {
        detailPhoto = await viewModel.loadPhotoDetail(photo.id)
    }

    private func moodEmoji(_ mood: String) -> String {
        switch mood {
        case "happy": return "😄"
        case "excited": return "🤩"
        case "calm": return "😊"
        case "sad": return "😢"
        case "angry": return "😠"
        case "anxious": return "😰"
        default: return ""
        }
    }

    private func moodLabel(_ mood: String) -> String {
        switch mood {
        case "happy": return "开心"
        case "excited": return "兴奋"
        case "calm": return "平静"
        case "sad": return "难过"
        case "angry": return "生气"
        case "anxious": return "焦虑"
        default: return ""
        }
    }

    private func photoTypeLabel(_ type: String) -> String {
        switch type {
        case "selfie": return "自拍"
        case "scenery": return "风景"
        case "friends": return "朋友"
        case "food": return "美食"
        case "pet": return "宠物"
        case "activity": return "活动"
        default: return "其他"
        }
    }
}

#Preview {
    PhotosView()
}

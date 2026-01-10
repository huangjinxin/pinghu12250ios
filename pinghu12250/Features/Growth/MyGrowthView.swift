//
//  MyGrowthView.swift
//  pinghu12250
//
//  心路历程 - 奖罚规则提交（与 web 端 /my-growth 同步）
//

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import Combine

struct MyGrowthView: View {
    @State private var selectedTab = 0
    @StateObject private var viewModel = MyGrowthViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab 切换
            Picker("", selection: $selectedTab) {
                Text("我擅长的").tag(0)
                Text("可填写项目").tag(1)
                Text("我的提交").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            TabView(selection: $selectedTab) {
                // 我擅长的（收藏）
                FavoritesTabView(viewModel: viewModel)
                    .tag(0)

                // 可填写项目
                AvailableTemplatesTabView(viewModel: viewModel)
                    .tag(1)

                // 我的提交
                MySubmissionsTabView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await viewModel.loadAllData()
        }
        .refreshable {
            await viewModel.loadAllData()
        }
        .sheet(item: $viewModel.selectedTemplate) { template in
            SubmissionFormSheet(template: template, viewModel: viewModel)
        }
        .sheet(item: $viewModel.viewingSubmission) { submission in
            SubmissionDetailSheet(submission: submission)
        }
        // 监听从 Dashboard 跳转过来的 Tab 切换通知
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("switchGrowthSubTab"))) { notification in
            if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = tabIndex
                }
            }
        }
    }
}

// MARK: - 我擅长的 Tab

struct FavoritesTabView: View {
    @ObservedObject var viewModel: MyGrowthViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingFavorites {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.favoriteTemplates.isEmpty {
                emptyView
            } else {
                templateGrid(viewModel.favoriteTemplates, isFavoriteTab: true)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("暂无收藏项目")
                .foregroundColor(.secondary)
            Text("可以在「可填写项目」中点击星标收藏")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func templateGrid(_ templates: [RuleTemplate], isFavoriteTab: Bool) -> some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(templates) { template in
                    TemplateCard(
                        template: template,
                        isFavorite: isFavoriteTab || viewModel.isFavorite(template.id),
                        onTap: { viewModel.selectedTemplate = template },
                        onToggleFavorite: { viewModel.toggleFavorite(template) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - 可填写项目 Tab

struct AvailableTemplatesTabView: View {
    @ObservedObject var viewModel: MyGrowthViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingTemplates {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.availableTemplates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("暂无可填写的项目")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(viewModel.availableTemplates) { template in
                            TemplateCard(
                                template: template,
                                isFavorite: viewModel.isFavorite(template.id),
                                onTap: { viewModel.selectedTemplate = template },
                                onToggleFavorite: { viewModel.toggleFavorite(template) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 我的提交 Tab

struct MySubmissionsTabView: View {
    @ObservedObject var viewModel: MyGrowthViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingSubmissions && viewModel.mySubmissions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.mySubmissions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("暂无提交记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.mySubmissions) { submission in
                            SubmissionCard(submission: submission) {
                                viewModel.viewingSubmission = submission
                            }
                            .onAppear {
                                // 自动加载更多
                                if submission.id == viewModel.mySubmissions.suffix(3).first?.id {
                                    Task { await viewModel.loadMySubmissions() }
                                }
                            }
                        }

                        // 底部状态
                        if viewModel.isLoadingSubmissions {
                            ProgressView()
                                .padding()
                        } else if !viewModel.submissionsHasMore {
                            Text("— 没有更多了 —")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 模板卡片

struct TemplateCard: View {
    let template: RuleTemplate
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }

            // 积分
            HStack {
                Text(template.points > 0 ? "+\(template.points)" : "\(template.points)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(template.points > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(template.points > 0 ? .green : .red)
                    .cornerRadius(4)

                Spacer()
            }

            // 类型标签
            HStack(spacing: 4) {
                if let typeName = template.type?.name {
                    Text(typeName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                if let standardName = template.standard?.name {
                    Text(standardName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }

            // 要求标签
            HStack(spacing: 4) {
                if template.requireText {
                    requirementTag("文字")
                }
                if template.requireImage {
                    requirementTag("图片")
                }
                if template.requireAudio == true {
                    requirementTag("音频", color: .purple)
                }
                if template.requireLink {
                    requirementTag("链接")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture(perform: onTap)
    }

    private func requirementTag(_ text: String, color: Color = .gray) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color == .gray ? .secondary : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - 提交卡片

struct SubmissionCard: View {
    let submission: RuleSubmission
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(submission.template?.name ?? "未知规则")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                statusBadge
            }

            if let content = submission.content, !content.isEmpty {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                // 积分
                if let points = submission.template?.points {
                    Text(points > 0 ? "+\(points)" : "\(points)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(points > 0 ? .green : .red)
                }

                Spacer()

                // 时间
                Text(submission.createdAt?.relativeDescription ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }

    private var statusBadge: some View {
        Text(submission.statusText)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(submission.statusColor.opacity(0.2))
            .foregroundColor(submission.statusColor)
            .cornerRadius(4)
    }
}

// MARK: - 提交表单

struct SubmissionFormSheet: View {
    let template: RuleTemplate
    @ObservedObject var viewModel: MyGrowthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var content = ""
    @State private var link = ""
    @State private var quantity = 1
    @State private var isSubmitting = false

    // 图片选择
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var uploadedImageUrls: [String] = []
    @State private var isUploadingImages = false

    // 音频录制
    @State private var recordedAudioURL: URL?
    @State private var isUploadingAudio = false

    var body: some View {
        NavigationStack {
            Form {
                Section("规则信息") {
                    LabeledContent("名称", value: template.name)
                    LabeledContent("积分", value: template.points > 0 ? "+\(template.points)" : "\(template.points)")
                    if let typeName = template.type?.name {
                        LabeledContent("类型", value: typeName)
                    }
                }

                if template.requireText {
                    Section("描述说明") {
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                    }
                }

                // 图片上传区域
                if template.requireImage {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // 已选择的图片预览
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                Button {
                                                    removeImage(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(.black.opacity(0.5)))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                            }

                            // 图片选择按钮
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 2,
                                matching: .images
                            ) {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text(selectedImages.isEmpty ? "选择图片" : "更换图片")
                                }
                                .foregroundColor(.blue)
                            }
                            .onChange(of: selectedPhotos) {
                                loadSelectedImages()
                            }

                            Text("最多上传2张图片")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        HStack {
                            Text("上传图片")
                            if isUploadingImages {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                }

                // 音频录制区域
                if template.requireAudio == true {
                    Section {
                        CompactRecordButton(
                            audioURL: $recordedAudioURL,
                            title: "",
                            maxDuration: 180
                        )
                    } header: {
                        HStack {
                            Text("录制音频")
                            if isUploadingAudio {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    } footer: {
                        Text("点击上方按钮录制音频，最长3分钟")
                    }
                }

                if template.requireLink {
                    Section("链接") {
                        TextField("请输入链接地址", text: $link)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }

                if template.allowQuantity == true {
                    Section("数量") {
                        Stepper("数量: \(quantity)", value: $quantity, in: 1...100)
                        Text("总积分: \(quantity * template.points)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("填写表单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        submitForm()
                    }
                    .disabled(isSubmitting || isUploadingImages || isUploadingAudio || !isFormValid)
                }
            }
        }
    }

    private func loadSelectedImages() {
        Task {
            selectedImages.removeAll()
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }

    private func removeImage(at index: Int) {
        selectedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }

    private func submitForm() {
        Task {
            isSubmitting = true

            // 如果有图片，先上传
            var imageUrls: [String] = []
            if !selectedImages.isEmpty {
                isUploadingImages = true
                for image in selectedImages {
                    if let jpegData = image.jpegData(compressionQuality: 0.8),
                       let url = await viewModel.uploadImage(jpegData) {
                        imageUrls.append(url)
                    }
                }
                isUploadingImages = false
            }

            // 如果有音频，先上传
            var audioUrls: [String] = []
            if let audioURL = recordedAudioURL {
                isUploadingAudio = true
                do {
                    let audioData = try Data(contentsOf: audioURL)
                    if let url = await viewModel.uploadAudio(audioData, filename: audioURL.lastPathComponent) {
                        audioUrls.append(url)
                    }
                } catch {
                    #if DEBUG
                    print("读取音频文件失败: \(error)")
                    #endif
                }
                isUploadingAudio = false
            }

            await viewModel.submitForm(
                templateId: template.id,
                content: content,
                images: imageUrls,
                audios: audioUrls,
                link: link,
                quantity: quantity
            )
            isSubmitting = false
            dismiss()
        }
    }

    private var isFormValid: Bool {
        if template.requireText && content.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if template.requireImage && selectedImages.isEmpty {
            return false
        }
        if template.requireAudio == true && recordedAudioURL == nil {
            return false
        }
        if template.requireLink && link.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }
}

// MARK: - 提交详情

struct SubmissionDetailSheet: View {
    let submission: RuleSubmission
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("规则信息") {
                    LabeledContent("规则名称", value: submission.template?.name ?? "未知")
                    LabeledContent("积分", value: "\(submission.template?.points ?? 0)")
                }

                Section("提交信息") {
                    LabeledContent("状态", value: submission.statusText)
                    if let content = submission.content, !content.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(content)
                        }
                    }
                    if let link = submission.link, !link.isEmpty {
                        LabeledContent("链接", value: link)
                    }
                    LabeledContent("提交时间", value: submission.createdAt?.relativeDescription ?? "")
                }

                // 图片展示
                if let images = submission.images, !images.isEmpty {
                    Section("提交图片") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(images, id: \.self) { imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        case .failure:
                                            Image(systemName: "photo")
                                                .frame(width: 100, height: 100)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(8)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 音频展示（带播放功能）
                if let audios = submission.audios, !audios.isEmpty {
                    Section("提交音频") {
                        ForEach(Array(audios.enumerated()), id: \.offset) { index, audioUrl in
                            AudioPlaybackRow(audioUrl: audioUrl, index: index)
                        }
                    }
                }

                if let reviewNote = submission.reviewNote, !reviewNote.isEmpty {
                    Section("审核备注") {
                        Text(reviewNote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("提交详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 音频播放行（用于提交详情）

struct AudioPlaybackRow: View {
    let audioUrl: String
    let index: Int

    @StateObject private var player = RemoteAudioPlayer()
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            // 播放/暂停按钮
            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                    }
                }
            }
            .buttonStyle(.plain)

            // 音频信息和进度
            VStack(alignment: .leading, spacing: 4) {
                Text("音频 \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if player.duration > 0 {
                    // 进度条
                    ProgressView(value: player.progress)
                        .tint(.purple)

                    // 时间
                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("点击播放")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 波形图标
            Image(systemName: "waveform")
                .foregroundColor(.purple.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            if let url = URL(string: audioUrl) {
                isLoading = true
                player.play(url: url) {
                    isLoading = false
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 远程音频播放器

@MainActor
class RemoteAudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func play(url: URL, onReady: (() -> Void)? = nil) {
        // 如果已经在播放同一个URL，继续播放
        if let currentItem = player?.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           currentURL == url {
            player?.play()
            isPlaying = true
            onReady?()
            return
        }

        // 停止之前的播放
        stop()

        // 配置音频会话
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("音频会话配置失败: \(error)")
            #endif
        }

        // 创建播放器
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // 监听准备完成 - 使用现代异步 API
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let durationValue = try await playerItem.asset.load(.duration)
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(durationValue)
                    self.player?.play()
                    self.isPlaying = true
                    onReady?()
                }
            } catch {
                #if DEBUG
                print("加载音频时长失败: \(error)")
                #endif
                await MainActor.run {
                    self.player?.play()
                    self.isPlaying = true
                    onReady?()
                }
            }
        }

        // 添加时间观察者
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
            }
        }

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}

#Preview {
    MyGrowthView()
}

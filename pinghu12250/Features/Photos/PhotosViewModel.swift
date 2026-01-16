//
//  PhotosViewModel.swift
//  pinghu12250
//
//  照片分享 ViewModel - 对应 Web 端 Photos.vue
//

import Foundation
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class PhotosViewModel: ObservableObject {

    // MARK: - 数据

    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 分页

    private var currentPage = 1
    private var pageSize = 20
    private var hasMore = true

    // MARK: - 加载照片列表

    func loadPhotos(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/photos?page=\(currentPage)&limit=\(pageSize)"
            let response: PhotoListResponse = try await APIService.shared.get(endpoint)

            if refresh {
                photos = response.data
            } else {
                photos.append(contentsOf: response.data)
            }

            if let pagination = response.pagination {
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.data.count >= pageSize
            }

            currentPage += 1
        } catch {
            #if DEBUG
            print("加载照片失败: \(error)")
            #endif
            errorMessage = "加载照片失败"
        }
    }

    // MARK: - 加载照片详情

    func loadPhotoDetail(_ id: String) async -> PhotoItem? {
        do {
            let endpoint = "/photos/\(id)"
            let response: PhotoDetailResponse = try await APIService.shared.get(endpoint)
            return response.data
        } catch {
            #if DEBUG
            print("加载照片详情失败: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - 发布照片

    func publishPhoto(
        images: [UIImage],
        content: String,
        mood: String?,
        photoType: String,
        isPublic: Bool
    ) async -> Bool {
        guard !images.isEmpty else {
            errorMessage = "请选择至少一张照片"
            return false
        }

        do {
            // 构建 multipart form data
            let boundary = UUID().uuidString
            var body = Data()

            // 添加照片
            for (index, image) in images.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"photos\"; filename=\"photo\(index).jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            }

            // 添加其他字段
            func addField(_ name: String, _ value: String) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }

            addField("content", content)
            if let mood = mood {
                addField("mood", mood)
            }
            addField("photoType", photoType)
            addField("isPublic", isPublic ? "true" : "false")

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            // 发送请求
            guard let url = URL(string: APIConfig.baseURL + "/photos") else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            if let token = APIService.shared.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "发布失败")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(PhotoPublishResponse.self, from: data)

            if result.success {
                // 刷新列表
                await loadPhotos(refresh: true)
                return true
            } else {
                errorMessage = result.error ?? "发布失败"
                return false
            }
        } catch {
            #if DEBUG
            print("发布照片失败: \(error)")
            #endif
            errorMessage = "发布失败"
            return false
        }
    }

    // MARK: - 点赞

    func toggleLike(_ photoId: String) async {
        do {
            let endpoint = "/photos/\(photoId)/like"
            let response: PhotoLikeResponse = try await APIService.shared.post(endpoint)

            // 更新本地状态
            if let index = photos.firstIndex(where: { $0.id == photoId }) {
                var photo = photos[index]
                let newLikesCount = response.liked ? photo.likesCount + 1 : photo.likesCount - 1
                // 由于 PhotoItem 是 struct，需要重新创建
                photos[index] = PhotoItem(
                    id: photo.id,
                    content: photo.content,
                    images: photo.images,
                    mood: photo.mood,
                    moodScore: photo.moodScore,
                    photoType: photo.photoType,
                    location: photo.location,
                    isPublic: photo.isPublic,
                    author: photo.author,
                    likesCount: newLikesCount,
                    commentsCount: photo.commentsCount,
                    isLiked: response.liked,
                    createdAt: photo.createdAt,
                    comments: photo.comments
                )
            }
        } catch {
            #if DEBUG
            print("点赞失败: \(error)")
            #endif
        }
    }

    // MARK: - 评论

    func addComment(_ photoId: String, content: String) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        do {
            struct CommentRequest: Encodable {
                let content: String
            }

            let endpoint = "/photos/\(photoId)/comment"
            let _: PhotoCommentResponse = try await APIService.shared.post(endpoint, body: CommentRequest(content: content))
            return true
        } catch {
            #if DEBUG
            print("评论失败: \(error)")
            #endif
            return false
        }
    }
}

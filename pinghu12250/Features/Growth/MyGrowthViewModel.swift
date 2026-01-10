//
//  MyGrowthViewModel.swift
//  pinghu12250
//
//  心路历程 ViewModel - 奖罚规则提交
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MyGrowthViewModel: ObservableObject {
    // MARK: - 数据

    @Published var favoriteTemplates: [RuleTemplate] = []
    @Published var availableTemplates: [RuleTemplate] = []
    @Published var mySubmissions: [RuleSubmission] = []

    // MARK: - 加载状态

    @Published var isLoadingFavorites = false
    @Published var isLoadingTemplates = false
    @Published var isLoadingSubmissions = false
    @Published var isSubmitting = false

    // MARK: - 分页状态

    @Published var submissionsPage = 1
    @Published var submissionsHasMore = true
    private let submissionsPageSize = 20

    // MARK: - 收藏状态缓存

    @Published private var favoriteIds: Set<String> = []

    // MARK: - 弹窗控制

    @Published var selectedTemplate: RuleTemplate?
    @Published var viewingSubmission: RuleSubmission?

    // MARK: - 错误处理

    @Published var errorMessage: String?

    // MARK: - 加载所有数据

    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFavorites() }
            group.addTask { await self.loadAvailableTemplates() }
            group.addTask { await self.loadMySubmissions(refresh: true) }
        }
    }

    // MARK: - 加载收藏的模板

    func loadFavorites() async {
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }

        do {
            let response: FavoritesResponse = try await APIService.shared.get(
                APIConfig.Endpoints.templateFavorites
            )
            favoriteTemplates = response.templates
            // 更新收藏ID缓存
            favoriteIds = Set(response.templates.map { $0.id })
        } catch {
            #if DEBUG
            print("加载收藏失败: \(error)")
            #endif
            favoriteTemplates = []
        }
    }

    // MARK: - 加载可填写的模板

    func loadAvailableTemplates() async {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }

        do {
            let response: TemplatesResponse = try await APIService.shared.get(
                APIConfig.Endpoints.ruleTemplates
            )
            availableTemplates = response.templates

            // 检查收藏状态
            await checkFavoriteStatus(for: response.templates)
        } catch {
            #if DEBUG
            print("加载模板失败: \(error)")
            #endif
            availableTemplates = []
        }
    }

    // MARK: - 检查收藏状态

    private func checkFavoriteStatus(for templates: [RuleTemplate]) async {
        let templateIds = templates.map { $0.id }
        guard !templateIds.isEmpty else { return }

        do {
            let response: CheckFavoritesResponse = try await APIService.shared.post(
                APIConfig.Endpoints.checkTemplateFavorites,
                body: ["templateIds": templateIds]
            )
            favoriteIds = Set(response.favorites.filter { $0.value }.map { $0.key })
        } catch {
            #if DEBUG
            print("检查收藏状态失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载我的提交

    func loadMySubmissions(refresh: Bool = false) async {
        if refresh {
            submissionsPage = 1
            submissionsHasMore = true
        }

        guard submissionsHasMore else { return }
        isLoadingSubmissions = true
        defer { isLoadingSubmissions = false }

        do {
            let endpoint = "\(APIConfig.Endpoints.mySubmissions)?page=\(submissionsPage)&limit=\(submissionsPageSize)"
            let response: SubmissionsResponse = try await APIService.shared.get(endpoint)

            if refresh {
                mySubmissions = response.submissions
            } else {
                mySubmissions.append(contentsOf: response.submissions)
            }

            if let pagination = response.pagination {
                submissionsHasMore = submissionsPage < pagination.totalPages
            } else {
                submissionsHasMore = response.submissions.count >= submissionsPageSize
            }
            submissionsPage += 1
        } catch {
            #if DEBUG
            print("加载提交记录失败: \(error)")
            #endif
            if refresh {
                mySubmissions = []
            }
        }
    }

    // MARK: - 收藏相关

    func isFavorite(_ templateId: String) -> Bool {
        favoriteIds.contains(templateId)
    }

    func toggleFavorite(_ template: RuleTemplate) {
        Task {
            if isFavorite(template.id) {
                await removeFavorite(template)
            } else {
                await addFavorite(template)
            }
        }
    }

    private func addFavorite(_ template: RuleTemplate) async {
        do {
            let _: FavoriteResponse = try await APIService.shared.post(
                APIConfig.Endpoints.templateFavorites,
                body: ["templateId": template.id]
            )
            favoriteIds.insert(template.id)
            // 刷新收藏列表
            await loadFavorites()
        } catch {
            #if DEBUG
            print("添加收藏失败: \(error)")
            #endif
            errorMessage = "收藏失败"
        }
    }

    private func removeFavorite(_ template: RuleTemplate) async {
        do {
            let _: MessageResponse = try await APIService.shared.delete(
                "\(APIConfig.Endpoints.templateFavorites)/\(template.id)"
            )
            favoriteIds.remove(template.id)
            // 刷新收藏列表
            await loadFavorites()
        } catch {
            #if DEBUG
            print("取消收藏失败: \(error)")
            #endif
            errorMessage = "取消收藏失败"
        }
    }

    // MARK: - 提交表单

    func submitForm(
        templateId: String,
        content: String,
        images: [String],
        audios: [String],
        link: String,
        quantity: Int
    ) async {
        isSubmitting = true
        defer { isSubmitting = false }

        let request = CreateSubmissionRequest(
            templateId: templateId,
            content: content.isEmpty ? nil : content,
            images: images.isEmpty ? nil : images,
            audios: audios.isEmpty ? nil : audios,
            link: link.isEmpty ? nil : link,
            quantity: quantity > 1 ? quantity : nil
        )

        do {
            let _: SubmissionResponse = try await APIService.shared.post(
                APIConfig.Endpoints.submissions,
                body: request
            )
            // 刷新提交列表
            await loadMySubmissions(refresh: true)
            selectedTemplate = nil
        } catch {
            #if DEBUG
            print("提交失败: \(error)")
            #endif
            errorMessage = "提交失败，请重试"
        }
    }

    // MARK: - 上传图片

    func uploadImage(_ imageData: Data) async -> String? {
        do {
            let response: UploadResponse = try await APIService.shared.uploadImage(imageData, filename: "image.jpg")
            return response.url
        } catch {
            #if DEBUG
            print("图片上传失败: \(error)")
            #endif
            errorMessage = "图片上传失败"
            return nil
        }
    }

    // MARK: - 上传音频

    func uploadAudio(_ audioData: Data, filename: String) async -> String? {
        do {
            let response: UploadResponse = try await APIService.shared.uploadAudio(audioData, filename: filename)
            return response.url
        } catch {
            #if DEBUG
            print("音频上传失败: \(error)")
            #endif
            errorMessage = "音频上传失败"
            return nil
        }
    }
}

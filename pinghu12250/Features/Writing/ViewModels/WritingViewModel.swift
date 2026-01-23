//
//  WritingViewModel.swift
//  pinghu12250
//
//  书写功能状态管理
//

import SwiftUI
import PencilKit
import CoreText
import Combine

@MainActor
class WritingViewModel: ObservableObject {
    // MARK: - Tab状态
    enum Tab: String, CaseIterable {
        case fonts = "字体"
        case practice = "临摹"
        case gallery = "作品库"
    }

    @Published var selectedTab: Tab = .practice

    // MARK: - 字体管理
    @Published var fonts: [UserFont] = []
    @Published var selectedFont: UserFont?
    @Published var isLoadingFonts = false
    @Published var registeredFontNames: [String: String] = [:]  // fontId -> postScriptName

    // MARK: - 练习状态
    @Published var practiceText = ""
    @Published var currentCharIndex = 0
    @Published var isPracticing = false

    var currentChar: Character? {
        guard !practiceText.isEmpty, currentCharIndex < practiceText.count else { return nil }
        let index = practiceText.index(practiceText.startIndex, offsetBy: currentCharIndex)
        return practiceText[index]
    }

    var practiceProgress: Double {
        guard !practiceText.isEmpty else { return 0 }
        return Double(currentCharIndex) / Double(practiceText.count)
    }

    // MARK: - 作品库
    enum ViewMode: String, CaseIterable {
        case all = "全部作品"
        case my = "我的作品"
    }

    enum SortBy: String, CaseIterable {
        case latest = "最新"
        case popular = "最热"
    }

    @Published var works: [CalligraphyWork] = []
    @Published var isLoadingWorks = false
    @Published var worksPage = 1
    @Published var hasMoreWorks = true
    @Published var viewMode: ViewMode = .all
    @Published var sortBy: SortBy = .latest

    // MARK: - 错误处理
    @Published var errorMessage: String?
    @Published var showError = false

    private let service = WritingService.shared

    // MARK: - 字体操作

    func loadFonts() async {
        isLoadingFonts = true
        defer { isLoadingFonts = false }

        do {
            fonts = try await service.getFonts()
            // 自动选择默认字体
            if selectedFont == nil {
                selectedFont = fonts.first(where: { $0.isDefault == true }) ?? fonts.first
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func setDefaultFont(_ font: UserFont) async {
        do {
            try await service.setDefaultFont(id: font.id)
            await loadFonts()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteFont(_ font: UserFont) async {
        do {
            try await service.deleteFont(id: font.id)
            fonts.removeAll { $0.id == font.id }
            if selectedFont?.id == font.id {
                selectedFont = fonts.first
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// 动态注册字体
    func registerFont(data: Data, fontId: String) -> String? {
        guard let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else { return nil }

        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(cgFont, &error) else { return nil }

        let ctFont = CTFontCreateWithGraphicsFont(cgFont, 0, nil, nil)
        let postScriptName = CTFontCopyPostScriptName(ctFont) as String
        registeredFontNames[fontId] = postScriptName
        return postScriptName
    }

    // MARK: - 练习操作

    func startPractice() {
        guard !practiceText.isEmpty else { return }
        currentCharIndex = 0
        isPracticing = true
    }

    func nextChar() {
        guard currentCharIndex < practiceText.count - 1 else {
            isPracticing = false
            return
        }
        currentCharIndex += 1
    }

    func previousChar() {
        guard currentCharIndex > 0 else { return }
        currentCharIndex -= 1
    }

    func endPractice() {
        isPracticing = false
        currentCharIndex = 0
    }

    // MARK: - 作品操作

    func loadWorks(refresh: Bool = false) async {
        if refresh {
            worksPage = 1
            hasMoreWorks = true
        }

        guard hasMoreWorks, !isLoadingWorks else { return }

        isLoadingWorks = true
        defer { isLoadingWorks = false }

        do {
            if viewMode == .all {
                let (items, _, totalPages) = try await service.getWorks(
                    page: worksPage,
                    pageSize: 20,
                    sort: sortBy == .latest ? "latest" : "popular"
                )
                if refresh {
                    works = items
                } else {
                    works.append(contentsOf: items)
                }
                hasMoreWorks = worksPage < totalPages
            } else {
                let (items, total) = try await service.getMyWorks(page: worksPage, pageSize: 20)
                if refresh {
                    works = items
                } else {
                    works.append(contentsOf: items)
                }
                hasMoreWorks = works.count < total
            }
            worksPage += 1
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadWorkDetail(_ workId: String) async -> CalligraphyWork? {
        do {
            return try await service.getWork(id: workId)
        } catch {
            print("加载作品详情失败: \(error)")
            // 不显示错误提示，以免打断用户体验，仅在控制台记录
            return nil
        }
    }

    func saveWork(content: String, image: UIImage, drawing: PKDrawing, canvasSize: CGSize) async -> Bool {
        do {
            // 上传图片
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                showError("图片处理失败")
                return false
            }
            let uploadResponse = try await APIService.shared.uploadImage(imageData, filename: "calligraphy.jpg")

            // 生成笔画数据
            let strokeData = StrokeDataV2.from(drawing: drawing, canvasSize: canvasSize)
            let strokeJSON = strokeData.toJSON()

            // 创建作品
            _ = try await service.createWork(
                content: content,
                fontId: selectedFont?.id,
                imagePath: uploadResponse.url,
                strokeData: strokeJSON
            )

            await loadWorks(refresh: true)
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    func deleteWork(_ work: CalligraphyWork) async {
        do {
            try await service.deleteWork(id: work.id)
            works.removeAll { $0.id == work.id }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func toggleLike(_ work: CalligraphyWork) async {
        do {
            let (liked, count) = try await service.toggleLike(id: work.id)
            if let index = works.firstIndex(where: { $0.id == work.id }) {
                // 由于CalligraphyWork是struct，需要重新创建
                var updatedWork = works[index]
                // 这里简化处理，实际需要更新isLiked和likeCount
                works[index] = updatedWork
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - 错误处理

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

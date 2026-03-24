//
//  WorksViewModel.swift
//  pinghu12250
//
//  作品广场 ViewModel - 画廊/朗诵/诗词古文/购物
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class WorksViewModel: ObservableObject {

    // MARK: - 钱包引用（用于支付）

    var walletViewModel: WalletViewModel?

    // MARK: - 画廊数据

    @Published var galleryWorks: [GalleryWork] = []
    @Published var galleryTypes: [GalleryType] = []
    @Published var galleryStandards: [GalleryStandard] = []
    @Published var selectedGalleryType: GalleryType?
    @Published var selectedGalleryStandard: GalleryStandard?
    @Published var isLoadingGallery = false

    // MARK: - 朗诵数据

    @Published var recitationWorks: [RecitationWork] = []
    @Published var isLoadingRecitation = false
    @Published var currentPlayingId: String?
    private var audioPlayer: AVPlayer?

    // MARK: - 诗词古文数据（使用 creative-works API）

    @Published var poetryWorks: [CreativeWorkItem] = []
    @Published var isLoadingPoetry = false
    @Published var poetryRefreshError: String?
    @Published var poetrySortBy: String = "latest"
    @Published var poetrySearchText: String = ""
    @Published var poetryType: String? = nil
    @Published var poetryRefreshId: UUID = UUID()
    private var likedPoetryIds: Set<String> = []

    // MARK: - 购物数据

    @Published var marketWorks: [MarketWork] = []
    @Published var myPurchases: [MarketOrder] = []
    @Published var qrProducts: [QRCodeProduct] = []
    @Published var qrCategories: [String] = []
    @Published var selectedQRCategory: String = ""
    @Published var isLoadingMarket = false
    @Published var isLoadingQR = false
    @Published var marketSortBy: String = "latest"  // latest, popular, price_asc, price_desc
    @Published var marketCategory: String = "all"  // all, free, paid, exclusive

    // MARK: - 公开日记分析数据（作品广场语义）

    @Published var publicDiaryAnalysis: [PublicDiaryAnalysisItem] = []
    @Published var isLoadingPublicDiaryAnalysis = false
    @Published var publicDiaryAnalysisPage: Int = 1
    @Published var publicDiaryAnalysisHasMore: Bool = true
    @Published var diaryAnalysisRefreshId: UUID = UUID()  // 强制刷新标识符

    // MARK: - 创意作品数据（动态栏目）

    @Published var creativeWorks: [CreativeWorkItem] = []
    @Published var isLoadingCreativeWorks = false
    @Published var creativeWorksPage: Int = 1
    @Published var creativeWorksHasMore: Bool = true

    // MARK: - 书写作品数据

    @Published var calligraphyWorks: [CalligraphyWork] = []
    @Published var isLoadingCalligraphy = false
    @Published var calligraphyPage: Int = 1
    @Published var calligraphyHasMore: Bool = true

    // MARK: - 分页（每个 Tab 独立）

    @Published var pageSize: Int = 18

    // 画廊分页
    @Published var galleryPage: Int = 1
    @Published var galleryHasMore: Bool = true

    // 朗诵分页
    @Published var recitationPage: Int = 1
    @Published var recitationHasMore: Bool = true

    // 诗词古文分页
    @Published var poetryPage: Int = 1
    @Published var poetryHasMore: Bool = true

    // 购物分页
    @Published var marketPage: Int = 1
    @Published var marketHasMore: Bool = true

    // 兼容旧代码（已废弃，请使用各 Tab 独立的分页状态）
    @Published var currentPage: Int = 1
    @Published var hasMore: Bool = true

    // MARK: - 状态

    @Published var errorMessage: String?
    @Published var selectedWork: GalleryWork?
    @Published var selectedRecitation: RecitationWork?
    @Published var selectedPoetry: CreativeWorkItem?
    @Published var selectedMarketWork: MarketWork?

    // MARK: - 初始化

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("音频会话设置失败: \(error)")
            #endif
        }
    }

    // MARK: - 画廊 API

    func loadGalleryWorks(refresh: Bool = false) async {
        if refresh {
            galleryPage = 1
            galleryHasMore = true
        }

        guard galleryHasMore else { return }
        isLoadingGallery = true
        defer { isLoadingGallery = false }

        do {
            var params: [String: String] = [
                "page": "\(galleryPage)",
                "pageSize": "\(pageSize)"
            ]

            if let typeId = selectedGalleryType?.id {
                params["typeId"] = typeId
            }
            if let standardId = selectedGalleryStandard?.id {
                params["standardId"] = standardId
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.galleryPublic)?\(queryString)"

            let response: GalleryResponse = try await APIService.shared.get(endpoint)

            if refresh {
                galleryWorks = response.works
            } else {
                galleryWorks.append(contentsOf: response.works)
            }

            if let pagination = response.pagination {
                galleryHasMore = galleryPage < pagination.totalPages
            } else {
                galleryHasMore = response.works.count >= pageSize
            }

            galleryPage += 1
        } catch {
            #if DEBUG
            print("加载画廊失败: \(error)")
            #endif
        }
    }

    func loadGalleryTypes() async {
        do {
            let response: GalleryTypesResponse = try await APIService.shared.get(
                APIConfig.Endpoints.galleryTypes
            )
            galleryTypes = response.types
        } catch {
            #if DEBUG
            print("加载画廊类型失败: \(error)")
            #endif
        }
    }

    func loadGalleryStandards() async {
        do {
            let response: GalleryStandardsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.galleryStandards
            )
            galleryStandards = response.standards
        } catch {
            #if DEBUG
            print("加载画廊标准失败: \(error)")
            #endif
        }
    }

    // MARK: - 朗诵 API

    func loadRecitationWorks(refresh: Bool = false) async {
        if refresh {
            recitationPage = 1
            recitationHasMore = true
        }

        guard recitationHasMore else { return }
        isLoadingRecitation = true
        defer { isLoadingRecitation = false }

        do {
            let params: [String: String] = [
                "page": "\(recitationPage)",
                "pageSize": "\(pageSize)"
            ]

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.recitationPublic)?\(queryString)"

            let response: RecitationResponse = try await APIService.shared.get(endpoint)

            if refresh {
                recitationWorks = response.works
            } else {
                recitationWorks.append(contentsOf: response.works)
            }

            if let pagination = response.pagination {
                recitationHasMore = recitationPage < pagination.totalPages
            } else {
                recitationHasMore = response.works.count >= pageSize
            }

            recitationPage += 1
        } catch {
            #if DEBUG
            print("加载朗诵失败: \(error)")
            #endif
        }
    }

    func playAudio(_ urlString: String, workId: String) {
        guard let url = URL(string: urlString) else { return }

        if currentPlayingId == workId {
            // 暂停
            audioPlayer?.pause()
            currentPlayingId = nil
        } else {
            // 播放
            stopCurrentAudio()
            let playerItem = AVPlayerItem(url: url)
            audioPlayer = AVPlayer(playerItem: playerItem)
            audioPlayer?.play()
            currentPlayingId = workId
        }
    }

    func stopCurrentAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        currentPlayingId = nil
    }

    // MARK: - 诗词古文 API（使用 creative-works API）

    func loadPoetryWorks(refresh: Bool = false) async {
        if refresh {
            poetryPage = 1
            poetryHasMore = true
            poetryRefreshError = nil
        }

        guard poetryHasMore else { return }

        // 本地缓存优先（仅首次加载时）
        if poetryPage == 1 && !refresh {
            if let cached: [CreativeWorkItem] = CacheService.shared.getCachedPoetryList(type: [CreativeWorkItem].self) {
                poetryWorks = cached
                #if DEBUG
                print("📦 从本地缓存加载诗词古文: \(cached.count) 条")
                #endif
                // 继续从网络加载最新数据
            }
        }

        isLoadingPoetry = true
        defer { isLoadingPoetry = false }

        // 使用 creative-works API，按 poetry 分类筛选
        do {
            var params: [String: String] = [
                "page": "\(poetryPage)",
                "limit": "\(pageSize)",
                "category": "poetry"  // 筛选诗词古文分类（slug）
            ]

            if !poetrySearchText.isEmpty {
                params["search"] = poetrySearchText
            }
            if let poetryType = poetryType {
                params["type"] = poetryType
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.creativeWorksPublic)?\(queryString)"

            #if DEBUG
            print("🌐 加载诗词古文(creative-works): \(APIConfig.baseURL)\(endpoint)")
            #endif

            // 后端返回 { success, data: { works, pagination } } 格式
            let response: APIResponse<CreativeWorksResponse> = try await APIService.shared.get(endpoint)

            guard let data = response.data else {
                #if DEBUG
                print("❌ 诗词古文返回数据为空, error=\(response.error ?? "无")")
                #endif
                poetryRefreshError = "加载失败，请检查网络"
                return
            }

            #if DEBUG
            print("✅ 诗词古文加载成功: \(data.works.count) 条, refresh=\(refresh)")
            for (index, work) in data.works.prefix(3).enumerated() {
                print("  [\(index)] id=\(work.id), title=\(work.title)")
            }
            #endif

            // 刷新时完全替换数据，确保显示最新内容
            if refresh {
                poetryWorks = data.works
                poetryRefreshError = nil
                poetryRefreshId = UUID()
            } else {
                poetryWorks.append(contentsOf: data.works)
            }

            // 缓存到本地（仅第一页）
            if poetryPage == 1 {
                try? CacheService.shared.cachePoetryList(data: poetryWorks)
                #if DEBUG
                print("💾 已缓存诗词古文列表: \(poetryWorks.count) 条")
                #endif
            }

            if let pagination = data.pagination {
                poetryHasMore = poetryPage < pagination.totalPages
            } else {
                poetryHasMore = data.works.count >= pageSize
            }

            poetryPage += 1
        } catch {
            #if DEBUG
            print("❌ 加载诗词古文失败: \(error)")
            if case let APIError.decodingError(decodingError) = error {
                print("  解码错误详情: \(decodingError)")
            }
            #endif
            // 如果网络失败但有缓存，不显示错误
            if poetryWorks.isEmpty {
                poetryRefreshError = "加载失败，请检查网络"
            }
        }
    }

    func togglePoetryLike(_ poetryId: String) async {
        let isCurrentlyLiked = likedPoetryIds.contains(poetryId)

        // 乐观更新
        if isCurrentlyLiked {
            likedPoetryIds.remove(poetryId)
        } else {
            likedPoetryIds.insert(poetryId)
        }

        do {
            let request = PoetryLikeRequest(isLike: !isCurrentlyLiked)
            let _: EmptyResponse = try await APIService.shared.post(
                "\(APIConfig.Endpoints.poetryWorks)/\(poetryId)/like",
                body: request
            )
        } catch {
            // 回滚
            if isCurrentlyLiked {
                likedPoetryIds.insert(poetryId)
            } else {
                likedPoetryIds.remove(poetryId)
            }
            errorMessage = "操作失败"
        }
    }

    func isPoetryLiked(_ poetryId: String) -> Bool {
        likedPoetryIds.contains(poetryId)
    }

    func searchPoetry(_ query: String) async {
        poetrySearchText = query
        await loadPoetryWorks(refresh: true)
    }

    // MARK: - 购物 API

    func loadMarketWorks(refresh: Bool = false) async {
        if refresh {
            marketPage = 1
            marketHasMore = true
        }

        guard marketHasMore else { return }
        isLoadingMarket = true
        defer { isLoadingMarket = false }

        do {
            var params: [String: String] = [
                "page": "\(marketPage)",
                "pageSize": "\(pageSize)",
                "sort": marketSortBy
            ]

            if marketCategory != "all" {
                params["category"] = marketCategory
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.marketWorks)?\(queryString)"

            let response: MarketResponse = try await APIService.shared.get(endpoint)

            if refresh {
                marketWorks = response.works
            } else {
                marketWorks.append(contentsOf: response.works)
            }

            if let pagination = response.pagination {
                marketHasMore = marketPage < pagination.totalPages
            } else {
                marketHasMore = response.works.count >= pageSize
            }

            marketPage += 1
        } catch {
            #if DEBUG
            print("加载市场失败: \(error)")
            #endif
        }
    }

    func loadMyPurchases() async {
        do {
            let response: MarketOrdersResponse = try await APIService.shared.get(
                APIConfig.Endpoints.marketMyPurchases
            )
            myPurchases = response.orders
        } catch {
            #if DEBUG
            print("加载购买记录失败: \(error)")
            #endif
        }
    }

    func purchaseWork(_ workId: String) async -> Bool {
        do {
            let request = PurchaseRequest(workId: workId)
            let _: PurchaseResponse = try await APIService.shared.post(
                "\(APIConfig.Endpoints.marketWorks)/\(workId)/purchase",
                body: request
            )
            await loadMyPurchases()
            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "购买失败"
            return false
        }
    }

    // MARK: - QR 码商品 API

    func loadQRProducts() async {
        isLoadingQR = true
        defer { isLoadingQR = false }

        do {
            var endpoint = "\(APIConfig.Endpoints.payPublicCodes)"
            if !selectedQRCategory.isEmpty {
                endpoint += "?category=\(selectedQRCategory)"
            }

            #if DEBUG
            print("[QR Products] 请求端点: \(endpoint)")
            #endif
            let response: QRCodeProductsResponse = try await APIService.shared.get(endpoint)
            qrProducts = response.codes
            #if DEBUG
            print("[QR Products] 加载成功: \(qrProducts.count) 条")
            #endif
        } catch {
            #if DEBUG
            print("[QR Products] 加载失败: \(error)")
            #endif
            if case let APIError.decodingError(decodingError) = error {
                #if DEBUG
                print("[QR Products] 解码错误详情: \(decodingError)")
                #endif
            }
        }
    }

    func loadQRCategories() async {
        do {
            struct CategoriesResponse: Decodable {
                let categories: [String]
            }
            let response: CategoriesResponse = try await APIService.shared.get(
                "/pay/codes/categories"
            )
            qrCategories = response.categories
        } catch {
            #if DEBUG
            print("加载QR分类失败: \(error)")
            #endif
        }
    }

    // MARK: - 公开日记分析 API（作品广场语义）

    func loadPublicDiaryAnalysis(refresh: Bool = false) async {
        if refresh {
            publicDiaryAnalysisPage = 1
            publicDiaryAnalysisHasMore = true
        }

        guard publicDiaryAnalysisHasMore else { return }
        isLoadingPublicDiaryAnalysis = true
        defer { isLoadingPublicDiaryAnalysis = false }

        do {
            let endpoint = "\(APIConfig.Endpoints.diaryAnalysisPublic)?page=\(publicDiaryAnalysisPage)&limit=\(pageSize)"

            #if DEBUG
            print("🌐 加载公开日记分析: \(APIConfig.baseURL)\(endpoint)")
            #endif

            // 后端返回 { success, data: { records, pagination } } 格式
            let response: APIResponse<PublicDiaryAnalysisResponse> = try await APIService.shared.get(endpoint)

            #if DEBUG
            print("📦 API响应: success=\(response.success ?? false), data=\(response.data != nil ? "有数据" : "无数据")")
            #endif

            guard let data = response.data else {
                #if DEBUG
                print("❌ 公开日记分析返回数据为空, error=\(response.error ?? "无"), message=\(response.message ?? "无")")
                #endif
                return
            }

            #if DEBUG
            print("✅ 公开日记分析加载成功: \(data.records.count) 条, refresh=\(refresh)")
            for (index, record) in data.records.prefix(3).enumerated() {
                print("  [\(index)] id=\(record.id), title=\(record.diaryTitle), isBatch=\(record.isBatch)")
            }
            #endif

            if refresh {
                publicDiaryAnalysis = data.records
                diaryAnalysisRefreshId = UUID()  // 更新刷新标识符，强制 SwiftUI 重新渲染
            } else {
                publicDiaryAnalysis.append(contentsOf: data.records)
            }

            if let pagination = data.pagination {
                publicDiaryAnalysisHasMore = publicDiaryAnalysisPage < pagination.totalPages
            } else {
                publicDiaryAnalysisHasMore = data.records.count >= pageSize
            }

            publicDiaryAnalysisPage += 1
        } catch {
            #if DEBUG
            print("❌ 加载公开日记分析失败: \(error)")
            if case let APIError.decodingError(decodingError) = error {
                print("  解码错误详情: \(decodingError)")
            }
            #endif
        }
    }

    // MARK: - 创意作品 API（动态栏目）

    func loadCreativeWorks(refresh: Bool = false) async {
        if refresh {
            creativeWorksPage = 1
            creativeWorksHasMore = true
        }

        guard creativeWorksHasMore else { return }
        isLoadingCreativeWorks = true
        defer { isLoadingCreativeWorks = false }

        do {
            let endpoint = "\(APIConfig.Endpoints.creativeWorksPublic)?page=\(creativeWorksPage)&pageSize=\(pageSize)"

            #if DEBUG
            print("🌐 加载创意作品: \(endpoint)")
            #endif

            let response: CreativeWorksResponse = try await APIService.shared.get(endpoint)

            #if DEBUG
            print("✅ 创意作品加载成功: \(response.works.count) 条")
            #endif

            if refresh {
                creativeWorks = response.works
            } else {
                creativeWorks.append(contentsOf: response.works)
            }

            if let pagination = response.pagination {
                creativeWorksHasMore = creativeWorksPage < pagination.totalPages
            } else {
                creativeWorksHasMore = response.works.count >= pageSize
            }

            creativeWorksPage += 1
        } catch {
            #if DEBUG
            print("❌ 加载创意作品失败: \(error)")
            #endif
        }
    }

    // MARK: - 书写作品 API

    func loadCalligraphyWorks(refresh: Bool = false, sort: String = "latest", mode: String = "all") async {
        if refresh {
            calligraphyPage = 1
            calligraphyHasMore = true
        }

        guard calligraphyHasMore else { return }
        isLoadingCalligraphy = true
        defer { isLoadingCalligraphy = false }

        do {
            let params: [String: String] = [
                "page": "\(calligraphyPage)",
                "limit": "\(pageSize)",
                "sort": sort
            ]

            let endpoint: String
            if mode == "my" {
                endpoint = "/calligraphy/my"
            } else {
                endpoint = "/calligraphy"
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let fullEndpoint = "\(endpoint)?\(queryString)"

            #if DEBUG
            print("🌐 加载书写作品: \(fullEndpoint)")
            #endif

            let response: CalligraphyListResponse = try await APIService.shared.get(fullEndpoint)

            guard let data = response.data else {
                #if DEBUG
                print("❌ 书写作品返回数据为空")
                #endif
                return
            }

            #if DEBUG
            print("✅ 书写作品加载成功: \(data.works.count) 条")
            #endif

            if refresh {
                calligraphyWorks = data.works
            } else {
                calligraphyWorks.append(contentsOf: data.works)
            }

            calligraphyHasMore = calligraphyPage < data.totalPages
            calligraphyPage += 1
        } catch {
            #if DEBUG
            print("❌ 加载书写作品失败: \(error)")
            #endif
        }
    }

    func toggleCalligraphyLike(_ work: CalligraphyWork) async {
        do {
            let endpoint = "/calligraphy/\(work.id)/like"
            let response: LikeResponse = try await APIService.shared.post(endpoint, body: EmptyRequest())

            if let data = response.data {
                if let index = calligraphyWorks.firstIndex(where: { $0.id == work.id }) {
                    var updatedWork = calligraphyWorks[index]
                    // 由于 CalligraphyWork 是 struct，需要创建新实例
                    // 这里简单刷新列表
                    await loadCalligraphyWorks(refresh: true)
                }
            }
        } catch {
            #if DEBUG
            print("❌ 点赞失败: \(error)")
            #endif
            errorMessage = "操作失败"
        }
    }

    /// 获取书写作品详情（包含完整的 content 和 strokeData）
    func getCalligraphyDetail(_ id: String) async -> CalligraphyWork? {
        do {
            let response: CalligraphyResponse = try await APIService.shared.get("/calligraphy/\(id)")
            return response.data
        } catch {
            #if DEBUG
            print("❌ 获取书写作品详情失败: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - 重置分页

    func resetPagination() {
        // 重置所有分页状态
        galleryPage = 1
        galleryHasMore = true
        recitationPage = 1
        recitationHasMore = true
        poetryPage = 1
        poetryHasMore = true
        marketPage = 1
        marketHasMore = true
        publicDiaryAnalysisPage = 1
        publicDiaryAnalysisHasMore = true
        creativeWorksPage = 1
        creativeWorksHasMore = true
        calligraphyPage = 1
        calligraphyHasMore = true
        // 兼容旧代码
        currentPage = 1
        hasMore = true
    }

    // MARK: - QR 商品支付

    @Published var selectedQRProduct: QRCodeProduct?
    @Published var showQRPaymentSheet = false

    func handleQRPayment(_ product: QRCodeProduct) {
        selectedQRProduct = product
        showQRPaymentSheet = true
    }
}

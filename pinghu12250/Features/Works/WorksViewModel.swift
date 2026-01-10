//
//  WorksViewModel.swift
//  pinghu12250
//
//  作品广场 ViewModel - 画廊/朗诵/唐诗宋词/购物
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

    // MARK: - 唐诗宋词数据

    @Published var poetryWorks: [PoetryWorkData] = []
    @Published var isLoadingPoetry = false
    @Published var poetrySortBy: String = "latest"  // latest, popular
    @Published var poetrySearchText: String = ""
    @Published var cachedPoetryIds: Set<String> = []
    private var likedPoetryIds: Set<String> = []
    private let cacheService = CacheService.shared
    private let offlineManager = OfflineManager.shared

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

    // MARK: - 分页

    @Published var currentPage: Int = 1
    @Published var pageSize: Int = 18
    @Published var hasMore: Bool = true

    // MARK: - 状态

    @Published var errorMessage: String?
    @Published var selectedWork: GalleryWork?
    @Published var selectedRecitation: RecitationWork?
    @Published var selectedPoetry: PoetryWorkData?
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
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoadingGallery = true
        defer { isLoadingGallery = false }

        do {
            var params: [String: String] = [
                "page": "\(currentPage)",
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
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.works.count >= pageSize
            }

            currentPage += 1
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
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoadingRecitation = true
        defer { isLoadingRecitation = false }

        do {
            let params: [String: String] = [
                "page": "\(currentPage)",
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
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.works.count >= pageSize
            }

            currentPage += 1
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

    // MARK: - 唐诗宋词 API

    func loadPoetryWorks(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoadingPoetry = true
        defer { isLoadingPoetry = false }

        // 如果离线模式，先尝试从缓存加载
        if offlineManager.shouldUseOfflineData {
            if let cachedData: [PoetryWorkData] = cacheService.getCachedPoetryList(type: [PoetryWorkData].self) {
                poetryWorks = cachedData
                cachedPoetryIds = Set(cachedData.map { $0.id })
                return
            }
        }

        // 在线模式从网络加载
        do {
            var params: [String: String] = [
                "page": "\(currentPage)",
                "pageSize": "\(pageSize)",
                "sort": poetrySortBy
            ]

            if !poetrySearchText.isEmpty {
                params["search"] = poetrySearchText
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.poetryPublic)?\(queryString)"

            let response: PoetryResponse = try await APIService.shared.get(endpoint)

            if refresh {
                poetryWorks = response.works
            } else {
                poetryWorks.append(contentsOf: response.works)
            }

            if let pagination = response.pagination {
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.works.count >= pageSize
            }

            currentPage += 1

            // 自动缓存第一页数据
            if currentPage == 2 && refresh {
                try? cacheService.cachePoetryList(data: poetryWorks)
            }
        } catch {
            // 网络失败时尝试从缓存加载
            if let cachedData: [PoetryWorkData] = cacheService.getCachedPoetryList(type: [PoetryWorkData].self) {
                poetryWorks = cachedData
                cachedPoetryIds = Set(cachedData.map { $0.id })
            }
            #if DEBUG
            print("加载唐诗宋词失败: \(error)")
            #endif
        }
    }

    /// 缓存单个诗词供离线使用
    func cachePoetryForOffline(_ poetry: PoetryWorkData) async {
        do {
            try cacheService.cachePoetry(poetryId: poetry.id, data: poetry)
            cachedPoetryIds.insert(poetry.id)
        } catch {
            #if DEBUG
            print("缓存诗词失败: \(error)")
            #endif
        }
    }

    /// 缓存诗词（简化调用）
    func cachePoetry(_ poetry: PoetryWorkData) async {
        await cachePoetryForOffline(poetry)
    }

    /// 检查诗词是否已缓存
    func isPoetryCached(_ poetryId: String) -> Bool {
        cacheService.isPoetryCached(poetryId: poetryId)
    }

    /// 获取缓存的诗词
    func getCachedPoetry(_ poetryId: String) -> PoetryWorkData? {
        cacheService.getCachedPoetry(poetryId: poetryId, type: PoetryWorkData.self)
    }

    /// 批量缓存诗词
    func cacheAllPoetryForOffline() async {
        for poetry in poetryWorks {
            await cachePoetryForOffline(poetry)
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
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoadingMarket = true
        defer { isLoadingMarket = false }

        do {
            var params: [String: String] = [
                "page": "\(currentPage)",
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
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.works.count >= pageSize
            }

            currentPage += 1
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

    // MARK: - 重置分页

    func resetPagination() {
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

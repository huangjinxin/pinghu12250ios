//
//  WorksModels.swift
//  pinghu12250
//
//  作品广场数据模型 - 画廊/朗诵/唐诗宋词/购物
//

import Foundation
import SwiftUI

// MARK: - URL 工具

/// 将相对路径转换为完整 URL
func buildFullURL(_ relativePath: String?) -> String? {
    guard let path = relativePath, !path.isEmpty else { return nil }

    // 如果已经是完整 URL，直接返回
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return path
    }

    // 获取服务器基础地址（去掉 /api 后缀）
    let baseURL = ServerConfig.shared.currentURL.replacingOccurrences(of: "/api", with: "")

    // 拼接完整 URL
    if path.hasPrefix("/") {
        return baseURL + path
    } else {
        return baseURL + "/" + path
    }
}

// MARK: - 作者信息

struct WorkAuthor: Codable {
    let id: String
    let username: String
    let nickname: String?
    let avatar: String?

    var displayName: String {
        nickname ?? username
    }

    var avatarLetter: String {
        String((nickname ?? username).prefix(1))
    }
}

// MARK: - 画廊作品

struct GalleryWork: Codable, Identifiable {
    let id: String
    let image: String?
    let images: [String]?
    let content: String?
    let author: WorkAuthor?
    let template: GalleryTemplate?
    let createdAt: String?

    var displayImage: String? {
        image ?? images?.first
    }

    /// 完整的显示图片 URL（自动添加服务器地址）
    var fullImageURL: String? {
        buildFullURL(displayImage)
    }

    var allImages: [String] {
        if let images = images, !images.isEmpty {
            return images
        }
        if let image = image {
            return [image]
        }
        return []
    }

    /// 所有图片的完整 URL
    var allFullImageURLs: [String] {
        allImages.compactMap { buildFullURL($0) }
    }
}

struct GalleryTemplate: Codable {
    let id: String
    let name: String
    let type: GalleryType?
    let standard: GalleryStandard?
}

struct GalleryType: Codable, Identifiable {
    let id: String
    let name: String
}

struct GalleryStandard: Codable, Identifiable {
    let id: String
    let name: String
}

struct GalleryResponse: Decodable {
    let works: [GalleryWork]
    let pagination: PaginationInfo?
}

struct GalleryDetailResponse: Decodable {
    let work: GalleryWork
}

struct GalleryTypesResponse: Decodable {
    let types: [GalleryType]
}

struct GalleryStandardsResponse: Decodable {
    let standards: [GalleryStandard]
}

// MARK: - 朗诵作品

struct RecitationWork: Codable, Identifiable {
    let id: String
    let audio: String?
    let audios: [String]?
    let content: String?
    let author: WorkAuthor?
    let template: GalleryTemplate?
    let createdAt: String?

    var displayAudio: String? {
        audio ?? audios?.first
    }

    /// 完整的显示音频 URL
    var fullAudioURL: String? {
        buildFullURL(displayAudio)
    }

    var allAudios: [String] {
        if let audios = audios, !audios.isEmpty {
            return audios
        }
        if let audio = audio {
            return [audio]
        }
        return []
    }

    /// 所有音频的完整 URL
    var allFullAudioURLs: [String] {
        allAudios.compactMap { buildFullURL($0) }
    }
}

struct RecitationResponse: Decodable {
    let works: [RecitationWork]
    let pagination: PaginationInfo?
}

struct RecitationDetailResponse: Decodable {
    let work: RecitationWork
}

// MARK: - 唐诗宋词作品

struct PoetryWorkData: Codable, Identifiable {
    let id: String
    let title: String
    let htmlCode: String?
    let coverImage: String?  // 封面图片路径
    let status: String?
    let reviewReason: String?
    let createdAt: String?
    let updatedAt: String?
    let authorId: String?
    let author: WorkAuthor?
    let likesCount: Int?

    var isApproved: Bool {
        status == "APPROVED"
    }

    /// 完整的封面图片 URL
    var fullCoverImageURL: String? {
        buildFullURL(coverImage)
    }
}

struct PoetryResponse: Decodable {
    let works: [PoetryWorkData]
    let pagination: PaginationInfo?
}

struct PoetryDetailResponse: Decodable {
    let work: PoetryWorkData
}

struct PoetryLikeRequest: Encodable {
    let isLike: Bool
}

// MARK: - 市场商品

struct MarketWork: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let price: Double
    let seller: WorkAuthor?
    let htmlContent: String?
    let cssContent: String?
    let jsContent: String?
    let sales: Int?
    let isExclusive: Bool?
    let createdAt: String?
}

struct MarketResponse: Decodable {
    let works: [MarketWork]
    let pagination: PaginationInfo?
}

struct MarketDetailResponse: Decodable {
    let work: MarketWork
}

struct PurchaseRequest: Encodable {
    let workId: String
}

struct PurchaseResponse: Decodable {
    let order: MarketOrder?
    let message: String?
}

struct MarketOrder: Codable, Identifiable {
    let id: String
    let workId: String
    let buyerId: String
    let price: Double
    let status: String?
    let createdAt: String?
    let work: MarketWork?
}

struct MarketOrdersResponse: Decodable {
    let orders: [MarketOrder]
    let pagination: PaginationInfo?
}

// MARK: - QR 码商品（扫码支付）

struct QRCodeProduct: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let description: String?
    let category: String?
    let qrcode: String?
    let createdAt: String?

    // amount 使用通用的 FlexibleDouble（定义在 Core/Models/CommonTypes.swift）
    private let _amount: FlexibleDouble

    var amount: Double {
        _amount.value
    }

    /// 完整的二维码图片 URL
    var fullQRCodeURL: String? {
        // qrcode 是 base64 data URL，直接返回
        qrcode
    }

    enum CodingKeys: String, CodingKey {
        case id, code, title, description, category, qrcode, createdAt
        case _amount = "amount"
    }
}

// 注意: AmountValue 已被 FlexibleDouble (Core/Models/CommonTypes.swift) 替代

struct QRCodeProductsResponse: Decodable {
    let codes: [QRCodeProduct]
    let pagination: PaginationInfo?
}

struct QRCategoriesResponse: Decodable {
    let categories: [String]
}

// MARK: - 排行榜

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let nickname: String?
    let avatar: String?
    let value: Double  // 销售额或销量
    let rank: Int

    var displayName: String {
        nickname ?? username
    }
}

struct LeaderboardResponse: Decodable {
    let entries: [LeaderboardEntry]
}

//
//  CommonTypes.swift
//  pinghu12250
//
//  通用类型定义 - 供多个模块共用
//
//  注意: 此文件包含跨模块共享的基础类型
//  Feature 层不应定义这些类型，应统一引用此文件
//

import Foundation

// MARK: - 分页信息

/// 通用分页信息
struct PaginationInfo: Codable {
    let page: Int
    let total: Int
    let totalPages: Int
    // 兼容 pageSize 和 limit 两种字段名
    let pageSize: Int?
    let limit: Int?

    var actualPageSize: Int {
        pageSize ?? limit ?? 20
    }

    enum CodingKeys: String, CodingKey {
        case page, total, totalPages, pageSize, limit
    }
}

// MARK: - 上传响应

/// 文件上传响应
struct UploadResponse: Decodable {
    let url: String
    let filename: String?
    let size: Int?
}

// MARK: - 通用消息响应

/// 通用消息响应（用于只返回 message 的 API）
struct MessageResponse: Decodable {
    let message: String
}

// MARK: - 灵活数值类型

/// 支持从字符串或数字解析的 Double
/// 用于处理后端返回的数值可能是字符串或数字的情况
struct FlexibleDouble: Codable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self),
                  let doubleFromString = Double(stringValue) {
            value = doubleFromString
        } else if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - 简化用户信息

/// 简化的用户信息（用于列表展示等场景）
struct SimpleUser: Codable {
    let id: String
    let username: String
    let avatar: String?
}

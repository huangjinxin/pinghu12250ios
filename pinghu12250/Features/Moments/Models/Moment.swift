//
//  Moment.swift
//  pinghu12250
//
//  朋友圈数据模型
//

import Foundation

struct Moment: Identifiable {
    let id: String
    let userName: String
    let content: String
    let timestamp: Date
    let likes: Int
    let comments: Int

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

//
//  Date+Extensions.swift
//  pinghu12250
//
//  日期扩展
//

import Foundation

extension Date {
    /// 相对时间描述（如：刚刚、5分钟前、昨天）
    var relativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 172800 {
            return "昨天"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: self)
        }
    }

    /// 相对时间描述（使用系统 RelativeDateTimeFormatter，中文本地化）
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// 格式化为标准日期字符串
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }

    /// 格式化为日期时间字符串
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
}

// MARK: - String 日期解析扩展

extension String {
    /// 解析 ISO8601 日期字符串为 Date
    var toDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date
        }
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }

    /// 获取日期字符串的相对描述
    var relativeDescription: String {
        toDate?.relativeDescription ?? self
    }
}

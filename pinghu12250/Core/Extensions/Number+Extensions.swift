//
//  Number+Extensions.swift
//  pinghu12250
//
//  数值类型扩展
//

import Foundation

// MARK: - TimeInterval 扩展

extension TimeInterval {
    /// 格式化为人类可读的时长（如：5分30秒）
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        }
        return "\(seconds)秒"
    }
}

// MARK: - Double 扩展

extension Double {
    /// 格式化为百分比字符串
    var percentageString: String {
        return String(format: "%.0f%%", self * 100)
    }
}

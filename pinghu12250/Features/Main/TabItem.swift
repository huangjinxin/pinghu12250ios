//
//  TabItem.swift
//  pinghu12250
//
//  Tab 项目枚举
//

import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case messages
    case contacts
    case moments
    case profile

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .messages: return "message.fill"
        case .contacts: return "book.fill"
        case .moments: return "globe.asia.australia.fill"
        case .profile: return "person.fill"
        }
    }

    var title: String {
        switch self {
        case .messages: return "消息"
        case .contacts: return "通讯录"
        case .moments: return "学习圈"
        case .profile: return "我的"
        }
    }
}

//
//  ParentModeKey.swift
//  pinghu12250
//
//  家长模式环境变量
//

import SwiftUI

// MARK: - 家长模式环境键

/// 是否处于家长模式
struct ParentModeKey: EnvironmentKey {
    static let defaultValue = false
}

/// 当前查看的孩子ID
struct ViewingChildIdKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

/// 当前查看的孩子信息
struct ViewingChildKey: EnvironmentKey {
    static let defaultValue: Child? = nil
}

extension EnvironmentValues {
    /// 是否处于家长模式（只读）
    var parentMode: Bool {
        get { self[ParentModeKey.self] }
        set { self[ParentModeKey.self] = newValue }
    }

    /// 当前查看的孩子ID
    var viewingChildId: String? {
        get { self[ViewingChildIdKey.self] }
        set { self[ViewingChildIdKey.self] = newValue }
    }

    /// 当前查看的孩子信息
    var viewingChild: Child? {
        get { self[ViewingChildKey.self] }
        set { self[ViewingChildKey.self] = newValue }
    }
}

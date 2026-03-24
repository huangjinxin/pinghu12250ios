//
//  ContactSelection.swift
//  pinghu12250
//
//  通讯录选中状态
//

import Foundation

enum ContactSelection: Equatable, Hashable {
    case none
    case addFriend
    case newFriends
    case aiTeachers
    case friend(User)

    static func == (lhs: ContactSelection, rhs: ContactSelection) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.addFriend, .addFriend): return true
        case (.newFriends, .newFriends): return true
        case (.aiTeachers, .aiTeachers): return true
        case (.friend(let a), .friend(let b)): return a.id == b.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .none: hasher.combine(0)
        case .addFriend: hasher.combine(1)
        case .newFriends: hasher.combine(2)
        case .aiTeachers: hasher.combine(3)
        case .friend(let u): hasher.combine(4); hasher.combine(u.id)
        }
    }
}

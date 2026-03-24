//
//  IMRouteState.swift
//  pinghu12250
//
//  IM 路由状态
//

import Foundation

enum IMRouteState: Equatable {
    case idle
    case openingConversation(userId: String)
    case failed(String)

    static func == (lhs: IMRouteState, rhs: IMRouteState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.openingConversation(let a), .openingConversation(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

//
//  MessageSelection.swift
//  pinghu12250
//
//  消息页通知名定义
//

import Foundation

extension Notification.Name {
    static let openConversation = Notification.Name("OpenConversation")
    static let openBotConversation = Notification.Name("OpenBotConversation")
    static let friendAdded = Notification.Name("FriendAdded")
    static let messageSent = Notification.Name("MessageSent")
    static let imIncomingBanner = Notification.Name("IMIncomingBanner")
    static let switchToGrowthTab = Notification.Name("SwitchToGrowthTab")
}

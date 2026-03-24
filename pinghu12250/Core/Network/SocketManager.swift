//
//  SocketManager.swift
//  pinghu12250
//
//  Socket.IO连接管理器
//

import Foundation
import Combine
import SocketIO

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticated
    case failed(Error)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.authenticated, .authenticated):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

class SocketManager: ObservableObject {
    static let shared = SocketManager()

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    @Published var connectionState: ConnectionState = .disconnected
    @Published var isConnected = false

    // 事件回调
    private var onNewMessageHandler: ((IMMessage) -> Void)?
    private var onMessageAckHandler: ((SocketMessageResponse) -> Void)?
    private var onSyncResultHandler: (([IMMessage]) -> Void)?

    private init() {}

    // MARK: - 连接管理

    func connect(token: String) {
        guard connectionState == .disconnected else {
            print("[Socket] ⚠️ 已经连接或正在连接中")
            return
        }

        print("[Socket] 🔌 开始连接...")
        connectionState = .connecting

        let socketURL = URL(string: APIConfig.socketURL)!
        print("[Socket] 📍 URL: \(socketURL)")

        manager = SocketIO.SocketManager(
            socketURL: socketURL,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .connectParams(["token": token]),
                .version(.three)
            ]
        )

        socket = manager?.defaultSocket

        setupEventHandlers()

        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            print("[Socket] ✅ 握手连接成功")
            self?.connectionState = .authenticated
            self?.isConnected = true
        }

        socket?.on(clientEvent: .error) { [weak self] data, _ in
            print("[Socket] ❌ 连接错误: \(data)")
            let error = NSError(domain: "SocketConnect", code: 500, userInfo: [NSLocalizedDescriptionKey: "连接错误"])
            self?.connectionState = .failed(error)
            self?.isConnected = false
        }

        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        manager = nil
        socket = nil
        connectionState = .disconnected
        isConnected = false
    }

    // MARK: - 事件发送

    func sendMessage(toUserId: String, content: String, tempId: String) {
        socket?.emit("send_message", [
            "toUserId": toUserId,
            "content": content,
            "tempId": tempId
        ])
    }

    func syncMessages(lastMessageId: String) {
        socket?.emit("sync_messages", [
            "lastMessageId": lastMessageId
        ])
    }

    // MARK: - 事件监听

    private func setupEventHandlers() {
        // 新消息
        socket?.on("new_message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let message = try? JSONDecoder().decode(IMMessage.self, from: jsonData) else {
                return
            }
            self?.onNewMessageHandler?(message)
        }

        // 消息发送确认
        socket?.on("message_sent") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let response = try? JSONDecoder().decode(SocketMessageResponse.self, from: jsonData) else {
                return
            }
            self?.onMessageAckHandler?(response)
        }

        // 同步结果
        socket?.on("sync_result") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let messagesArray = dict["messages"] as? [[String: Any]],
                  let jsonData = try? JSONSerialization.data(withJSONObject: messagesArray),
                  let messages = try? JSONDecoder().decode([IMMessage].self, from: jsonData) else {
                return
            }
            self?.onSyncResultHandler?(messages)
        }

        // 断开连接
        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.isConnected = false
            self?.connectionState = .disconnected
        }
    }

    // MARK: - 注册回调

    func onNewMessage(_ handler: @escaping (IMMessage) -> Void) {
        onNewMessageHandler = handler
    }

    func onMessageAck(_ handler: @escaping (SocketMessageResponse) -> Void) {
        onMessageAckHandler = handler
    }

    func onSyncResult(_ handler: @escaping ([IMMessage]) -> Void) {
        onSyncResultHandler = handler
    }
}

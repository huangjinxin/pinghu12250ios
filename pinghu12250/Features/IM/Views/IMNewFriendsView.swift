//
//  IMNewFriendsView.swift
//  pinghu12250
//
//  新的朋友 - 好友申请列表
//

import SwiftUI

struct FriendRequest: Identifiable, Decodable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: String
    let createdAt: String
    let fromUser: UserInfo?
    let toUser: UserInfo?

    struct UserInfo: Decodable {
        let id: String
        let username: String
        let avatar: String?
    }
}

struct IMNewFriendsView: View {
    @State private var receivedRequests: [FriendRequest] = []
    @State private var sentRequests: [FriendRequest] = []
    @State private var isLoading = false
    @State private var processingId: String?

    var body: some View {
        List {
            if !receivedRequests.isEmpty {
                Section("收到的申请") {
                    ForEach(receivedRequests) { request in
                        ReceivedRequestRow(
                            request: request,
                            isProcessing: processingId == request.id,
                            onAccept: { await acceptRequest(request.id) },
                            onReject: { await rejectRequest(request.id) },
                            onStartChat: { IMNavigationHelper.openFriendChat(userId: request.fromUserId) }
                        )
                    }
                }
            }

            if !sentRequests.isEmpty {
                Section("发出的申请") {
                    ForEach(sentRequests) { request in
                        SentRequestRow(request: request) {
                            IMNavigationHelper.openFriendChat(userId: request.toUserId)
                        }
                    }
                }
            }

            if receivedRequests.isEmpty && sentRequests.isEmpty && !isLoading {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text("暂无好友申请")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .navigationTitle("新的朋友")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRequests()
        }
        .refreshable {
            await loadRequests()
        }
    }

    private func loadRequests() async {
        isLoading = true
        do {
            async let received = fetchReceivedRequests()
            async let sent = fetchSentRequests()
            (receivedRequests, sentRequests) = try await (received, sent)
        } catch {
            print("加载好友申请失败: \(error)")
        }
        isLoading = false
    }

    private func fetchReceivedRequests() async throws -> [FriendRequest] {
        let response: APIResponse<[FriendRequest]> = try await APIService.shared.get("/api/friend-requests/received")
        return response.data ?? []
    }

    private func fetchSentRequests() async throws -> [FriendRequest] {
        let response: APIResponse<[FriendRequest]> = try await APIService.shared.get("/api/friend-requests/sent")
        return response.data ?? []
    }

    private func acceptRequest(_ requestId: String) async {
        processingId = requestId
        do {
            let _: APIResponse<String?> = try await APIService.shared.post("/api/friend-requests/\(requestId)/accept")
            IMNavigationHelper.notifyFriendAdded()
            await loadRequests()
        } catch {
            print("接受好友失败: \(error)")
        }
        processingId = nil
    }

    private func rejectRequest(_ requestId: String) async {
        processingId = requestId
        do {
            let _: APIResponse<String?> = try await APIService.shared.post("/api/friend-requests/\(requestId)/reject")
            await loadRequests()
        } catch {
            print("拒绝好友失败: \(error)")
        }
        processingId = nil
    }
}

struct ReceivedRequestRow: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onAccept: () async -> Void
    let onReject: () async -> Void
    let onStartChat: () -> Void

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: request.fromUser?.avatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(request.fromUser?.username ?? "")
                .font(.system(size: 16))

            Spacer()

            if request.status == "PENDING" {
                if isProcessing {
                    ProgressView().controlSize(.small)
                } else {
                    HStack(spacing: 8) {
                        Button("接受") {
                            Task { await onAccept() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("拒绝") {
                            Task { await onReject() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else if request.status == "ACCEPTED" {
                Button("发消息") {
                    onStartChat()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("已拒绝").foregroundColor(.gray).font(.caption)
            }
        }
    }
}

struct SentRequestRow: View {
    let request: FriendRequest
    let onStartChat: () -> Void

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: request.toUser?.avatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(request.toUser?.username ?? "")
                .font(.system(size: 16))

            Spacer()

            if request.status == "PENDING" {
                Text("等待验证").foregroundColor(.orange).font(.caption)
            } else if request.status == "ACCEPTED" {
                Button("发消息") {
                    onStartChat()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("已拒绝").foregroundColor(.gray).font(.caption)
            }
        }
    }
}

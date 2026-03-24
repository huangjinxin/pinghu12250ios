//
//  FriendViewModel.swift
//  pinghu12250
//
//  好友列表业务逻辑
//

import Foundation
import Combine

class FriendViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadFriends() async {
        await MainActor.run { isLoading = true }

        do {
            let loadedFriends = try await FriendService.shared.getFriends()
            await MainActor.run {
                friends = loadedFriends
                errorMessage = nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

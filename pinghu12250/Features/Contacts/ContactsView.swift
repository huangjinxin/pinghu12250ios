//
//  ContactsView.swift
//  pinghu12250
//
//  通讯录视图
//

import SwiftUI

struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @State private var searchText = ""
    @State private var showAddFriend = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: IMNewFriendsView()) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                            .frame(width: 40, height: 40)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Circle())
                        Text("新的朋友")
                    }
                }
            }

            if !vm.aiAssistants.isEmpty {
                Section("AI老师") {
                    ForEach(vm.aiAssistants) { contact in
                        ContactRowView(contact: contact)
                    }
                }
            }

            Section("好友") {
                ForEach(vm.friends) { friend in
                    NavigationLink(destination: IMChatView(friendUserId: friend.id, friendName: friend.username)) {
                        HStack {
                            AsyncImage(url: URL(string: friend.avatar ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            Text(friend.username)
                                .font(.system(size: 16))
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索联系人")
        .navigationTitle("通讯录")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            IMAddFriendView()
        }
        .task {
            vm.loadContacts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendAdded"))) { _ in
            vm.loadContacts()
        }
        .refreshable {
            vm.loadContacts()
        }
    }
}

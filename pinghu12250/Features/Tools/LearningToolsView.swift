//
//  LearningToolsView.swift
//  pinghu12250
//
//  学习工具列表
//

import SwiftUI

struct LearningToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOfflineDiary = false
    @State private var showSpaceWeb = false

    var body: some View {
        NavigationView {
            List {
                Button {
                    showOfflineDiary = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("写日记")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                            Text("离线记录，随时随地")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Button {
                    showSpaceWeb = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.green)
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("空间web")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                            Text("访问完整网页版")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("学习工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showOfflineDiary) {
                OfflineDiaryView()
            }
            .fullScreenCover(isPresented: $showSpaceWeb) {
                SpaceWebView()
            }
        }
    }
}

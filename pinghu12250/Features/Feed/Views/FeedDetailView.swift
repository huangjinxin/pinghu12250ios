//
//  FeedDetailView.swift
//  pinghu12250
//
//  学习圈动态详情
//

import SwiftUI

struct FeedDetailView: View {
    let item: UnifiedFeedItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 作者区域
                HStack(spacing: 12) {
                    // 头像
                    if let avatar = item.author.avatar, let url = URL(string: avatar.hasPrefix("http") ? avatar : APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + avatar) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color(hex: "E5E7EB")).overlay(
                                Text(String(item.author.name.prefix(1)))
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            )
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color(hex: "E5E7EB"))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(String(item.author.name.prefix(1)))
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.author.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "576B95"))
                        HStack(spacing: 8) {
                            Text(item.formattedTime)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(item.type.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "10B981"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "10B981").opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()

                    if let mood = item.mood {
                        Text(MoodHelper.emoji(for: mood))
                            .font(.system(size: 24))
                    }
                }
                .padding(16)

                // 标题
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                // 正文
                if let content = item.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                // 图片（保持比例展示）
                if let images = item.images, !images.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(images, id: \.self) { path in
                            AsyncImage(url: ImageURLHelper.fullURL(path)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(8)
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 200)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } else if let preview = item.preview {
                    AsyncImage(url: ImageURLHelper.fullURL(preview)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                        default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // 互动
                Divider().padding(.horizontal, 16)
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 16))
                            .foregroundColor(.pink)
                        Text("\(item.likesCount ?? 0)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Text("\(item.commentsCount ?? 0)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .background(Color.white)
    }
}

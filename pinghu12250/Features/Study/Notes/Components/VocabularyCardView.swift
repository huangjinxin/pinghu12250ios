//
//  VocabularyCardView.swift
//  pinghu12250
//
//  生词卡片组件
//  显示单个生字/词，支持米字格/田字格显示
//  点击展开显示详情和操作按钮
//

import SwiftUI

/// 生词卡片视图
struct VocabularyCardView: View {
    /// 笔记数据
    let note: ReadingNote
    /// 格子类型
    var gridType: GridType = .mi
    /// 是否选中
    var isSelected: Bool = false
    /// 练习记录数量
    var practiceCount: Int = 0

    /// 点击回调
    var onTap: (() -> Void)?
    /// 开始练习回调
    var onPractice: (() -> Void)?
    /// 收藏回调
    var onFavorite: (() -> Void)?
    /// 删除回调
    var onDelete: (() -> Void)?
    /// 查看详情回调
    var onViewDetail: (() -> Void)?

    // MARK: - 计算属性

    /// 从笔记提取字符
    private var character: String {
        note.query ?? contentDict?["character"] as? String ?? "字"
    }

    /// 从笔记提取拼音
    private var pinyin: String? {
        contentDict?["pinyin"] as? String
    }

    /// 从笔记提取释义
    private var definition: String? {
        contentDict?["definition"] as? String ?? contentDict?["meaning"] as? String
    }

    /// 从笔记提取组词
    private var words: [String]? {
        contentDict?["words"] as? [String] ?? contentDict?["compounds"] as? [String]
    }

    /// 从笔记提取笔顺
    private var strokeOrder: String? {
        contentDict?["strokeOrder"] as? String
    }

    /// 是否收藏
    private var isFavorite: Bool {
        note.isFavorite ?? false
    }

    /// 解析content为字典
    private var contentDict: [String: Any]? {
        guard let content = note.content else { return nil }
        if let dict = content.value as? [String: Any] {
            return dict
        }
        if let str = content.value as? String,
           let data = str.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 左侧：米字格 + 拼音
            VStack(spacing: 3) {
                MiTianGridView(
                    character: character,
                    gridType: gridType,
                    size: 50
                )

                // 拼音
                if let pinyin = pinyin {
                    Text(pinyin)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 54)

            // 右侧：释义 + 操作按钮
            VStack(alignment: .leading, spacing: 6) {
                // 释义（显示在右上方）
                if let definition = definition {
                    Text(definition)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 操作按钮行
                HStack(spacing: 6) {
                    // 书写练习按钮
                    Button {
                        onPractice?()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 10))
                            Text("练习")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }

                    // 练习记录
                    if practiceCount > 0 {
                        Button {
                            onViewDetail?()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text("\(practiceCount)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                    }

                    Spacer()

                    // 更多操作菜单
                    moreButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 选中状态指示器
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - 更多按钮

    private var moreButton: some View {
        Menu {
            // 收藏
            Button {
                onFavorite?()
            } label: {
                Label(
                    isFavorite ? "取消收藏" : "收藏",
                    systemImage: isFavorite ? "heart.fill" : "heart"
                )
            }

            Divider()

            // 删除
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 22)
                .background(Color(.systemGray5))
                .cornerRadius(11)
        }
    }

    // MARK: - 卡片背景色

    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.green.opacity(0.08)
        } else {
            return Color(.systemBackground)
        }
    }

    // MARK: - 卡片边框色

    private var cardBorderColor: Color {
        if isSelected {
            return .green
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - 预览

#Preview("生词卡片") {
    ScrollView {
        VStack(spacing: 8) {
            VocabularyCardView(
                note: ReadingNote(
                    id: "1",
                    userId: "user1",
                    textbookId: nil,
                    sessionId: nil,
                    sourceType: "dict",
                    query: "春",
                    content: AnyCodable([
                        "pinyin": "chūn",
                        "definition": "一年的第一个季节，万物复苏的时候",
                        "words": ["春天", "春风", "春节", "春雨"]
                    ]),
                    snippet: nil,
                    page: nil,
                    isFavorite: false,
                    favoriteAt: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    textbook: nil,
                    chapterId: nil,
                    paragraphId: nil,
                    textRange: nil
                ),
                gridType: .mi,
                practiceCount: 3
            )

            VocabularyCardView(
                note: ReadingNote(
                    id: "2",
                    userId: "user1",
                    textbookId: nil,
                    sessionId: nil,
                    sourceType: "dict",
                    query: "夏",
                    content: AnyCodable([
                        "pinyin": "xià",
                        "definition": "一年的第二个季节",
                        "words": ["夏天", "夏日"]
                    ]),
                    snippet: nil,
                    page: nil,
                    isFavorite: true,
                    favoriteAt: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    textbook: nil,
                    chapterId: nil,
                    paragraphId: nil,
                    textRange: nil
                ),
                gridType: .mi,
                practiceCount: 1
            )

            VocabularyCardView(
                note: ReadingNote(
                    id: "3",
                    userId: "user1",
                    textbookId: nil,
                    sessionId: nil,
                    sourceType: "dict",
                    query: "秋",
                    content: AnyCodable([
                        "pinyin": "qiū",
                        "definition": "一年的第三个季节"
                    ]),
                    snippet: nil,
                    page: nil,
                    isFavorite: false,
                    favoriteAt: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    textbook: nil,
                    chapterId: nil,
                    paragraphId: nil,
                    textRange: nil
                ),
                gridType: .tian
            )
        }
        .padding()
    }
    .background(Color(.systemGray6))
}

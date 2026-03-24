//
//  LeaderboardCard.swift
//  pinghu12250
//
//  排行榜卡片
//

import SwiftUI

struct LeaderboardItem: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let value: Int
    let label: String
}

struct LeaderboardCard: View {
    let icon: String
    let title: String
    let items: [LeaderboardItem]
    let color: Color
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            Button(action: onTap) {
                HStack {
                    Text(icon).font(.system(size: 18))
                    Text(title).font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("详情 →").font(.system(size: 12)).foregroundColor(.blue)
                }
                .padding(14)
                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            }

            Divider()

            // 排行列表
            VStack(spacing: 8) {
                if items.isEmpty {
                    Text("暂无数据").font(.system(size: 13)).foregroundColor(.secondary).padding(20)
                } else {
                    ForEach(items.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Text("\(item.rank)").font(.system(size: 12, weight: .bold))
                                .foregroundColor(item.rank <= 3 ? .orange : .secondary)
                                .frame(width: 18)

                            Text(item.name).font(.system(size: 13)).lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 6)
                                    Rectangle().fill(color).frame(width: geo.size.width * percent(item), height: 6)
                                }
                                .cornerRadius(3)
                            }
                            .frame(height: 6)

                            Text("\(item.value)\(item.label)").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private func percent(_ item: LeaderboardItem) -> CGFloat {
        guard let maxItem = items.first, maxItem.value > 0 else { return 0.05 }
        return Swift.max(0.05, CGFloat(item.value) / CGFloat(maxItem.value))
    }
}

//
//  NotesWidget.swift
//  pinghu12250
//
//  笔记小组件 - 显示最近笔记
//  注意：此文件需要添加到 Widget Extension 目标
//

import SwiftUI
import WidgetKit

// MARK: - Widget Timeline Provider

struct NotesWidgetProvider: TimelineProvider {
    typealias Entry = NotesWidgetEntry

    func placeholder(in context: Context) -> NotesWidgetEntry {
        NotesWidgetEntry(
            date: Date(),
            notes: [
                WidgetNote(
                    id: "placeholder",
                    title: "示例笔记",
                    content: "这是一条笔记内容...",
                    type: "text",
                    textbookName: "语文",
                    pageIndex: 1,
                    isFavorite: false,
                    updatedAt: Date()
                )
            ],
            totalCount: 1,
            configuration: .default
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesWidgetEntry) -> Void) {
        let entry = NotesWidgetDataProvider.shared.getEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesWidgetEntry>) -> Void) {
        let entry = NotesWidgetDataProvider.shared.getEntry()

        // 每30分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget 视图

struct NotesWidgetEntryView: View {
    var entry: NotesWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        default:
            smallWidgetView
        }
    }

    // MARK: - 小尺寸

    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.appPrimary)
                Text("我的笔记")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()

            if let note = entry.notes.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Text(note.textbookName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("暂无笔记")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 总数
            Text("\(entry.totalCount) 条笔记")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - 中尺寸

    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.appPrimary)
                Text("最近笔记")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(entry.totalCount) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 笔记列表
            if entry.notes.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.notes.prefix(3)) { note in
                        noteRow(note)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - 大尺寸

    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "note.text")
                    .font(.title3)
                    .foregroundColor(.appPrimary)
                Text("我的笔记")
                    .font(.headline)
                Spacer()
                Text("\(entry.totalCount) 条笔记")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 笔记列表
            if entry.notes.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无笔记")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.notes.prefix(5)) { note in
                        noteCard(note)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - 笔记行

    private func noteRow(_ note: WidgetNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: note.typeIcon)
                .font(.caption)
                .foregroundColor(.appPrimary)

            Text(note.displayTitle)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if note.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            Text(note.textbookName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 笔记卡片

    private func noteCard(_ note: WidgetNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: note.typeIcon)
                    .font(.caption)
                    .foregroundColor(.appPrimary)

                Text(note.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Text(note.textbookName)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let page = note.pageIndex {
                    Text("P\(page + 1)")
                        .font(.caption2)
                        .foregroundColor(.appPrimary)
                }

                Spacer()

                Text(note.updatedAt.relativeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Widget 配置

// @main  // 注意：Widget Extension 需要取消注释此行
struct NotesWidget: Widget {
    let kind: String = "NotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesWidgetProvider()) { entry in
            NotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("我的笔记")
        .description("快速查看最近的学习笔记")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - 预览

#if DEBUG
struct NotesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = NotesWidgetEntry(
            date: Date(),
            notes: [
                WidgetNote(
                    id: "1",
                    title: "古诗词背诵",
                    content: "春眠不觉晓，处处闻啼鸟...",
                    type: "text",
                    textbookName: "语文 三年级上",
                    pageIndex: 10,
                    isFavorite: true,
                    updatedAt: Date()
                ),
                WidgetNote(
                    id: "2",
                    title: "",
                    content: "乘法口诀表：二二得四，二三得六...",
                    type: "summary",
                    textbookName: "数学 三年级上",
                    pageIndex: 25,
                    isFavorite: false,
                    updatedAt: Date().addingTimeInterval(-3600)
                ),
                WidgetNote(
                    id: "3",
                    title: "单词笔记",
                    content: "apple: 苹果\nbanana: 香蕉",
                    type: "text",
                    textbookName: "英语 三年级上",
                    pageIndex: 5,
                    isFavorite: false,
                    updatedAt: Date().addingTimeInterval(-7200)
                )
            ],
            totalCount: 15,
            configuration: .default
        )

        Group {
            NotesWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            NotesWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            NotesWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
#endif

// 注意: Date.relativeDescription 已在 Date+Extensions.swift 中定义

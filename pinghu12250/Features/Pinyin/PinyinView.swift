//
//  PinyinView.swift
//  pinghu12250
//
//  拼音学习
//

import SwiftUI

struct PinyinView: View {
    @StateObject private var viewModel = PinyinViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("练习").tag(0)
                Text("记录").tag(1)
                Text("排行榜").tag(2)
                Text("声韵调").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                PinyinInputTab(viewModel: viewModel).tag(0)
                PinyinRecordsTab(viewModel: viewModel).tag(1)
                PinyinLeaderboardTab(viewModel: viewModel).tag(2)
                PinyinChartTab().tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("拼音学习")
    }
}

// MARK: - 练习输入
private struct PinyinInputTab: View {
    @ObservedObject var viewModel: PinyinViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("输入汉字文本，系统将生成拼音供练习")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $viewModel.inputText)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)

                Button {
                    Task { await viewModel.convertText() }
                } label: {
                    if viewModel.isConverting {
                        ProgressView().tint(.white)
                    } else {
                        Text("开始练习")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(viewModel.inputText.isEmpty || viewModel.isConverting)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $viewModel.showPractice) {
            PinyinPracticeSheet(viewModel: viewModel)
        }
    }
}

// MARK: - 练习记录
private struct PinyinRecordsTab: View {
    @ObservedObject var viewModel: PinyinViewModel

    var body: some View {
        List {
            if let stats = viewModel.stats {
                Section {
                    HStack {
                        Text("总练习")
                        Spacer()
                        Text("\(stats.allTime.totalPractices)次")
                    }
                    HStack {
                        Text("总字数")
                        Spacer()
                        Text("\(stats.allTime.totalChars)字")
                    }
                    HStack {
                        Text("平均正确率")
                        Spacer()
                        Text(String(format: "%.1f%%", stats.allTime.avgAccuracy))
                    }
                }
            }

            Section {
                ForEach(viewModel.records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.system(size: 15))
                        HStack {
                            Text("\(record.charCount)字")
                            Text(String(format: "%.1f%%", record.accuracy))
                            Text("\(record.duration)秒")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadRecords()
        }
    }
}

// MARK: - 排行榜
private struct PinyinLeaderboardTab: View {
    @ObservedObject var viewModel: PinyinViewModel

    var body: some View {
        VStack {
            Picker("", selection: $viewModel.selectedPeriod) {
                Text("本周").tag("week")
                Text("本月").tag("month")
                Text("全部").tag("all")
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                Task { await viewModel.loadLeaderboard() }
            }

            List(viewModel.leaderboard) { entry in
                HStack {
                    Text("\(entry.rank)")
                        .frame(width: 30)
                        .foregroundColor(entry.rank <= 3 ? .orange : .secondary)
                    Text(entry.displayName)
                    Spacer()
                    Text("\(entry.charCount)字")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await viewModel.loadLeaderboard()
        }
    }
}

// MARK: - 声韵调表
private struct PinyinChartTab: View {
    private let initials = ["b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]
    private let singleFinals = ["a", "o", "e", "i", "u", "ü"]
    private let compoundFinals = ["ai", "ei", "ui", "ao", "ou", "iu", "ie", "üe", "er"]
    private let nasalFinals = ["an", "en", "in", "un", "ün"]
    private let backNasalFinals = ["ang", "eng", "ing", "ong"]
    private let tones = [
        ("ā", "一声（阴平）"),
        ("á", "二声（阳平）"),
        ("ǎ", "三声（上声）"),
        ("à", "四声（去声）"),
        ("a", "轻声")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                chartSection(title: "声母（23个）", items: initials)
                chartSection(title: "单韵母（6个）", items: singleFinals)
                chartSection(title: "复韵母（9个）", items: compoundFinals)
                chartSection(title: "前鼻韵母（5个）", items: nasalFinals)
                chartSection(title: "后鼻韵母（4个）", items: backNasalFinals)

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("声调（以\"a\"为例）")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(tones, id: \.0) { tone in
                            VStack(spacing: 4) {
                                Text(tone.0)
                                    .font(.system(size: 28, weight: .semibold))
                                Text(tone.1)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func chartSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3, height: 16)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

// MARK: - 练习弹窗
private struct PinyinPracticeSheet: View {
    @ObservedObject var viewModel: PinyinViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let current = viewModel.currentChar {
                    Spacer()
                    Text(current.char)
                        .font(.system(size: 100))
                    if viewModel.showHint {
                        Text(current.pinyin)
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    TextField("输入拼音", text: $viewModel.typedText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                        .padding()
                        .onChange(of: viewModel.typedText) { _, _ in
                            viewModel.checkInput()
                        }
                    Spacer()
                }
            }
            .navigationTitle("练习中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("退出") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("提示") { viewModel.showHint = true }
                }
            }
        }
    }
}

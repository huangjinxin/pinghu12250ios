//
//  OfflineDiaryView.swift
//  pinghu12250
//
//  离线日记练习编辑器 - 登录前可用
//

import SwiftUI

struct OfflineDiaryView: View {
    @StateObject private var viewModel = OfflineDiaryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧编辑区 (2/3)
                ScrollView {
                    VStack(spacing: 16) {
                        leftContent
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * 0.67)

                Divider()

                // 右侧统计区 (1/3)
                ScrollView {
                    VStack(spacing: 16) {
                        rightContent
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * 0.33)
            }
        }
        .navigationTitle("写日记练习")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("清空") {
                    viewModel.clear()
                }
                .disabled(viewModel.content.isEmpty)
            }
        }
        }
        .navigationViewStyle(.stack)
    }

    private var leftContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("标题")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("给日记起个标题", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("内容")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.content)
                    .frame(height: 300)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("心情")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("", selection: $viewModel.mood) {
                        ForEach(DiaryMood.allCases) { mood in
                            Text("\(mood.emoji) \(mood.name)").tag(mood.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("天气")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("", selection: $viewModel.weather) {
                        ForEach(DiaryWeather.allCases) { weather in
                            Text("\(weather.emoji) \(weather.name)").tag(weather.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            // 提示信息
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("这是练习模式，不会保存内容。登录后可以正式提交日记并获得积分奖励。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var rightContent: some View {
        VStack(spacing: 16) {
            // 字数统计
            VStack(alignment: .leading, spacing: 12) {
                Text("📊 字数统计").font(.system(size: 15, weight: .semibold))
                HStack(spacing: 12) {
                    wordStatView(value: viewModel.wordCount.total, label: "总字符")
                    wordStatView(value: viewModel.wordCount.words, label: "文字")
                    wordStatView(value: viewModel.wordCount.punctuation, label: "标点")
                    wordStatView(value: viewModel.wordCount.spaces, label: "空格")
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.levels, id: \.name) { level in
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.wordCount.words >= level.minWords ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.wordCount.words >= level.minWords ? .green : .gray)
                            Text(level.name).font(.system(size: 14))
                            Text("(\(level.minWords)字)").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                }

                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 8)
                            Rectangle().fill(Color.blue).frame(width: geometry.size.width * CGFloat(viewModel.progress) / 100, height: 8)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)

                    if let next = viewModel.nextLevel {
                        Text("还需 \(viewModel.wordsNeeded) 字达到\(next.name)等级").font(.system(size: 12)).foregroundColor(.secondary)
                    } else {
                        Text("🎉 已达到大师等级！").font(.system(size: 12)).foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // 查重
            VStack(alignment: .leading, spacing: 12) {
                Text("🔍 内容查重").font(.system(size: 15, weight: .semibold))
                Button {
                    viewModel.checkDuplicate()
                } label: {
                    Text(viewModel.wordCount.words < 100 ? "还需\(100 - viewModel.wordCount.words)字可查重" : "检测重复内容")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(viewModel.wordCount.words >= 100 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(viewModel.wordCount.words < 100)

                if viewModel.duplicateCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("发现 \(viewModel.duplicateCount) 处重复片段")
                            .font(.system(size: 13))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func wordStatView(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 18, weight: .semibold))
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
    }
}


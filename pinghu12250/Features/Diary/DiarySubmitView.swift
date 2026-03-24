//
//  DiarySubmitView.swift
//  pinghu12250
//
//  写日记提交页面
//

import SwiftUI

struct DiarySubmitView: View {
    @StateObject private var viewModel = DiarySubmitViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧写作区域 (2/3)
                ScrollView {
                    VStack(spacing: 16) {
                        leftContent
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * 0.67)

                Divider()

                // 右侧统计区域 (1/3)
                ScrollView {
                    VStack(spacing: 16) {
                        rightContent
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * 0.33)
            }
        }
        .navigationTitle("写日记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("提交") {
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .alert("提交成功", isPresented: $viewModel.showSuccess) {
            Button("继续写") { viewModel.reset() }
            Button("查看列表") { dismiss() }
        } message: {
            Text("日记已提交，等待审核")
        }
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

            VStack(alignment: .leading, spacing: 8) {
                Text("标签")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    TextField("添加标签", text: $viewModel.tagInput)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        viewModel.addTag()
                    }
                    .disabled(viewModel.tagInput.isEmpty)
                }

                if !viewModel.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag).font(.system(size: 13))
                                    Button {
                                        viewModel.removeTag(tag)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
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
                    Task { await viewModel.checkDuplicate() }
                } label: {
                    if viewModel.isCheckingDuplicate {
                        ProgressView()
                    } else {
                        Text(viewModel.wordCount.words < 800 ? "还需\(800 - viewModel.wordCount.words)字可查重" : "检测重复内容")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(viewModel.wordCount.words >= 800 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(viewModel.wordCount.words < 800 || viewModel.isCheckingDuplicate)

                if let result = viewModel.duplicateResult {
                    VStack(spacing: 8) {
                        HStack {
                            VStack {
                                Text("\(Int(result.overallRate))%").font(.system(size: 20, weight: .bold))
                                Text("总重复率").font(.system(size: 11))
                            }
                            if result.selfRepeatRate > 0 {
                                VStack {
                                    Text("\(Int(result.selfRepeatRate))%").font(.system(size: 20, weight: .bold))
                                    Text("自身重复").font(.system(size: 11))
                                }
                            }
                        }
                        Text("已检查 \(result.checkedDiaries) 篇日记").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // 最近提交
            VStack(alignment: .leading, spacing: 12) {
                Text("📚 最近提交").font(.system(size: 15, weight: .semibold))
                if viewModel.recentHistory.isEmpty {
                    Text("暂无历史记录").font(.system(size: 13)).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
                } else {
                    ForEach(viewModel.recentHistory) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 14))
                                Text(formatDate(item.date)).font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(item.points)").font(.system(size: 13, weight: .medium)).foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM-dd"
        return displayFormatter.string(from: date)
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

enum DiaryMood: String, CaseIterable, Identifiable {
    case happy = "开心"
    case sad = "难过"
    case excited = "兴奋"
    case calm = "平静"
    case angry = "生气"
    case tired = "疲惫"

    var id: String { rawValue }
    var name: String { rawValue }
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .excited: return "🤩"
        case .calm: return "😌"
        case .angry: return "😠"
        case .tired: return "😴"
        }
    }
}

enum DiaryWeather: String, CaseIterable, Identifiable {
    case sunny = "晴天"
    case cloudy = "多云"
    case rainy = "雨天"
    case snowy = "雪天"
    case windy = "大风"

    var id: String { rawValue }
    var name: String { rawValue }
    var emoji: String {
        switch self {
        case .sunny: return "☀️"
        case .cloudy: return "☁️"
        case .rainy: return "🌧️"
        case .snowy: return "❄️"
        case .windy: return "💨"
        }
    }
}

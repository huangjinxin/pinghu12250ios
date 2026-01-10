//
//  PracticeQuestionView.swift
//  pinghu12250
//
//  练习题渲染组件 - 支持选择题、填空题、判断题
//  兼容 Web 端 JSON 结构
//

import SwiftUI
import Combine

// MARK: - 练习题数据模型（兼容 Web 端 JSON）

struct PracticeQuestionData: Codable, Identifiable {
    var id: String { stem }  // 使用题干作为ID
    let stem: String           // 题干
    let type: String           // choice / blank / judge / multi
    let options: [QuestionOption]?  // 选项列表
    let answer: String         // 正确答案
    let analysis: String?      // 解析

    struct QuestionOption: Codable, Identifiable {
        var id: String { value }
        let value: String      // A, B, C, D
        let text: String       // 选项内容
    }

    // 从 JSON Any 解析
    static func parse(from json: Any) -> [PracticeQuestionData]? {
        // 处理单个题目或题目数组
        var jsonArray: [[String: Any]] = []

        if let single = json as? [String: Any] {
            // 检查是否有 questions 数组（多题格式）
            if let questions = single["questions"] as? [[String: Any]] {
                jsonArray = questions
            }
            // 检查是否有 question 对象（单题格式 - Web 端格式）
            else if let question = single["question"] as? [String: Any] {
                jsonArray = [question]
            }
            // 检查是否直接是单个题目（有 stem 字段）
            else if single["stem"] != nil {
                jsonArray = [single]
            }
        } else if let array = json as? [[String: Any]] {
            jsonArray = array
        }

        guard !jsonArray.isEmpty else { return nil }

        // 转换为 PracticeQuestionData
        var results: [PracticeQuestionData] = []
        for item in jsonArray {
            guard let stem = item["stem"] as? String,
                  let answer = item["answer"] as? String else { continue }

            let type = (item["type"] as? String) ?? "choice"
            let analysis = item["analysis"] as? String

            // 解析选项
            var options: [QuestionOption]? = nil
            if let optionsData = item["options"] {
                if let optArray = optionsData as? [[String: Any]] {
                    options = optArray.compactMap { opt in
                        guard let value = opt["value"] as? String,
                              let text = opt["text"] as? String else { return nil }
                        return QuestionOption(value: value, text: text)
                    }
                } else if let optArray = optionsData as? [String] {
                    // 简化格式：["选项A", "选项B", ...]
                    let labels = ["A", "B", "C", "D", "E", "F"]
                    options = optArray.enumerated().map { (index, text) in
                        QuestionOption(value: labels[index], text: text)
                    }
                }
            }

            results.append(PracticeQuestionData(
                stem: stem,
                type: type,
                options: options,
                answer: answer,
                analysis: analysis
            ))
        }

        return results.isEmpty ? nil : results
    }
}

// MARK: - 练习题视图状态

class PracticeQuestionState: ObservableObject {
    @Published var userAnswer: String = ""
    @Published var isAnswered: Bool = false
    @Published var isCorrect: Bool = false
    @Published var showAnalysis: Bool = false
}

// MARK: - 练习题主视图

struct PracticeQuestionView: View {
    let question: PracticeQuestionData
    let index: Int
    let compact: Bool

    @StateObject private var state = PracticeQuestionState()

    init(question: PracticeQuestionData, index: Int = 0, compact: Bool = false) {
        self.question = question
        self.index = index
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 题目标题
            questionHeader

            // 题干
            Text(question.stem)
                .font(compact ? .subheadline : .body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // 根据题型渲染不同组件
            questionContent

            // 作答反馈
            if state.isAnswered {
                answerFeedback
            }

            // 解析（可折叠）
            if let analysis = question.analysis, !analysis.isEmpty {
                analysisSection(analysis)
            }
        }
        .padding()
        .background(questionBackground)
        .cornerRadius(12)
    }

    // MARK: - 题目标题

    private var questionHeader: some View {
        HStack {
            Text("第 \(index + 1) 题")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Spacer()

            if state.isAnswered {
                HStack(spacing: 4) {
                    Image(systemName: state.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(state.isCorrect ? "正确" : "错误")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(state.isCorrect ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((state.isCorrect ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 题目内容（根据题型分发）

    @ViewBuilder
    private var questionContent: some View {
        switch question.type {
        case "choice":
            choiceOptions
        case "multi":
            multiChoiceOptions
        case "blank":
            blankInput
        case "judge":
            judgeButtons
        default:
            choiceOptions  // 默认为选择题
        }
    }

    // MARK: - 选择题选项

    private var choiceOptions: some View {
        VStack(spacing: 8) {
            ForEach(question.options ?? []) { option in
                ChoiceOptionRow(
                    option: option,
                    isSelected: state.userAnswer == option.value,
                    isCorrect: option.value == question.answer,
                    isAnswered: state.isAnswered,
                    compact: compact
                ) {
                    selectOption(option.value)
                }
            }
        }
    }

    // MARK: - 多选题选项

    private var multiChoiceOptions: some View {
        VStack(spacing: 8) {
            ForEach(question.options ?? []) { option in
                MultiChoiceOptionRow(
                    option: option,
                    isSelected: state.userAnswer.contains(option.value),
                    isCorrect: question.answer.contains(option.value),
                    isAnswered: state.isAnswered,
                    compact: compact
                ) {
                    toggleMultiOption(option.value)
                }
            }

            // 多选确认按钮
            if !state.isAnswered && !state.userAnswer.isEmpty {
                Button {
                    checkMultiAnswer()
                } label: {
                    Text("确认答案")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appPrimary)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 填空题输入

    private var blankInput: some View {
        HStack(spacing: 12) {
            TextField("请输入答案", text: $state.userAnswer)
                .textFieldStyle(.roundedBorder)
                .disabled(state.isAnswered)
                .onSubmit {
                    checkBlankAnswer()
                }

            Button {
                checkBlankAnswer()
            } label: {
                Text("确认")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(state.userAnswer.isEmpty || state.isAnswered ? Color.gray : Color.appPrimary)
                    .cornerRadius(8)
            }
            .disabled(state.userAnswer.isEmpty || state.isAnswered)
        }
    }

    // MARK: - 判断题按钮

    private var judgeButtons: some View {
        HStack(spacing: 16) {
            JudgeButton(
                title: "正确",
                icon: "checkmark",
                isSelected: state.userAnswer == "对",
                isCorrect: question.answer == "对",
                isAnswered: state.isAnswered
            ) {
                selectJudge("对")
            }

            JudgeButton(
                title: "错误",
                icon: "xmark",
                isSelected: state.userAnswer == "错",
                isCorrect: question.answer == "错",
                isAnswered: state.isAnswered
            ) {
                selectJudge("错")
            }
        }
    }

    // MARK: - 作答反馈

    private var answerFeedback: some View {
        Group {
            if !state.isCorrect {
                HStack {
                    Text("正确答案：")
                        .foregroundColor(.secondary)
                    Text(question.answer)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 解析区域（可折叠）

    private func analysisSection(_ analysis: String) -> some View {
        DisclosureGroup(
            isExpanded: $state.showAnalysis,
            content: {
                Text(analysis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            },
            label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                    Text("查看解析")
                        .font(.subheadline)
                }
                .foregroundColor(.orange)
            }
        )
        .padding(.top, 8)
        .onAppear {
            // 答题后自动展开解析
            if state.isAnswered {
                state.showAnalysis = true
            }
        }
    }

    // MARK: - 背景样式

    private var questionBackground: Color {
        if state.isAnswered {
            return state.isCorrect ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
        }
        return Color(.systemGray6)
    }

    // MARK: - 答题逻辑

    private func selectOption(_ value: String) {
        guard !state.isAnswered else { return }
        state.userAnswer = value
        state.isAnswered = true
        state.isCorrect = (value == question.answer)
    }

    private func toggleMultiOption(_ value: String) {
        guard !state.isAnswered else { return }
        if state.userAnswer.contains(value) {
            state.userAnswer = state.userAnswer.replacingOccurrences(of: value, with: "")
        } else {
            state.userAnswer += value
        }
    }

    private func checkMultiAnswer() {
        guard !state.isAnswered else { return }
        state.isAnswered = true
        // 比较排序后的答案
        let userSorted = String(state.userAnswer.sorted())
        let correctSorted = String(question.answer.sorted())
        state.isCorrect = (userSorted == correctSorted)
    }

    private func checkBlankAnswer() {
        guard !state.isAnswered, !state.userAnswer.isEmpty else { return }
        state.isAnswered = true
        // 忽略大小写和首尾空格比较
        state.isCorrect = state.userAnswer.trimmingCharacters(in: .whitespaces).lowercased()
            == question.answer.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func selectJudge(_ value: String) {
        guard !state.isAnswered else { return }
        state.userAnswer = value
        state.isAnswered = true
        state.isCorrect = (value == question.answer)
    }
}

// MARK: - 选择题选项行

struct ChoiceOptionRow: View {
    let option: PracticeQuestionData.QuestionOption
    let isSelected: Bool
    let isCorrect: Bool
    let isAnswered: Bool
    let compact: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选项标记
                ZStack {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 16, height: 16)
                    }
                }

                // 选项标签
                Text(option.value + ".")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .frame(width: 24)

                // 选项内容
                Text(option.text)
                    .font(compact ? .caption : .subheadline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private var borderColor: Color {
        if isAnswered {
            if isCorrect { return .green }
            if isSelected { return .red }
        }
        return isSelected ? .appPrimary : Color(.systemGray4)
    }

    private var fillColor: Color {
        if isAnswered {
            if isCorrect { return .green }
            if isSelected { return .red }
        }
        return .appPrimary
    }

    private var textColor: Color {
        if isAnswered {
            if isCorrect { return .green }
            if isSelected && !isCorrect { return .red }
        }
        return .primary
    }

    private var backgroundColor: Color {
        if isAnswered {
            if isCorrect { return Color.green.opacity(0.1) }
            if isSelected && !isCorrect { return Color.red.opacity(0.1) }
        }
        return isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemBackground)
    }
}

// MARK: - 多选题选项行

struct MultiChoiceOptionRow: View {
    let option: PracticeQuestionData.QuestionOption
    let isSelected: Bool
    let isCorrect: Bool
    let isAnswered: Bool
    let compact: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 复选框
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fillColor)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                Text(option.value + ".")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .frame(width: 24)

                Text(option.text)
                    .font(compact ? .caption : .subheadline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private var borderColor: Color {
        if isAnswered && isCorrect { return .green }
        if isAnswered && isSelected && !isCorrect { return .red }
        return isSelected ? .appPrimary : Color(.systemGray4)
    }

    private var fillColor: Color {
        if isAnswered && isCorrect { return .green }
        if isAnswered && isSelected { return .red }
        return .appPrimary
    }

    private var textColor: Color {
        if isAnswered && isCorrect { return .green }
        if isAnswered && isSelected && !isCorrect { return .red }
        return .primary
    }

    private var backgroundColor: Color {
        if isAnswered && isCorrect { return Color.green.opacity(0.1) }
        if isAnswered && isSelected && !isCorrect { return Color.red.opacity(0.1) }
        return isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemBackground)
    }
}

// MARK: - 判断题按钮

struct JudgeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isCorrect: Bool
    let isAnswered: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private var foregroundColor: Color {
        if isAnswered {
            if isCorrect { return .green }
            if isSelected { return .red }
        }
        return isSelected ? .appPrimary : .primary
    }

    private var backgroundColor: Color {
        if isAnswered {
            if isCorrect { return Color.green.opacity(0.15) }
            if isSelected { return Color.red.opacity(0.15) }
        }
        return isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemBackground)
    }

    private var borderColor: Color {
        if isAnswered {
            if isCorrect { return .green }
            if isSelected { return .red }
        }
        return isSelected ? .appPrimary : Color(.systemGray4)
    }
}

// MARK: - 练习题列表视图（用于显示多道题）

struct PracticeQuestionsListView: View {
    let questions: [PracticeQuestionData]
    let compact: Bool

    @State private var correctCount = 0
    @State private var answeredCount = 0

    init(questions: [PracticeQuestionData], compact: Bool = false) {
        self.questions = questions
        self.compact = compact
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                PracticeQuestionView(question: question, index: index, compact: compact)
            }

            // 底部统计（当所有题目都回答后显示）
            if answeredCount == questions.count && questions.count > 0 {
                scoreFooter
            }
        }
    }

    private var scoreFooter: some View {
        HStack {
            Text("本次成绩：")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(correctCount) / \(questions.count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(correctCount == questions.count ? .green : .orange)

            Text("(\(Int(Double(correctCount) / Double(questions.count) * 100))%)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                // 重做功能需要重置状态
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重做")
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview("选择题") {
    ScrollView {
        PracticeQuestionView(
            question: PracticeQuestionData(
                stem: "下列哪个是光合作用的产物？",
                type: "choice",
                options: [
                    .init(value: "A", text: "二氧化碳"),
                    .init(value: "B", text: "水"),
                    .init(value: "C", text: "葡萄糖和氧气"),
                    .init(value: "D", text: "氮气")
                ],
                answer: "C",
                analysis: "光合作用的反应式为：6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂，产物是葡萄糖和氧气。"
            ),
            index: 0
        )
        .padding()
    }
}

#Preview("判断题") {
    ScrollView {
        PracticeQuestionView(
            question: PracticeQuestionData(
                stem: "地球是太阳系中最大的行星。",
                type: "judge",
                options: nil,
                answer: "错",
                analysis: "木星是太阳系中最大的行星，地球的体积和质量都远小于木星。"
            ),
            index: 0
        )
        .padding()
    }
}

#Preview("填空题") {
    ScrollView {
        PracticeQuestionView(
            question: PracticeQuestionData(
                stem: "我国的首都是______。",
                type: "blank",
                options: nil,
                answer: "北京",
                analysis: "北京是中华人民共和国的首都，位于华北平原北部。"
            ),
            index: 0
        )
        .padding()
    }
}

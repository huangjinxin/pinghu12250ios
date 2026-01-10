//
//  QuestionCardView.swift
//  pinghu12250
//
//  练习题卡片视图 - 支持多种题型
//

import SwiftUI

// MARK: - 问题卡片容器

struct QuestionCardView: View {
    let question: PracticeItem
    let index: Int
    let total: Int
    @Binding var userAnswer: String
    let showResult: Bool
    let onSubmit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 题目头部
                questionHeader

                // 题干
                Text(question.stem)
                    .font(.body)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                // 根据题型显示不同的答题区域
                switch question.type {
                case .choice:
                    ChoiceOptionsView(
                        options: question.options ?? [],
                        selectedOption: $userAnswer,
                        correctAnswer: showResult ? question.answer : nil
                    )

                case .multiChoice:
                    MultiChoiceOptionsView(
                        options: question.options ?? [],
                        selectedOptions: $userAnswer,
                        correctAnswer: showResult ? question.answer : nil
                    )

                case .blank:
                    BlankInputView(
                        blanksCount: question.blanks?.count ?? 1,
                        userAnswer: $userAnswer,
                        correctAnswer: showResult ? question.answer : nil
                    )

                case .judge:
                    JudgeOptionsView(
                        selectedOption: $userAnswer,
                        correctAnswer: showResult ? question.answer : nil
                    )

                case .shortAnswer:
                    ShortAnswerInputView(
                        userAnswer: $userAnswer,
                        correctAnswer: showResult ? question.answer : nil
                    )
                }

                // 显示结果
                if showResult {
                    resultSection
                }

                // 提交按钮
                if !showResult {
                    submitButton
                }
            }
            .padding()
        }
    }

    // MARK: - 题目头部

    private var questionHeader: some View {
        HStack {
            // 题号和类型
            HStack(spacing: 8) {
                Text("第 \(index + 1) 题")
                    .font(.headline)
                    .fontWeight(.bold)

                HStack(spacing: 4) {
                    Image(systemName: question.type.icon)
                        .font(.caption)
                    Text(question.type.displayName)
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(question.type.color)
                .cornerRadius(8)
            }

            Spacer()

            // 进度
            Text("\(index + 1)/\(total)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 难度
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { level in
                    Image(systemName: level <= question.difficulty ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundColor(level <= question.difficulty ? .orange : .gray.opacity(0.3))
                }
            }
        }
    }

    // MARK: - 结果区域

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 正确/错误标记
            let isCorrect = PracticeService.shared.checkAnswer(question: question, userAnswer: userAnswer)

            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCorrect ? .green : .red)

                Text(isCorrect ? "回答正确！" : "回答错误")
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)

                Spacer()
            }
            .padding()
            .background((isCorrect ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(12)

            // 正确答案
            if !isCorrect {
                HStack {
                    Text("正确答案：")
                        .foregroundColor(.secondary)
                    Text(question.answer)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                }
                .padding(.horizontal)
            }

            // 解析
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("解析")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(question.analysis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - 提交按钮

    private var submitButton: some View {
        Button(action: onSubmit) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("提交答案")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(userAnswer.isEmpty ? Color.gray : Color.appPrimary)
            .cornerRadius(12)
        }
        .disabled(userAnswer.isEmpty)
    }
}

// MARK: - 选择题选项视图

struct ChoiceOptionsView: View {
    let options: [OptionItem]
    @Binding var selectedOption: String
    let correctAnswer: String?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                OptionRowView(
                    option: option,
                    isSelected: selectedOption == option.value,
                    isCorrect: correctAnswer == option.value,
                    isWrong: correctAnswer != nil && selectedOption == option.value && correctAnswer != option.value,
                    showResult: correctAnswer != nil
                ) {
                    if correctAnswer == nil {
                        selectedOption = option.value
                    }
                }
            }
        }
    }
}

// MARK: - 多选题选项视图

struct MultiChoiceOptionsView: View {
    let options: [OptionItem]
    @Binding var selectedOptions: String
    let correctAnswer: String?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                let isSelected = selectedOptions.contains(option.value)
                let isCorrectOption = correctAnswer?.contains(option.value) ?? false

                MultiOptionRowView(
                    option: option,
                    isSelected: isSelected,
                    isCorrect: correctAnswer != nil && isCorrectOption && isSelected,
                    isWrong: correctAnswer != nil && !isCorrectOption && isSelected,
                    isMissed: correctAnswer != nil && isCorrectOption && !isSelected,
                    showResult: correctAnswer != nil
                ) {
                    if correctAnswer == nil {
                        toggleOption(option.value)
                    }
                }
            }

            if correctAnswer == nil {
                Text("可多选")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func toggleOption(_ value: String) {
        if selectedOptions.contains(value) {
            selectedOptions = selectedOptions.replacingOccurrences(of: value, with: "")
        } else {
            selectedOptions = String((selectedOptions + value).sorted())
        }
    }
}

// MARK: - 选项行视图

struct OptionRowView: View {
    let option: OptionItem
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let showResult: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 选项字母
                ZStack {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isSelected || isCorrect {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 32, height: 32)
                    }

                    Text(option.value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected || isCorrect ? .white : .primary)
                }

                // 选项内容
                Text(option.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                // 结果图标
                if showResult {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isWrong {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(showResult)
    }

    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .appPrimary }
        return Color(.systemGray4)
    }

    private var fillColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .appPrimary }
        return .clear
    }

    private var backgroundColor: Color {
        if isCorrect { return Color.green.opacity(0.1) }
        if isWrong { return Color.red.opacity(0.1) }
        if isSelected { return Color.appPrimary.opacity(0.1) }
        return Color(.systemBackground)
    }
}

// MARK: - 多选选项行视图

struct MultiOptionRowView: View {
    let option: OptionItem
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let isMissed: Bool
    let showResult: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 复选框
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected || isMissed {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fillColor)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }

                Text(option.value)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(option.text)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                if showResult {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isWrong {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    } else if isMissed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(showResult)
    }

    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isMissed { return .orange }
        if isSelected { return .appPrimary }
        return Color(.systemGray4)
    }

    private var fillColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isMissed { return .orange }
        if isSelected { return .appPrimary }
        return .clear
    }

    private var backgroundColor: Color {
        if isCorrect { return Color.green.opacity(0.1) }
        if isWrong { return Color.red.opacity(0.1) }
        if isMissed { return Color.orange.opacity(0.1) }
        return Color(.systemBackground)
    }
}

// MARK: - 判断题视图

struct JudgeOptionsView: View {
    @Binding var selectedOption: String
    let correctAnswer: String?

    var body: some View {
        HStack(spacing: 20) {
            ForEach(["对", "错"], id: \.self) { option in
                let isSelected = selectedOption == option
                let isCorrectOption = correctAnswer == option
                let isWrong = correctAnswer != nil && isSelected && !isCorrectOption

                JudgeOptionButton(
                    label: option,
                    icon: option == "对" ? "checkmark.circle.fill" : "xmark.circle.fill",
                    isSelected: isSelected,
                    isCorrect: correctAnswer != nil && isCorrectOption,
                    isWrong: isWrong
                ) {
                    if correctAnswer == nil {
                        selectedOption = option
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

struct JudgeOptionButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(iconColor)

                Text(label)
                    .font(.headline)
                    .foregroundColor(iconColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return label == "对" ? .green : .red }
        return .secondary
    }

    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return label == "对" ? .green : .red }
        return Color(.systemGray4)
    }

    private var backgroundColor: Color {
        if isCorrect { return Color.green.opacity(0.1) }
        if isWrong { return Color.red.opacity(0.1) }
        if isSelected { return (label == "对" ? Color.green : Color.red).opacity(0.1) }
        return Color(.systemBackground)
    }
}

// MARK: - 填空题视图

struct BlankInputView: View {
    let blanksCount: Int
    @Binding var userAnswer: String
    let correctAnswer: String?

    @State private var answers: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<blanksCount, id: \.self) { index in
                HStack {
                    Text("第 \(index + 1) 空：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("请输入答案", text: binding(for: index))
                        .textFieldStyle(.roundedBorder)
                        .disabled(correctAnswer != nil)
                }
            }

            if let correct = correctAnswer, !correct.isEmpty {
                HStack {
                    Text("正确答案：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(correct)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            answers = Array(repeating: "", count: blanksCount)
        }
        .onChange(of: answers) { _, newAnswers in
            userAnswer = newAnswers.joined(separator: "、")
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { newValue in
                if index < answers.count {
                    answers[index] = newValue
                }
            }
        )
    }
}

// MARK: - 简答题视图

struct ShortAnswerInputView: View {
    @Binding var userAnswer: String
    let correctAnswer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $userAnswer)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .disabled(correctAnswer != nil)

            if correctAnswer == nil {
                Text("请详细作答")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("参考答案：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(correctAnswer ?? "")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    let sampleQuestion = PracticeItem(
        type: .choice,
        stem: "下列哪个选项是正确的？这是一道测试题目，请仔细阅读后选择正确答案。",
        options: [
            OptionItem(value: "A", text: "这是选项A的内容"),
            OptionItem(value: "B", text: "这是选项B的内容"),
            OptionItem(value: "C", text: "这是选项C的内容"),
            OptionItem(value: "D", text: "这是选项D的内容")
        ],
        answer: "B",
        analysis: "选项B是正确的，因为根据课文内容..."
    )

    QuestionCardView(
        question: sampleQuestion,
        index: 0,
        total: 5,
        userAnswer: .constant(""),
        showResult: false,
        onSubmit: {}
    )
}

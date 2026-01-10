//
//  PracticeView.swift
//  pinghu12250
//
//  练习面板视图 - 显示练习题和答题交互
//

import SwiftUI
import Combine

// MARK: - 练习 ViewModel

@MainActor
class PracticeViewModel: ObservableObject {
    // 状态
    @Published var state: PracticeState = .idle
    @Published var session: PracticeSession?
    @Published var currentIndex: Int = 0
    @Published var userAnswers: [String] = []
    @Published var showResults: [Bool] = []

    // 计时
    @Published var elapsedTime: TimeInterval = 0
    @Published var questionStartTime: Date?
    private var timer: Timer?

    // 配置
    @Published var settings = PracticeSettings.default
    let textbookId: String
    let subject: String

    init(textbookId: String, subject: String) {
        self.textbookId = textbookId
        self.subject = subject
    }

    // MARK: - 生成练习

    func generatePractice(pageIndex: Int, pageImage: UIImage) async {
        state = .generating

        do {
            let questions = try await PracticeService.shared.generatePractice(
                textbookId: textbookId,
                pageIndex: pageIndex,
                image: pageImage,
                subject: subject,
                questionTypes: enabledQuestionTypes,
                count: settings.questionCount
            )

            guard !questions.isEmpty else {
                state = .error("未能生成有效题目")
                return
            }

            session = PracticeSession(textbookId: textbookId, pageIndex: pageIndex)
            session?.questions = questions
            userAnswers = Array(repeating: "", count: questions.count)
            showResults = Array(repeating: false, count: questions.count)
            currentIndex = 0

            state = .ready

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private var enabledQuestionTypes: [QuestionType] {
        var types: [QuestionType] = []
        if settings.includeChoiceQuestions { types.append(.choice) }
        if settings.includeBlankQuestions { types.append(.blank) }
        if settings.includeJudgeQuestions { types.append(.judge) }
        return types.isEmpty ? [.choice] : types
    }

    // MARK: - 开始练习

    func startPractice() {
        guard session != nil else { return }
        state = .answering(0)
        startTimer()
        questionStartTime = Date()
    }

    // MARK: - 提交答案

    func submitAnswer() {
        guard let session = session,
              currentIndex < session.questions.count else { return }

        let question = session.questions[currentIndex]
        let answer = userAnswers[currentIndex]

        // 计算用时
        let timeTaken = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // 检查答案
        let isCorrect = PracticeService.shared.checkAnswer(question: question, userAnswer: answer)

        // 记录答案
        let userAnswer = UserAnswer(
            questionId: question.id,
            answer: answer,
            isCorrect: isCorrect,
            timeTaken: timeTaken
        )
        self.session?.answers.append(userAnswer)

        // 显示结果
        showResults[currentIndex] = true
        state = .showingResult(isCorrect)

        // 自动下一题
        if settings.autoNext {
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.autoNextDelay) {
                self.nextQuestion()
            }
        }
    }

    // MARK: - 下一题

    func nextQuestion() {
        guard let session = session else { return }

        if currentIndex < session.questions.count - 1 {
            currentIndex += 1
            state = .answering(currentIndex)
            questionStartTime = Date()
        } else {
            completePractice()
        }
    }

    // MARK: - 上一题

    func previousQuestion() {
        if currentIndex > 0 {
            currentIndex -= 1
            state = .answering(currentIndex)
        }
    }

    // MARK: - 完成练习

    func completePractice() {
        stopTimer()
        session?.completedAt = Date()
        state = .completed

        // 保存记录
        if let session = session {
            PracticeHistoryManager.shared.saveSession(session, textbookTitle: "")
        }
    }

    // MARK: - 重新开始

    func restart() {
        session = nil
        userAnswers = []
        showResults = []
        currentIndex = 0
        elapsedTime = 0
        state = .idle
    }

    // MARK: - 计时器

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedTime += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - 练习面板视图

struct PracticeView: View {
    @StateObject private var viewModel: PracticeViewModel
    let pageIndex: Int
    let pageImage: UIImage?
    let onDismiss: () -> Void

    init(textbookId: String, subject: String, pageIndex: Int, pageImage: UIImage?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PracticeViewModel(textbookId: textbookId, subject: subject))
        self.pageIndex = pageIndex
        self.pageImage = pageImage
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // 根据状态显示内容
            switch viewModel.state {
            case .idle:
                idleView

            case .generating:
                generatingView

            case .ready:
                readyView

            case .answering, .showingResult:
                practiceContentView

            case .completed:
                completedView

            case .error(let message):
                errorView(message)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 空闲状态

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.appPrimary)

            Text("智能练习")
                .font(.title2)
                .fontWeight(.bold)

            Text("基于当前页面内容，AI 将为你生成练习题")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 设置选项
            VStack(spacing: 16) {
                settingRow(
                    icon: "number.circle.fill",
                    title: "题目数量",
                    value: "\(viewModel.settings.questionCount) 道"
                ) {
                    // 可以添加调整逻辑
                }

                Toggle(isOn: $viewModel.settings.showTimer) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text("显示计时")
                    }
                }
                .tint(.appPrimary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            // 开始按钮
            Button {
                if let image = pageImage {
                    Task {
                        await viewModel.generatePractice(pageIndex: pageIndex, pageImage: image)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开始生成练习")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(pageImage != nil ? Color.appPrimary : Color.gray)
                .cornerRadius(12)
            }
            .disabled(pageImage == nil)
            .padding(.horizontal, 40)

            if pageImage == nil {
                Text("请先截取页面内容")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.appPrimary)
                Text(title)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 生成中

    private var generatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)

            Text("AI 正在分析页面内容...")
                .font(.headline)

            Text("正在生成练习题")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 显示页面预览
            if let image = pageImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 准备就绪

    private var readyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("练习题已生成！")
                .font(.title2)
                .fontWeight(.bold)

            if let session = viewModel.session {
                VStack(spacing: 8) {
                    Text("共 \(session.questions.count) 道题目")
                        .font(.headline)

                    HStack(spacing: 16) {
                        ForEach(QuestionType.allCases, id: \.self) { type in
                            let count = session.questions.filter { $0.type == type }.count
                            if count > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.caption)
                                    Text("\(count)")
                                        .font(.caption)
                                }
                                .foregroundColor(type.color)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            Button {
                viewModel.startPractice()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("开始答题")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 练习内容

    private var practiceContentView: some View {
        VStack(spacing: 0) {
            // 顶部进度条
            practiceHeader

            // 题目卡片
            if let session = viewModel.session,
               viewModel.currentIndex < session.questions.count {
                QuestionCardView(
                    question: session.questions[viewModel.currentIndex],
                    index: viewModel.currentIndex,
                    total: session.questions.count,
                    userAnswer: $viewModel.userAnswers[viewModel.currentIndex],
                    showResult: viewModel.showResults[viewModel.currentIndex],
                    onSubmit: {
                        viewModel.submitAnswer()
                    }
                )
            }

            // 底部导航
            if case .showingResult = viewModel.state {
                practiceFooter
            }
        }
    }

    private var practiceHeader: some View {
        VStack(spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.appPrimary)
                        .frame(width: progressWidth(for: geometry.size.width), height: 4)
                }
            }
            .frame(height: 4)

            // 信息栏
            HStack {
                // 进度
                Text("第 \(viewModel.currentIndex + 1) / \(viewModel.session?.questions.count ?? 0) 题")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // 计时器
                if viewModel.settings.showTimer {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(viewModel.elapsedTime.formattedDuration)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        guard let session = viewModel.session, !session.questions.isEmpty else { return 0 }
        return totalWidth * CGFloat(viewModel.currentIndex + 1) / CGFloat(session.questions.count)
    }

    private var practiceFooter: some View {
        HStack(spacing: 16) {
            // 上一题
            if viewModel.currentIndex > 0 {
                Button {
                    viewModel.previousQuestion()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("上一题")
                    }
                    .foregroundColor(.appPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // 下一题/完成
            Button {
                viewModel.nextQuestion()
            } label: {
                HStack {
                    Text(isLastQuestion ? "完成练习" : "下一题")
                    Image(systemName: isLastQuestion ? "checkmark" : "chevron.right")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var isLastQuestion: Bool {
        guard let session = viewModel.session else { return true }
        return viewModel.currentIndex >= session.questions.count - 1
    }

    // MARK: - 完成视图

    private var completedView: some View {
        VStack(spacing: 24) {
            // 成绩卡片
            if let session = viewModel.session {
                VStack(spacing: 16) {
                    // 分数圆环
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 12)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: session.accuracy)
                            .stroke(
                                session.accuracy >= 0.6 ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text(session.accuracy.percentageString)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("正确率")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 统计信息
                    HStack(spacing: 32) {
                        statItem(
                            icon: "checkmark.circle.fill",
                            value: "\(session.correctCount)",
                            label: "正确",
                            color: .green
                        )

                        statItem(
                            icon: "xmark.circle.fill",
                            value: "\(session.questions.count - session.correctCount)",
                            label: "错误",
                            color: .red
                        )

                        statItem(
                            icon: "timer",
                            value: session.totalTime.formattedDuration,
                            label: "用时",
                            color: .orange
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                // 鼓励语
                Text(encouragementText(accuracy: session.accuracy))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // 操作按钮
            VStack(spacing: 12) {
                Button {
                    viewModel.restart()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("再练一次")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                }

                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("返回阅读")
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func encouragementText(accuracy: Double) -> String {
        switch accuracy {
        case 1.0: return "太棒了！全部正确！🎉"
        case 0.8..<1.0: return "非常好！继续保持！👏"
        case 0.6..<0.8: return "不错！还可以更好！💪"
        case 0.4..<0.6: return "加油！多复习一下！📚"
        default: return "别灰心！再试一次！✊"
        }
    }

    // MARK: - 错误视图

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("生成失败")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.state = .idle
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        PracticeView(
            textbookId: "test",
            subject: "CHINESE",
            pageIndex: 0,
            pageImage: nil,
            onDismiss: {}
        )
    }
}

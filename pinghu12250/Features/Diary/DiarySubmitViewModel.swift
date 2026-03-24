//
//  DiarySubmitViewModel.swift
//  pinghu12250
//

import SwiftUI
import Combine

struct DiarySubmitRequest: Codable {
    let templateName: String
    let title: String
    let content: String
    let mood: String
    let weather: String
    let tags: [String]
}

struct WordCount {
    let total: Int
    let words: Int
    let punctuation: Int
    let spaces: Int
}

@MainActor
class DiarySubmitViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var mood = "开心"
    @Published var weather = "晴天"
    @Published var tags: [String] = []
    @Published var tagInput = ""
    @Published var isSubmitting = false
    @Published var showSuccess = false
    @Published var recentHistory: [HistoryItem] = []
    @Published var isCheckingDuplicate = false
    @Published var duplicateResult: DuplicateResult?

    private let api = APIService.shared

    struct Level {
        let name: String
        let minWords: Int
    }

    let levels = [
        Level(name: "入门", minWords: 800),
        Level(name: "良好", minWords: 1000),
        Level(name: "优秀", minWords: 1200),
        Level(name: "卓越", minWords: 1500),
        Level(name: "大师", minWords: 2000)
    ]

    var wordCount: WordCount {
        let total = content.count
        let chineseChars = content.filter { $0 >= "\u{4e00}" && $0 <= "\u{9fa5}" }.count
        let englishChars = content.filter { $0.isLetter && $0.isASCII }.count
        let numbers = content.filter { $0.isNumber }.count
        let words = chineseChars + englishChars + numbers
        let punctuation = content.filter { char in
            let punctuations: [Character] = ["，", "。", "！", "？", "、", "；", "：", "（", "）", "【", "】", "《", "》", "…", "—", ",", ".", "!", "?", ";", ":", "(", ")", "[", "]", "<", ">", "\"", "'"]
            return punctuations.contains(char) || char == "\u{201C}" || char == "\u{201D}" || char == "\u{2018}" || char == "\u{2019}"
        }.count
        let spaces = content.filter { $0.isWhitespace }.count
        return WordCount(total: total, words: words, punctuation: punctuation, spaces: spaces)
    }

    var currentLevel: Level? {
        let words = wordCount.words
        return levels.reversed().first { words >= $0.minWords }
    }

    var nextLevel: Level? {
        let words = wordCount.words
        return levels.first { words < $0.minWords }
    }

    var progress: Int {
        let words = wordCount.words
        guard let next = nextLevel else { return 100 }
        let prevMin = currentLevel?.minWords ?? 0
        let range = next.minWords - prevMin
        return min(100, Int(Double(words - prevMin) / Double(range) * 100))
    }

    var wordsNeeded: Int {
        guard let next = nextLevel else { return 0 }
        return max(0, next.minWords - wordCount.words)
    }

    var canSubmit: Bool {
        !title.isEmpty && !content.isEmpty
    }

    func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag), tags.count < 5 else { return }
        tags.append(tag)
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func loadHistory() async {
        do {
            let response: APIResponse<HistoryResponse> = try await api.get("/api/diary/recent?limit=5")
            if let data = response.data {
                recentHistory = data.list
            }
        } catch {}
    }

    func checkDuplicate() async {
        guard wordCount.words >= 800 else { return }
        isCheckingDuplicate = true
        defer { isCheckingDuplicate = false }

        do {
            let body = ["content": content]
            let response: APIResponse<DuplicateResult> = try await api.post("/api/diary/check-duplicate", body: body)
            duplicateResult = response.data
        } catch {}
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let body = DiarySubmitRequest(
                templateName: "日记(审批前提项/日)",
                title: title,
                content: content,
                mood: mood,
                weather: weather,
                tags: tags
            )
            let _: APIResponse<SubmissionResponse> = try await api.post("/api/submissions", body: body)
            showSuccess = true
        } catch {}
    }

    func reset() {
        title = ""
        content = ""
        mood = "开心"
        weather = "晴天"
        tags = []
        tagInput = ""
    }
}

struct HistoryItem: Codable, Identifiable {
    let id: String
    let title: String
    let date: String
    let points: Int
}

struct HistoryResponse: Codable {
    let list: [HistoryItem]
}

struct DuplicateResult: Codable {
    let overallRate: Double
    let selfRepeatRate: Double
    let checkedDiaries: Int
    let duplicateChars: Int
    let selfRepeatChars: Int
}


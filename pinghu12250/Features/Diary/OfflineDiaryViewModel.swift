//
//  OfflineDiaryViewModel.swift
//  pinghu12250
//
//  离线日记练习 ViewModel
//

import SwiftUI
import Combine

@MainActor
class OfflineDiaryViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var mood = "开心"
    @Published var weather = "晴天"
    @Published var duplicateCount = 0

    struct OfflineWordCount {
        let total: Int
        let words: Int
        let punctuation: Int
        let spaces: Int
    }

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

    var wordCount: OfflineWordCount {
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
        return OfflineWordCount(total: total, words: words, punctuation: punctuation, spaces: spaces)
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

        let ranges = [
            (min: 0, max: 800),
            (min: 800, max: 1000),
            (min: 1000, max: 1200),
            (min: 1200, max: 1500),
            (min: 1500, max: 2000)
        ]

        let levelIndex = levels.firstIndex { words < $0.minWords } ?? levels.count
        guard levelIndex < ranges.count else { return 100 }

        let range = ranges[levelIndex]
        let rangeProgress = Double(words - range.min) / Double(range.max - range.min)
        let totalProgress = Double(levelIndex) * 20.0 + rangeProgress * 20.0
        return min(Int(totalProgress), 100)
    }

    var wordsNeeded: Int {
        guard let next = nextLevel else { return 0 }
        return next.minWords - wordCount.words
    }

    func checkDuplicate() {
        guard content.count >= 100 else { return }

        // 简单的重复检测：查找重复的句子
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 5 }

        var seen = Set<String>()
        var duplicates = 0

        for sentence in sentences {
            if seen.contains(sentence) {
                duplicates += 1
            } else {
                seen.insert(sentence)
            }
        }

        duplicateCount = duplicates
    }

    func clear() {
        title = ""
        content = ""
        mood = "开心"
        weather = "晴天"
        duplicateCount = 0
    }
}

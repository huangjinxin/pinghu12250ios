//
//  PinyinViewModel.swift
//  pinghu12250
//
//  拼音学习ViewModel
//

import SwiftUI
import Combine

@MainActor
class PinyinViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var isConverting = false
    @Published var showPractice = false
    @Published var records: [PinyinRecord] = []
    @Published var stats: PinyinStats?
    @Published var leaderboard: [PinyinLeaderboardEntry] = []
    @Published var selectedPeriod = "week"
    @Published var currentCharIndex = 0
    @Published var typedText = ""
    @Published var showHint = false

    private var convertedChars: [PinyinChar] = []
    private let api = APIService.shared

    var currentChar: PinyinChar? {
        guard currentCharIndex < convertedChars.count else { return nil }
        return convertedChars[currentCharIndex]
    }

    func convertText() async {
        guard !inputText.isEmpty else { return }
        isConverting = true
        defer { isConverting = false }

        do {
            let body = ["text": inputText]
            let response: APIResponse<ConvertResponse> = try await api.post("/api/pinyin/convert", body: body)
            if let data = response.data {
                convertedChars = data.chars
                currentCharIndex = 0
                typedText = ""
                showHint = false
                showPractice = true
            }
        } catch {}
    }

    func checkInput() {
        guard let current = currentChar else { return }
        if typedText.lowercased() == current.pinyinLetters.lowercased() {
            typedText = ""
            showHint = false
            if currentCharIndex + 1 < convertedChars.count {
                currentCharIndex += 1
            } else {
                showPractice = false
            }
        }
    }

    func loadRecords() async {
        do {
            let response: APIResponse<RecordsResponse> = try await api.get("/api/pinyin/practice/my")
            if let data = response.data {
                records = data.practices
            }
        } catch {}

        do {
            let response: APIResponse<PinyinStats> = try await api.get("/api/pinyin/practice/my/stats")
            stats = response.data
        } catch {}
    }

    func loadLeaderboard() async {
        do {
            let response: APIResponse<PinyinLeaderboardResponse> = try await api.get(
                "/api/pinyin/practice/leaderboard",
                queryItems: [URLQueryItem(name: "period", value: selectedPeriod)]
            )
            if let data = response.data {
                leaderboard = data.leaderboard
            }
        } catch {}
    }
}

struct PinyinChar: Codable {
    let char: String
    let pinyin: String
    let pinyinLetters: String
}

struct ConvertResponse: Codable {
    let chars: [PinyinChar]
}

struct PinyinRecord: Codable, Identifiable {
    let id: String
    let title: String
    let charCount: Int
    let accuracy: Double
    let duration: Int
}

struct RecordsResponse: Codable {
    let practices: [PinyinRecord]
    let total: Int
}

struct PinyinStats: Codable {
    let allTime: StatsDetail
}

struct StatsDetail: Codable {
    let practiceCount: Int
    let charCount: Int
    let avgAccuracy: Double

    var totalPractices: Int { practiceCount }
    var totalChars: Int { charCount }
}

struct PinyinLeaderboardEntry: Codable, Identifiable {
    let user: PinyinUser
    let charCount: Int
    let rank: Int

    var id: String { user.id }
    var displayName: String { user.profile?.nickname ?? user.username }
}

struct PinyinUser: Codable {
    let id: String
    let username: String
    let avatar: String?
    let profile: PinyinProfile?
}

struct PinyinProfile: Codable {
    let nickname: String?
}

struct PinyinLeaderboardResponse: Codable {
    let leaderboard: [PinyinLeaderboardEntry]
}

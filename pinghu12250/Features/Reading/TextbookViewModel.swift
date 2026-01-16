//
//  TextbookViewModel.swift
//  pinghu12250
//
//  教材 ViewModel - 教材列表、收藏、笔记管理
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TextbookViewModel: ObservableObject {
    // MARK: - 数据

    @Published var publicTextbooks: [Textbook] = []
    @Published var favoriteTextbooks: [Textbook] = []
    @Published var readingNotes: [ReadingNote] = []
    @Published var textbookToc: [TextbookUnit] = []

    // MARK: - 筛选选项

    @Published var filterSubjects: [String] = []
    @Published var filterGrades: [Int] = []
    @Published var filterSemesters: [String] = []
    @Published var filterVersions: [String] = []

    // MARK: - 当前筛选

    @Published var selectedSubject: String = ""
    @Published var selectedGrade: Int = 0
    @Published var selectedSemester: String = ""
    @Published var selectedVersion: String = ""
    @Published var searchText: String = ""

    // MARK: - 分页

    @Published var currentPage: Int = 1
    @Published var pageSize: Int = 50  // 增加每页数量
    @Published var totalCount: Int = 0
    @Published var hasMore: Bool = true

    // MARK: - 状态

    @Published var isLoading = false
    @Published var isLoadingNotes = false
    @Published var isLoadingFavorites = false
    @Published var errorMessage: String?

    // MARK: - 选中项

    @Published var selectedTextbook: Textbook?
    @Published var selectedNote: ReadingNote?

    // MARK: - 收藏ID集合

    private var favoriteIds: Set<String> = []

    // MARK: - 初始化加载

    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFilterOptions() }
            group.addTask { await self.loadPublicTextbooks() }
            group.addTask { await self.loadFavorites() }
        }
    }

    // MARK: - 加载筛选选项

    func loadFilterOptions() async {
        do {
            let response: TextbookOptionsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.textbookOptions
            )
            let options = response.options
            if !options.subjectValues.isEmpty {
                filterSubjects = options.subjectValues
            }
            if !options.gradeValues.isEmpty {
                filterGrades = options.gradeValues
            }
            if !options.semesterValues.isEmpty {
                filterSemesters = options.semesterValues
            }
            if !options.versionValues.isEmpty {
                filterVersions = options.versionValues
            }
        } catch {
            #if DEBUG
            print("加载筛选选项失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载公共教材列表

    func loadPublicTextbooks(refresh: Bool = false) async {
        // 刷新时重置分页
        if refresh {
            currentPage = 1
            hasMore = true
            publicTextbooks = []
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(currentPage)"),
                URLQueryItem(name: "limit", value: "\(pageSize)")
            ]

            if !selectedSubject.isEmpty {
                queryItems.append(URLQueryItem(name: "subject", value: selectedSubject))
            }
            if selectedGrade > 0 {
                queryItems.append(URLQueryItem(name: "grade", value: "\(selectedGrade)"))
            }
            if !selectedSemester.isEmpty {
                queryItems.append(URLQueryItem(name: "semester", value: selectedSemester))
            }
            if !selectedVersion.isEmpty {
                queryItems.append(URLQueryItem(name: "version", value: selectedVersion))
            }
            if !searchText.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: searchText))
            }

            let response: TextbookListResponse = try await APIService.shared.get(
                APIConfig.Endpoints.textbooksPublic,
                queryItems: queryItems
            )

            publicTextbooks = response.textbooks
            totalCount = response.total
            hasMore = response.page < response.totalPages

            // 更新筛选选项（如果服务器返回了）
            if let filterOpts = response.filterOptions {
                if let subjects = filterOpts.subjects, !subjects.isEmpty {
                    filterSubjects = subjects
                }
                if let grades = filterOpts.grades, !grades.isEmpty {
                    filterGrades = grades
                }
            }

            #if DEBUG
            print("加载教材成功: \(publicTextbooks.count) 条, 总数: \(totalCount), 页: \(currentPage)/\(response.totalPages)")
            #endif
        } catch {
            #if DEBUG
            print("加载教材失败: \(error)")
            if case let APIError.decodingError(decodingError) = error {
                print("解码错误详情: \(decodingError)")
            }
            #endif
            errorMessage = "加载教材失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 加载指定页码

    func loadPage(_ page: Int) async {
        guard page >= 1 else { return }
        currentPage = page
        await loadPublicTextbooks(refresh: false)
    }

    // MARK: - 加载收藏教材

    func loadFavorites() async {
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }

        do {
            // 后端返回格式: { textbooks: [...], pagination: {...} }
            let response: TextbookListResponse = try await APIService.shared.get(
                APIConfig.Endpoints.textbookFavorites
            )
            favoriteTextbooks = response.textbooks
            favoriteIds = Set(response.textbooks.map { $0.id })
        } catch {
            #if DEBUG
            print("加载收藏失败: \(error)")
            #endif
        }
    }

    // MARK: - 检查是否收藏

    func isFavorite(_ textbookId: String) -> Bool {
        favoriteIds.contains(textbookId)
    }

    // MARK: - 切换收藏

    func toggleFavorite(_ textbook: Textbook) async {
        let textbookId = textbook.id
        let wasFavorite = isFavorite(textbookId)

        // 乐观更新
        if wasFavorite {
            favoriteIds.remove(textbookId)
            favoriteTextbooks.removeAll { $0.id == textbookId }
        } else {
            favoriteIds.insert(textbookId)
            favoriteTextbooks.insert(textbook, at: 0)
        }

        do {
            if wasFavorite {
                let _: EmptyResponse = try await APIService.shared.delete(
                    "\(APIConfig.Endpoints.textbookFavorites)/\(textbookId)"
                )
            } else {
                let _: EmptyResponse = try await APIService.shared.post(
                    "\(APIConfig.Endpoints.textbookFavorites)/\(textbookId)",
                    body: EmptyRequest()
                )
            }
        } catch {
            // 回滚
            if wasFavorite {
                favoriteIds.insert(textbookId)
                favoriteTextbooks.insert(textbook, at: 0)
            } else {
                favoriteIds.remove(textbookId)
                favoriteTextbooks.removeAll { $0.id == textbookId }
            }
            errorMessage = "操作失败，请重试"
        }
    }

    // MARK: - 加载教材目录

    func loadTextbookToc(_ textbookId: String) async {
        do {
            let response: TextbookTocResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.textbooksToc)/\(textbookId)/toc"
            )
            textbookToc = response.units
        } catch {
            #if DEBUG
            print("加载目录失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载阅读笔记

    func loadReadingNotes(textbookId: String? = nil, refresh: Bool = false) async {
        isLoadingNotes = true
        defer { isLoadingNotes = false }

        do {
            var endpoint = APIConfig.Endpoints.textbooksNotes + "?limit=100"
            if let id = textbookId {
                endpoint += "&textbookId=\(id)"
            }

            // 使用兼容后端格式的响应类型
            let response: ReadingNotesAPIResponse = try await APIService.shared.get(endpoint)
            readingNotes = response.allNotes
            #if DEBUG
            print("加载笔记成功: \(readingNotes.count) 条")
            #endif
        } catch {
            #if DEBUG
            print("加载笔记失败: \(error)")
            #endif
            // 尝试打印更详细的错误信息
            if case let APIError.decodingError(decodingError) = error {
                #if DEBUG
                print("解码错误详情: \(decodingError)")
                #endif
            }
            readingNotes = []
        }
    }

    // MARK: - 创建笔记

    func createNote(
        textbookId: String?,
        sourceType: String,
        query: String?,
        content: String?,
        snippet: String?,
        page: Int?
    ) async -> ReadingNote? {
        do {
            let request = CreateReadingNoteRequest(
                textbookId: textbookId,
                sessionId: UUID().uuidString,
                sourceType: sourceType,
                query: query,
                content: content,
                snippet: snippet,
                page: page
            )
            let response: ReadingNoteDetailResponse = try await APIService.shared.post(
                APIConfig.Endpoints.textbooksNotes,
                body: request
            )
            readingNotes.insert(response.note, at: 0)
            return response.note
        } catch {
            #if DEBUG
            print("创建笔记失败: \(error)")
            #endif
            errorMessage = "保存笔记失败"
            return nil
        }
    }

    // MARK: - 更新笔记

    func updateNote(_ noteId: String, query: String? = nil, content: String? = nil, snippet: String? = nil) async -> Bool {
        do {
            let request = UpdateReadingNoteRequest(query: query, content: content, snippet: snippet)
            let _: ReadingNoteDetailResponse = try await APIService.shared.put(
                "\(APIConfig.Endpoints.textbooksNotes)/\(noteId)",
                body: request
            )
            await loadReadingNotes()
            return true
        } catch {
            #if DEBUG
            print("更新笔记失败: \(error)")
            #endif
            errorMessage = "更新笔记失败"
            return false
        }
    }

    // MARK: - 删除笔记

    func deleteNote(_ noteId: String) async -> Bool {
        do {
            let _: EmptyResponse = try await APIService.shared.delete(
                "\(APIConfig.Endpoints.textbooksNotes)/\(noteId)"
            )
            readingNotes.removeAll { $0.id == noteId }
            return true
        } catch {
            #if DEBUG
            print("删除笔记失败: \(error)")
            #endif
            errorMessage = "删除笔记失败"
            return false
        }
    }

    // MARK: - 切换笔记收藏状态

    func toggleNoteFavorite(_ noteId: String) async -> Bool {
        // 找到当前笔记
        guard let index = readingNotes.firstIndex(where: { $0.id == noteId }) else {
            return false
        }

        let currentNote = readingNotes[index]
        let wasFavorite = currentNote.isFavorite ?? false

        do {
            // 调用后端 API
            let response: NoteFavoriteResponse = try await APIService.shared.post(
                "\(APIConfig.Endpoints.textbooksNotes)/\(noteId)/favorite",
                body: EmptyRequest()
            )

            // 更新本地数据
            if let data = response.data {
                // 重新加载笔记列表以获取最新状态
                await loadReadingNotes()
            }

            return true
        } catch {
            #if DEBUG
            print("切换收藏失败: \(error)")
            #endif
            errorMessage = wasFavorite ? "取消收藏失败" : "收藏失败"
            return false
        }
    }

    // MARK: - 搜索教材

    func searchTextbooks(_ query: String) async {
        searchText = query
        await loadPublicTextbooks(refresh: true)
    }

    // MARK: - 应用筛选

    func applyFilters(subject: String, grade: Int, semester: String, version: String) async {
        selectedSubject = subject
        selectedGrade = grade
        selectedSemester = semester
        selectedVersion = version
        await loadPublicTextbooks(refresh: true)
    }

    // MARK: - 重置筛选

    func resetFilters() async {
        selectedSubject = ""
        selectedGrade = 0
        selectedSemester = ""
        selectedVersion = ""
        searchText = ""
        await loadPublicTextbooks(refresh: true)
    }
}

// MARK: - 辅助类型

struct EmptyRequest: Encodable {}
struct EmptyResponse: Decodable {}

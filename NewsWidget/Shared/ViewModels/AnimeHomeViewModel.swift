import Foundation
import Observation

// 首頁 ViewModel。
// 負責載入 Jikan 分類、依分類載入動漫列表、以及把今日放送資料存給 Widget 使用。
@MainActor
@Observable
final class AnimeHomeViewModel {
    private let settingsStore: AppGroupSettingsStore
    private var repository: AnimeRepository

    // private(set) 讓 View 可以讀取狀態，但修改必須透過 ViewModel method。
    private(set) var categories: [AnimeCategory] = []
    private(set) var selectedCategory: AnimeCategory?
    private(set) var brief: AnimeBrief = .empty
    private(set) var isLoading = false
    private(set) var isLoadingCategories = false

    convenience init() {
        self.init(
            settingsStore: AppGroupSettingsStore(),
            repository: ProcessInfo.processInfo.arguments.contains("-useMockAnimeRepository")
                ? MockAnimeRepository()
                : JikanAnimeRepository()
        )
    }

    // 保留注入點，之後寫 XCTest 時可以塞 fake repository。
    init(settingsStore: AppGroupSettingsStore, repository: AnimeRepository) {
        self.settingsStore = settingsStore
        self.repository = repository
    }

    func onAppear() async {
        await loadCategories()
        await refreshTodayScheduleForWidget()
    }

    func selectCategory(_ category: AnimeCategory) async {
        selectedCategory = category
        await refresh()
    }

    func refresh() async {
        guard let selectedCategory else { return }

        isLoading = true
        defer { isLoading = false }

        let loadedBrief = await repository.fetchAnimeBrief(for: selectedCategory)
        brief = loadedBrief
        settingsStore.saveLatestAnimeBrief(loadedBrief)
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }

        isLoadingCategories = true
        let loadedCategories = await repository.fetchCategories()
        isLoadingCategories = false

        categories = loadedCategories

        if let firstCategory = loadedCategories.first {
            selectedCategory = firstCategory
            await refresh()
        }
    }

    private func refreshTodayScheduleForWidget() async {
        let todayBrief = await repository.fetchAnimeBrief(for: .todaySchedule)
        settingsStore.saveLatestTodayAnimeBrief(todayBrief)
    }
}

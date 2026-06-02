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
    private(set) var isLoadingMore = false
    private(set) var isLoadingCategories = false
    private(set) var hasMoreAnime = true
    private var currentPage = 1

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

        // 切換分類或手動重新整理時，都從第 1 頁重新開始。
        currentPage = 1
        hasMoreAnime = true
        let loadedBrief = await repository.fetchAnimeBrief(for: selectedCategory, page: currentPage)
        brief = loadedBrief
        hasMoreAnime = loadedBrief.items.count == 10
        settingsStore.saveLatestAnimeBrief(loadedBrief)
    }

    // 當列表最後一筆即將出現在畫面上時，讀取下一頁並接在既有資料後面。
    // item 參數可以避免每一列出現時都觸發 request。
    func loadMoreIfNeeded(currentItem item: AnimeSummary) async {
        guard item.id == brief.items.last?.id,
              let selectedCategory,
              !isLoading,
              !isLoadingMore,
              hasMoreAnime else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        let loadedBrief = await repository.fetchAnimeBrief(for: selectedCategory, page: nextPage)

        // API 偶爾可能回傳重複資料，以 id 過濾後再 append。
        let existingIDs = Set(brief.items.map(\.id))
        let newItems = loadedBrief.items.filter { !existingIDs.contains($0.id) }
        brief = AnimeBrief(
            title: brief.title,
            mode: brief.mode,
            items: brief.items + newItems,
            updatedAt: loadedBrief.updatedAt
        )
        currentPage = nextPage
        hasMoreAnime = loadedBrief.items.count == 10
        settingsStore.saveLatestAnimeBrief(brief)
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

import XCTest
@testable import NewsWidget

// ViewModel 會更新 SwiftUI 畫面狀態，所以它被設計在 MainActor 上使用。
// 測試 ViewModel 時也放在 MainActor，可以貼近實際 UI 使用情境。
@MainActor
final class AnimeHomeViewModelTests: XCTestCase {
    func testOnAppearLoadsCategoriesAndPersistsTodayBriefForWidget() async {
        // 這個測試同時驗證兩件事：
        // 1. App 啟動後會先載入 Jikan 分類，並預設選第一個分類。
        // 2. App 會另外抓「今日放送」並存進 Widget 專用的 storage。
        let suiteName = "AnimeHomeViewModelTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = AppGroupSettingsStore(userDefaults: userDefaults)
        // 透過 dependency injection 傳入 mock repository 和測試用 store。
        // 好處是測試不需要真的打 API，也不會寫到正式 App Group。
        let viewModel = AnimeHomeViewModel(settingsStore: store, repository: MockAnimeRepository())

        await viewModel.onAppear()

        // ViewModel 自己的狀態要正確。
        XCTAssertFalse(viewModel.categories.isEmpty)
        XCTAssertEqual(viewModel.selectedCategory?.name, "Action")
        XCTAssertEqual(viewModel.brief.title, "Action")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingCategories)
        // App 目前分類列表和 Widget 今日提醒分開儲存，避免 Widget 被分類切換影響。
        XCTAssertEqual(store.loadLatestAnimeBrief()?.title, "Action")
        XCTAssertEqual(store.loadLatestTodayAnimeBrief()?.mode, .todaySchedule)

        // 手動清掉這次測試建立的 UserDefaults suite。
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    func testSelectCategoryRefreshesList() async {
        let store = AppGroupSettingsStore(userDefaults: UserDefaults(suiteName: "AnimeHomeViewModelTests.\(UUID().uuidString)")!)
        let viewModel = AnimeHomeViewModel(settingsStore: store, repository: MockAnimeRepository())

        await viewModel.onAppear()
        let category = AnimeCategory(id: 4, name: "Comedy", count: 8_800)
        await viewModel.selectCategory(category)

        XCTAssertEqual(viewModel.selectedCategory, category)
        XCTAssertEqual(viewModel.brief.title, "Comedy")
        XCTAssertFalse(viewModel.brief.items.isEmpty)
    }

    func testLoadMoreAppendsNextPage() async {
        // 使用專門的 fake repository，第一頁和第二頁各回傳 10 筆資料。
        // 這樣可以精準驗證 ViewModel 是 append，而不是覆蓋原本列表。
        let store = AppGroupSettingsStore(userDefaults: UserDefaults(suiteName: "AnimeHomeViewModelTests.\(UUID().uuidString)")!)
        let viewModel = AnimeHomeViewModel(settingsStore: store, repository: PagingAnimeRepository())

        await viewModel.onAppear()
        let firstPageLastItem = viewModel.brief.items.last!
        await viewModel.loadMoreIfNeeded(currentItem: firstPageLastItem)

        XCTAssertEqual(viewModel.brief.items.count, 20)
        XCTAssertEqual(viewModel.brief.items.first?.id, 1)
        XCTAssertEqual(viewModel.brief.items.last?.id, 20)
        XCTAssertFalse(viewModel.isLoadingMore)
    }

    func testLoadMoreStopsWhenNextPageIsEmpty() async {
        // 第三頁為空時，ViewModel 應該停止繼續請求。
        // 畫面會根據 hasMoreAnime 顯示「沒有更多資料」。
        let store = AppGroupSettingsStore(userDefaults: UserDefaults(suiteName: "AnimeHomeViewModelTests.\(UUID().uuidString)")!)
        let viewModel = AnimeHomeViewModel(settingsStore: store, repository: PagingAnimeRepository())

        await viewModel.onAppear()
        await viewModel.loadMoreIfNeeded(currentItem: viewModel.brief.items.last!)
        await viewModel.loadMoreIfNeeded(currentItem: viewModel.brief.items.last!)

        XCTAssertEqual(viewModel.brief.items.count, 20)
        XCTAssertFalse(viewModel.hasMoreAnime)
        XCTAssertFalse(viewModel.isLoadingMore)
    }

    func testRefreshReplacesLoadedPagesWithFirstPage() async {
        // Arrange：先模擬使用者往下滑，讓列表載入第 1 頁和第 2 頁，共 20 筆。
        let store = AppGroupSettingsStore(userDefaults: UserDefaults(suiteName: "AnimeHomeViewModelTests.\(UUID().uuidString)")!)
        let viewModel = AnimeHomeViewModel(settingsStore: store, repository: PagingAnimeRepository())

        await viewModel.onAppear()
        await viewModel.loadMoreIfNeeded(currentItem: viewModel.brief.items.last!)
        XCTAssertEqual(viewModel.brief.items.count, 20)

        // Act：模擬點擊右上角重新整理按鈕後執行的 refresh。
        await viewModel.refresh()

        // Assert：舊分頁資料要被移除，只留下重新取得的第 1 頁。
        XCTAssertEqual(viewModel.brief.items.count, 10)
        XCTAssertEqual(viewModel.brief.items.first?.id, 1)
        XCTAssertEqual(viewModel.brief.items.last?.id, 10)
    }
}

// 測試無限捲動用的 fake repository。
// 分類第 1 頁回傳 id 1...10，第 2 頁回傳 id 11...20。
private struct PagingAnimeRepository: AnimeRepository {
    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief {
        AnimeBrief(title: mode.title, mode: mode, items: [], updatedAt: .now)
    }

    func fetchCategories() async -> [AnimeCategory] {
        [AnimeCategory(id: 1, name: "Action", count: 20)]
    }

    func fetchAnimeBrief(for category: AnimeCategory, page: Int) async -> AnimeBrief {
        guard page <= 2 else {
            return AnimeBrief(title: category.name, mode: .seasonal, items: [], updatedAt: .now)
        }

        let startID = ((page - 1) * 10) + 1
        let items = (startID..<(startID + 10)).map { id in
            AnimeSummary(id: id, title: "Anime \(id)")
        }

        return AnimeBrief(title: category.name, mode: .seasonal, items: items, updatedAt: .now)
    }
}

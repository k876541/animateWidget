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
}

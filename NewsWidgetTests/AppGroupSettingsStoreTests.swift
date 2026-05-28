import XCTest
@testable import NewsWidget

// Store 會被 App / Widget 共用，實務上會寫入 App Group UserDefaults。
// 測試時不使用真正的 App Group，避免污染使用者實際資料。
@MainActor
final class AppGroupSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: AppGroupSettingsStore!

    override func setUp() {
        super.setUp()
        // 每個測試都建立一個唯一的 UserDefaults suite。
        // 這樣測試彼此隔離，不會因上一個測試寫入的資料影響下一個測試。
        suiteName = "NewsWidgetTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = AppGroupSettingsStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        // 測試結束後清掉暫存資料。
        // XCTest 每個 test method 都會跑一次 setUp / tearDown，保持環境乾淨很重要。
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSelectedAnimeModeDefaultsToSeasonal() {
        // 沒有任何使用者設定時，App 應該有穩定的預設值。
        // 這可以避免首頁或 Widget 在第一次啟動時沒有資料可用。
        XCTAssertEqual(store.loadSelectedAnimeMode(), .seasonal)
    }

    func testSelectedAnimeModeRoundTrips() {
        // Round trip 的意思是「寫入什麼，讀出來就應該是什麼」。
        // 這類測試很適合用來驗證 UserDefaults / Codable / storage key 是否正確。
        store.saveSelectedAnimeMode(.todaySchedule)

        XCTAssertEqual(store.loadSelectedAnimeMode(), .todaySchedule)
    }

    func testLatestAnimeBriefRoundTrips() {
        // 建一份最小但完整的資料，確認 AnimeBrief 可以被正確 encode 後存入 UserDefaults，
        // 也可以再 decode 回一模一樣的 model。
        let brief = AnimeBrief(
            title: "Test Brief",
            mode: .upcoming,
            items: [
                AnimeSummary(
                    id: 1,
                    title: "Test Anime",
                    imageAssetName: "s-l1200",
                    score: 8.5,
                    episodes: 12,
                    airingDay: "Friday",
                    synopsis: "Test synopsis",
                    source: "Unit Test"
                )
            ],
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        store.saveLatestAnimeBrief(brief)

        // AnimeBrief / AnimeSummary 有符合 Equatable，所以可以直接比較整包 model。
        // 若未來 model 新增欄位，這個測試也能提醒我們 storage 是否要同步處理。
        XCTAssertEqual(store.loadLatestAnimeBrief(), brief)
    }

    func testLatestTodayAnimeBriefRoundTrips() {
        // Widget 現在只需要今日放送，所以另外用 latestTodayAnimeBrief 儲存。
        // 這樣 App 下方分類切換時，不會把 Widget 的提醒資料覆蓋成其他分類。
        let brief = AnimeBrief(
            title: "今日放送",
            mode: .todaySchedule,
            items: [
                AnimeSummary(
                    id: 21,
                    title: "One Piece",
                    imageAssetName: "s-l1200",
                    airingDay: "Sunday",
                    source: "Unit Test"
                )
            ],
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        store.saveLatestTodayAnimeBrief(brief)

        XCTAssertEqual(store.loadLatestTodayAnimeBrief(), brief)
    }
}

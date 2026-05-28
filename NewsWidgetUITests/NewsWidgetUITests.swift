import XCTest

// UI Test 是從使用者角度操作 App：
// 它不直接呼叫 ViewModel 或 Repository，而是啟動 App、找畫面元件、點擊、再檢查畫面結果。
final class NewsWidgetUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI 測試通常一個關鍵步驟失敗後，後面也很難有意義。
        // 設成 false 可以讓測試在第一個失敗點就停止，錯誤比較好判斷。
        continueAfterFailure = false
    }

    func testHomeShowsAnimeCategoriesAndPosterRows() throws {
        // XCUIApplication 代表被測試的 App。
        // launch() 會真的打開 simulator 裡的 App，接著才能用 accessibility 找元件。
        let app = XCUIApplication()
        // UI Test 不應該依賴真實網路，否則 API 慢或暫時失敗會讓測試不穩。
        // App 看到這個 launch argument 後，會改用 MockAnimeRepository。
        app.launchArguments = ["-useMockAnimeRepository"]
        app.launch()

        // waitForExistence 用在啟動畫面可能需要一點時間的元件。
        // 比起直接 exists，它比較不容易因 simulator 啟動慢而誤判失敗。
        XCTAssertTrue(app.staticTexts["Anime Widget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["動畫分類"].exists)
        XCTAssertTrue(app.buttons["Action"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Comedy"].exists)

        // 模擬使用者點「Action」分類。
        // app.buttons["Action"] 能找到按鈕，是因為 SwiftUI button 有 accessibility label。
        app.buttons["Action"].tap()

        // 點擊後，下方列表應該切換成 Action 對應的假資料。
        XCTAssertTrue(app.staticTexts["Sousou no Frieren"].waitForExistence(timeout: 3))
        // 這裡找的是 Image 的 accessibility label。
        // 測 UI 圖片時，不會比較圖片像素，而是確認代表圖片的 UI 元件有出現在畫面上。
        XCTAssertTrue(app.images["Sousou no Frieren 海報"].exists)

        // 點擊動畫列後，應該出現滿版海報預覽 overlay。
        app.staticTexts["Sousou no Frieren"].tap()
        let overlay = app.buttons["poster-preview-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))

        // Overlay 任意位置點擊都會關閉。
        overlay.tap()
        XCTAssertFalse(overlay.waitForExistence(timeout: 1))
    }
}

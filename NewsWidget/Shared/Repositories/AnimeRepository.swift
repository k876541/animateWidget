import Foundation

// 動漫資料來源抽象層。
// ViewModel 只依賴這個 protocol，之後要從 mock 換成 Jikan API 時不用改 UI。
protocol AnimeRepository: Sendable {
    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief
    func fetchCategories() async -> [AnimeCategory]
    func fetchAnimeBrief(for category: AnimeCategory, page: Int) async -> AnimeBrief
}

extension AnimeRepository {
    // 分類列表第一次載入時預設讀取第 1 頁。
    // 保留這個便利方法，呼叫端不需要每次都手動填 page: 1。
    func fetchAnimeBrief(for category: AnimeCategory) async -> AnimeBrief {
        await fetchAnimeBrief(for: category, page: 1)
    }
}

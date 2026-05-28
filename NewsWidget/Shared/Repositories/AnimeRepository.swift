import Foundation

// 動漫資料來源抽象層。
// ViewModel 只依賴這個 protocol，之後要從 mock 換成 Jikan API 時不用改 UI。
protocol AnimeRepository: Sendable {
    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief
    func fetchCategories() async -> [AnimeCategory]
    func fetchAnimeBrief(for category: AnimeCategory) async -> AnimeBrief
}

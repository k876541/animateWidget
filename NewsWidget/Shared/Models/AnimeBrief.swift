import Foundation

// Widget / App 共用的一份動漫簡報。
// App 會把這份資料存進 App Group，Widget 再從 App Group 讀出來。
nonisolated struct AnimeBrief: Codable, Equatable, Sendable {
    let title: String
    let mode: AnimeWidgetMode
    let items: [AnimeSummary]
    let updatedAt: Date

    // 畫面尚未載入資料時使用的空狀態。
    static let empty = AnimeBrief(
        title: "Anime Widget",
        mode: .seasonal,
        items: [],
        updatedAt: .now
    )
}

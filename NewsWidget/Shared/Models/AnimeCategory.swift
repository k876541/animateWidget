import Foundation

// Jikan /genres/anime 回傳的動畫分類。
// App 中間的橫向分類卡片會使用這個 model。
nonisolated struct AnimeCategory: Identifiable, Codable, Equatable, Sendable {
    // Jikan 使用 mal_id 當 genre id。
    let id: Int
    let name: String
    let count: Int?
}

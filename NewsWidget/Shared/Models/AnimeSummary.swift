import Foundation

// 單一動畫摘要。
// 這個 model 是 App 列表和 Widget 顯示的最小資料單位。
struct AnimeSummary: Identifiable, Codable, Equatable, Sendable {
    // Jikan / MyAnimeList 使用 mal_id 當作品 id，所以這裡用 Int。
    let id: Int
    let title: String
    // 第一版先支援本機 asset name，讓 mock data 可以直接顯示專案內圖片。
    // 未來接 Jikan 時，會優先使用 imageURL 顯示遠端海報圖。
    let imageAssetName: String?
    let imageURL: URL?
    let score: Double?
    let episodes: Int?
    let airingDay: String?
    let synopsis: String?
    let source: String?

    init(
        id: Int,
        title: String,
        imageAssetName: String? = nil,
        imageURL: URL? = nil,
        score: Double? = nil,
        episodes: Int? = nil,
        airingDay: String? = nil,
        synopsis: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.title = title
        self.imageAssetName = imageAssetName
        self.imageURL = imageURL
        self.score = score
        self.episodes = episodes
        self.airingDay = airingDay
        self.synopsis = synopsis
        self.source = source
    }
}

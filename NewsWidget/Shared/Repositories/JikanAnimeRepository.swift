import Foundation
import OSLog

// 正式串接 Jikan REST API 的 repository。
// Jikan 是 unofficial MyAnimeList API，base URL 是 https://api.jikan.moe/v4。
struct JikanAnimeRepository: AnimeRepository {
    // Logger 會把訊息輸出到 Xcode Console。
    // category 使用 Jikan，方便在 Console 搜尋框輸入 Jikan 過濾網路紀錄。
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NewsWidget",
        category: "Jikan"
    )

    private let baseURL: URL
    private let urlSession: URLSession

    init(
        baseURL: URL = URL(string: "https://api.jikan.moe/v4")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief {
        do {
            let url = try makeURL(for: mode)
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanAnimeListResponse.self, from: data)
            let items = result.data
                .map { $0.asAnimeSummary(source: url.absoluteString) }
            Self.logger.info("[Jikan] mode=\(mode.rawValue, privacy: .public) decoded \(items.count) anime")

            return AnimeBrief(
                title: mode.title,
                mode: mode,
                items: Array(items.prefix(10)),
                updatedAt: .now
            )
        } catch {
            // 正式環境不回退到假資料，避免使用者誤以為 API 回傳了這些動畫。
            // ViewModel 之後可再加上 error state，顯示重新整理提示。
            Self.logger.error("[Jikan] mode=\(mode.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return makeEmptyBrief(title: mode.title, mode: mode)
        }
    }

    func fetchCategories() async -> [AnimeCategory] {
        do {
            let url = baseURL.appendingPathComponent("genres/anime")
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanGenreListResponse.self, from: data)
            Self.logger.info("[Jikan] decoded \(result.data.count) categories")
            return result.data.map { $0.asAnimeCategory() }
        } catch {
            // API 失敗時先顯示空分類，不混入只供測試使用的固定資料。
            Self.logger.error("[Jikan] categories failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    func fetchAnimeBrief(for category: AnimeCategory, page: Int) async -> AnimeBrief {
        do {
            let url = try makeURL(for: category, page: page)
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanAnimeListResponse.self, from: data)
            let items = result.data
                .map { $0.asAnimeSummary(source: url.absoluteString) }
            Self.logger.info("[Jikan] category=\(category.name, privacy: .public) page=\(page) decoded \(items.count) anime")

            return AnimeBrief(
                title: category.name,
                mode: .seasonal,
                items: Array(items.prefix(10)),
                updatedAt: .now
            )
        } catch {
            Self.logger.error("[Jikan] category=\(category.name, privacy: .public) page=\(page) failed: \(String(describing: error), privacy: .public)")
            return makeEmptyBrief(title: category.name, mode: .seasonal)
        }
    }

    // Repository protocol 目前沒有 throws，因此先用空列表表達「沒有取得正式資料」。
    private func makeEmptyBrief(title: String, mode: AnimeWidgetMode) -> AnimeBrief {
        AnimeBrief(title: title, mode: mode, items: [], updatedAt: .now)
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }

    private func fetchData(from url: URL) async throws -> Data {
        // 每次真正送出 URLSession request 前都會留下紀錄。
        // 往下捲動時，可從 URL 尾端確認 page 是否依序變成 2、3、4。
        Self.logger.info("[Jikan] request \(url.absoluteString, privacy: .public)")
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("[Jikan] response is not HTTP")
            throw JikanRepositoryError.invalidResponse
        }

        Self.logger.info("[Jikan] response status=\(httpResponse.statusCode) bytes=\(data.count)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw JikanRepositoryError.invalidResponse
        }

        return data
    }

    private func makeURL(for mode: AnimeWidgetMode) throws -> URL {
        let endpoint = baseURL.appendingPathComponent(mode.jikanEndpointPath)

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw JikanRepositoryError.invalidURL
        }

        components.queryItems = mode.jikanQueryItems

        guard let url = components.url else {
            throw JikanRepositoryError.invalidURL
        }

        return url
    }

    private func makeURL(for category: AnimeCategory, page: Int) throws -> URL {
        let endpoint = baseURL.appendingPathComponent("anime")

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw JikanRepositoryError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "genres", value: String(category.id)),
            URLQueryItem(name: "order_by", value: "popularity"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else {
            throw JikanRepositoryError.invalidURL
        }

        return url
    }
}

private enum JikanRepositoryError: Error {
    case invalidURL
    case invalidResponse
}

// Jikan list endpoints 都會回傳 {"data": [...]}。
// 這裡只 decode App 目前需要的欄位，避免 model 被 API 的完整 response 綁死。
private struct JikanAnimeListResponse: Decodable {
    let data: [JikanAnime]
}

private struct JikanGenreListResponse: Decodable {
    let data: [JikanGenre]
}

private struct JikanGenre: Decodable {
    let malID: Int
    let name: String
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case count
    }

    func asAnimeCategory() -> AnimeCategory {
        AnimeCategory(id: malID, name: name, count: count)
    }
}

private struct JikanAnime: Decodable {
    let malID: Int
    let title: String
    let titleEnglish: String?
    let images: JikanImages?
    let score: Double?
    let episodes: Int?
    let synopsis: String?
    let broadcast: JikanBroadcast?

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case title
        case titleEnglish = "title_english"
        case images
        case score
        case episodes
        case synopsis
        case broadcast
    }

    func asAnimeSummary(source: String) -> AnimeSummary {
        AnimeSummary(
            id: malID,
            title: titleEnglish ?? title,
            imageURL: images?.jpg?.largeImageURL ?? images?.jpg?.imageURL,
            score: score,
            episodes: episodes,
            airingDay: broadcast?.day,
            synopsis: synopsis,
            source: source
        )
    }
}

private struct JikanImages: Decodable {
    let jpg: JikanImageURLs?
}

private struct JikanImageURLs: Decodable {
    let imageURL: URL?
    let largeImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case largeImageURL = "large_image_url"
    }
}

private struct JikanBroadcast: Decodable {
    let day: String?
}

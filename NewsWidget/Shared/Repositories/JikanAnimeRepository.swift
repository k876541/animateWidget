import Foundation

// 正式串接 Jikan REST API 的 repository。
// Jikan 是 unofficial MyAnimeList API，base URL 是 https://api.jikan.moe/v4。
struct JikanAnimeRepository: AnimeRepository {
    private let baseURL: URL
    private let urlSession: URLSession
    private let fallbackRepository: AnimeRepository

    init(
        baseURL: URL = URL(string: "https://api.jikan.moe/v4")!,
        urlSession: URLSession = .shared,
        fallbackRepository: AnimeRepository = MockAnimeRepository()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.fallbackRepository = fallbackRepository
    }

    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief {
        do {
            let url = try makeURL(for: mode)
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanAnimeListResponse.self, from: data)
            let items = result.data.map { $0.asAnimeSummary(source: url.absoluteString) }

            return AnimeBrief(
                title: mode.title,
                mode: mode,
                items: Array(items.prefix(10)),
                updatedAt: .now
            )
        } catch {
            // API 失敗時回到假資料，讓畫面與 Widget 不會整個空白。
            // 真正產品可再加上 error state，提示目前正在顯示快取或備援資料。
            return await fallbackRepository.fetchAnimeBrief(for: mode)
        }
    }

    func fetchCategories() async -> [AnimeCategory] {
        do {
            let url = baseURL.appendingPathComponent("genres/anime")
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanGenreListResponse.self, from: data)
            return result.data.map { $0.asAnimeCategory() }
        } catch {
            return await fallbackRepository.fetchCategories()
        }
    }

    func fetchAnimeBrief(for category: AnimeCategory) async -> AnimeBrief {
        do {
            let url = try makeURL(for: category)
            let data = try await fetchData(from: url)
            let result = try decoder.decode(JikanAnimeListResponse.self, from: data)
            let items = result.data.map { $0.asAnimeSummary(source: url.absoluteString) }

            return AnimeBrief(
                title: category.name,
                mode: .seasonal,
                items: Array(items.prefix(10)),
                updatedAt: .now
            )
        } catch {
            return await fallbackRepository.fetchAnimeBrief(for: category)
        }
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
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

    private func makeURL(for category: AnimeCategory) throws -> URL {
        let endpoint = baseURL.appendingPathComponent("anime")

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw JikanRepositoryError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "genres", value: String(category.id)),
            URLQueryItem(name: "order_by", value: "popularity"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "limit", value: "10")
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

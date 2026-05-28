import XCTest
@testable import NewsWidget

// 測試類別加上 @MainActor，是因為目前 app 的資料模型與 ViewModel
// 有些會在主執行緒使用。測試也跟著跑在 MainActor，可以避免 Swift 6
// 對 actor isolation 的編譯錯誤。
@MainActor
final class AnimeRepositoryTests: XCTestCase {
    func testMockRepositoryReturnsSelectedModeBrief() async {
        // Arrange：準備要被測試的物件。
        // 這裡使用 MockAnimeRepository，代表測試不依賴網路，也不會因 API 掛掉而失敗。
        let repository = MockAnimeRepository()

        // Act：執行真正想驗證的行為。
        // repository 方法是 async，未來換成真 API 時測試結構也不用大改。
        let brief = await repository.fetchAnimeBrief(for: .topAiring)

        // Assert：確認結果是否符合預期。
        // 這個測試保護「選熱門連載時，回來的資料也必須是熱門連載」。
        XCTAssertEqual(brief.mode, .topAiring)
        XCTAssertEqual(brief.title, "熱門連載")
        XCTAssertFalse(brief.items.isEmpty)
        // 因為首頁左側海報目前吃本地 asset，所以測試每筆假資料都有填圖片名稱。
        XCTAssertTrue(brief.items.allSatisfy { $0.imageAssetName == "s-l1200" })
    }

    func testAnimeWidgetModeJikanPaths() {
        // 這裡測的是 enum 與 Jikan API path 的對應關係。
        // 之後若要接真 API，這些 path 是組 URL 的基礎，寫測試可以避免改 enum 時不小心改壞 endpoint。
        XCTAssertTrue(AnimeWidgetMode.todaySchedule.jikanPath.hasPrefix("/schedules?filter="))
        XCTAssertEqual(AnimeWidgetMode.seasonal.jikanPath, "/seasons/now?limit=10")
        XCTAssertEqual(AnimeWidgetMode.topAiring.jikanPath, "/top/anime?filter=airing&limit=10")
        XCTAssertEqual(AnimeWidgetMode.upcoming.jikanPath, "/seasons/upcoming?limit=10")
    }

    func testMockRepositoryReturnsCategories() async {
        let repository = MockAnimeRepository()

        let categories = await repository.fetchCategories()

        XCTAssertEqual(categories.first, AnimeCategory(id: 1, name: "Action", count: 5_000))
        XCTAssertFalse(categories.isEmpty)
    }

    func testJikanRepositoryDecodesAnimeListResponse() async throws {
        // 這個測試用假的 URLProtocol 攔截 URLSession request。
        // 好處是可以測正式 repository 的 JSON decode 邏輯，但不需要真的打 Jikan API。
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v4/seasons/now")
            XCTAssertEqual(request.url?.query, "limit=10")

            let json = """
            {
              "data": [
                {
                  "mal_id": 52991,
                  "title": "Sousou no Frieren",
                  "title_english": "Frieren: Beyond Journey's End",
                  "images": {
                    "jpg": {
                      "image_url": "https://example.com/frieren.jpg",
                      "large_image_url": "https://example.com/frieren-large.jpg"
                    }
                  },
                  "score": 9.3,
                  "episodes": 28,
                  "synopsis": "After the party defeats the Demon King, Frieren begins a new journey.",
                  "broadcast": {
                    "day": "Fridays"
                  }
                }
              ]
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data(json.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let repository = JikanAnimeRepository(urlSession: session)

        let brief = await repository.fetchAnimeBrief(for: .seasonal)

        XCTAssertEqual(brief.mode, .seasonal)
        XCTAssertEqual(brief.items.first?.id, 52991)
        XCTAssertEqual(brief.items.first?.title, "Frieren: Beyond Journey's End")
        XCTAssertEqual(brief.items.first?.imageURL?.absoluteString, "https://example.com/frieren-large.jpg")
        XCTAssertEqual(brief.items.first?.airingDay, "Fridays")
    }

    func testJikanRepositoryDecodesGenresResponse() async throws {
        // Jikan 的分類來源是 /genres/anime，畫面中間的橫向分類卡片會使用這份資料。
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v4/genres/anime")

            let json = """
            {
              "data": [
                {
                  "mal_id": 1,
                  "name": "Action",
                  "count": 5123
                }
              ]
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data(json.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let repository = JikanAnimeRepository(urlSession: session)

        let categories = await repository.fetchCategories()

        XCTAssertEqual(categories, [AnimeCategory(id: 1, name: "Action", count: 5123)])
    }
}

private final class MockURLProtocol: URLProtocol {
    // URLProtocol 的 API 需要用 static 入口讓 URLSession 找到 handler。
    // 這個 handler 只在單一測試方法內設定與使用，所以用 nonisolated(unsafe)
    // 告訴 Swift 6：這個 shared state 的同步由測試流程自己保證。
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            XCTFail("MockURLProtocol requestHandler is missing.")
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

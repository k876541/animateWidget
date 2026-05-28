import Foundation

// 第一版先使用假資料，讓 App / Widget 流程先穩定。
// 下一步可以新增 JikanAnimeRepository，把資料來源換成 https://api.jikan.moe/v4。
struct MockAnimeRepository: AnimeRepository {
    func fetchAnimeBrief(for mode: AnimeWidgetMode) async -> AnimeBrief {
        let items = Self.itemsByMode[mode, default: []]

        return AnimeBrief(
            title: mode.title,
            mode: mode,
            items: Array(items.prefix(10)),
            updatedAt: .now
        )
    }

    func fetchCategories() async -> [AnimeCategory] {
        Self.categories
    }

    func fetchAnimeBrief(for category: AnimeCategory) async -> AnimeBrief {
        let items = Self.itemsByCategoryID[category.id, default: Self.itemsByMode[.seasonal, default: []]]

        return AnimeBrief(
            title: category.name,
            mode: .seasonal,
            items: Array(items.prefix(10)),
            updatedAt: .now
        )
    }

    // Widget preview 或 App 還沒寫入 latestAnimeBrief 時使用的預覽資料。
    static let fallbackBrief = AnimeBrief(
        title: AnimeWidgetMode.seasonal.title,
        mode: .seasonal,
        items: Array(itemsByMode[.seasonal, default: []].prefix(5)),
        updatedAt: .now
    )

    // Widget 只顯示今日放送，用這份資料做預覽和 App 尚未寫入時的 fallback。
    static let fallbackTodayBrief = AnimeBrief(
        title: AnimeWidgetMode.todaySchedule.title,
        mode: .todaySchedule,
        items: Array(itemsByMode[.todaySchedule, default: []].prefix(5)),
        updatedAt: .now
    )

    static let categories = [
        AnimeCategory(id: 1, name: "Action", count: 5_000),
        AnimeCategory(id: 2, name: "Adventure", count: 4_200),
        AnimeCategory(id: 4, name: "Comedy", count: 8_800),
        AnimeCategory(id: 8, name: "Drama", count: 3_700),
        AnimeCategory(id: 10, name: "Fantasy", count: 4_900)
    ]

    private static let itemsByCategoryID: [Int: [AnimeSummary]] = [
        1: itemsByMode[.topAiring, default: []],
        2: itemsByMode[.todaySchedule, default: []],
        4: itemsByMode[.seasonal, default: []],
        8: itemsByMode[.upcoming, default: []],
        10: itemsByMode[.seasonal, default: []]
    ]

    // 用不同 mode 分組，模擬 Jikan 不同 endpoint 回來的資料。
    private static let itemsByMode: [AnimeWidgetMode: [AnimeSummary]] = [
        .todaySchedule: [
            AnimeSummary(
                id: 21,
                title: "One Piece",
                imageAssetName: "s-l1200",
                score: 8.7,
                episodes: nil,
                airingDay: "Sunday",
                synopsis: "草帽一行人持續航向偉大航道，尋找傳說中的大秘寶。",
                source: "MAL Schedule"
            ),
            AnimeSummary(
                id: 58567,
                title: "Sakamoto Days",
                imageAssetName: "s-l1200",
                score: 7.8,
                episodes: 11,
                airingDay: "Saturday",
                synopsis: "退休殺手坂本太郎在日常生活中再次捲入危機。",
                source: "MAL Schedule"
            ),
            AnimeSummary(
                id: 54789,
                title: "My Hero Academia",
                imageAssetName: "s-l1200",
                score: 7.9,
                episodes: nil,
                airingDay: "Saturday",
                synopsis: "英雄與敵人的全面衝突持續升溫。",
                source: "MAL Schedule"
            )
        ],
        .seasonal: [
            AnimeSummary(
                id: 58514,
                title: "Witch Watch",
                imageAssetName: "s-l1200",
                score: 7.4,
                episodes: nil,
                airingDay: "Sunday",
                synopsis: "魔女與青梅竹馬的同居日常，混合校園、奇幻與喜劇節奏。",
                source: "Jikan /seasons/now"
            ),
            AnimeSummary(
                id: 59062,
                title: "Lazarus",
                imageAssetName: "s-l1200",
                score: 7.2,
                episodes: 13,
                airingDay: "Sunday",
                synopsis: "近未來科幻動作作品，描寫人類面臨藥物危機後的追查行動。",
                source: "Jikan /seasons/now"
            ),
            AnimeSummary(
                id: 56845,
                title: "Fire Force Season 3",
                imageAssetName: "s-l1200",
                score: 7.7,
                episodes: nil,
                airingDay: "Friday",
                synopsis: "特殊消防隊面對更大的真相與戰鬥。",
                source: "Jikan /seasons/now"
            )
        ],
        .topAiring: [
            AnimeSummary(
                id: 52991,
                title: "Sousou no Frieren",
                imageAssetName: "s-l1200",
                score: 9.3,
                episodes: 28,
                airingDay: nil,
                synopsis: "勇者一行打倒魔王後，精靈魔法使芙莉蓮重新理解時間與情感。",
                source: "Jikan /top/anime"
            ),
            AnimeSummary(
                id: 5114,
                title: "Fullmetal Alchemist: Brotherhood",
                imageAssetName: "s-l1200",
                score: 9.1,
                episodes: 64,
                airingDay: nil,
                synopsis: "愛德華與阿爾馮斯為取回失去的一切踏上旅程。",
                source: "Jikan /top/anime"
            ),
            AnimeSummary(
                id: 9253,
                title: "Steins;Gate",
                imageAssetName: "s-l1200",
                score: 9.1,
                episodes: 24,
                airingDay: nil,
                synopsis: "偶然發明時間機器的研究社，逐步捲入無法回頭的世界線。",
                source: "Jikan /top/anime"
            )
        ],
        .upcoming: [
            AnimeSummary(
                id: 52299,
                title: "Solo Leveling Season 2",
                imageAssetName: "s-l1200",
                score: nil,
                episodes: nil,
                airingDay: nil,
                synopsis: "成振宇的獵人之路邁向新的階段。",
                source: "Jikan /seasons/upcoming"
            ),
            AnimeSummary(
                id: 55791,
                title: "Dandadan Season 2",
                imageAssetName: "s-l1200",
                score: nil,
                episodes: nil,
                airingDay: nil,
                synopsis: "超自然、外星人與青春喜劇繼續展開。",
                source: "Jikan /seasons/upcoming"
            ),
            AnimeSummary(
                id: 58572,
                title: "Chainsaw Man Movie: Reze Arc",
                imageAssetName: "s-l1200",
                score: nil,
                episodes: 1,
                airingDay: nil,
                synopsis: "電次與蕾潔篇章改編劇場版。",
                source: "Jikan /seasons/upcoming"
            )
        ]
    ]
}

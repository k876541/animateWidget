import Foundation

// App 和 Widget Extension 是不同 target、不同 process。
// 要共享資料，需要使用 App Group UserDefaults，而不是一般 UserDefaults.standard。
struct AppGroupSettingsStore {
    // UserDefaults 的 key 集中管理，避免不同檔案手寫字串造成 typo。
    private enum Key {
        static let selectedAnimeMode = "selectedAnimeMode"
        static let latestAnimeBrief = "latestAnimeBrief"
        static let latestTodayAnimeBrief = "latestTodayAnimeBrief"
    }

    // 這個值必須和 App / Widget 的 entitlements 裡的 App Group 一致。
    // 真機或正式簽署前，也要在 Apple Developer / Xcode Capability 開啟同一個 group。
    static let appGroupIdentifier = "group.RyanCC.NewsWidget"

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 如果 suiteName 建立失敗，先 fallback 到 .standard，讓模擬器開發不會直接壞掉。
    // 但正式 App/Widget 共用資料時，仍應確認 App Group 設定正確。
    init(userDefaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupIdentifier)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func loadSelectedAnimeMode() -> AnimeWidgetMode {
        guard let rawValue = userDefaults.string(forKey: Key.selectedAnimeMode),
              let mode = AnimeWidgetMode(rawValue: rawValue)
        else {
            // 第一次開 App 尚未存過設定時，先預設顯示本季新番。
            return .seasonal
        }

        return mode
    }

    func saveSelectedAnimeMode(_ mode: AnimeWidgetMode) {
        userDefaults.set(mode.rawValue, forKey: Key.selectedAnimeMode)
    }

    func loadLatestAnimeBrief() -> AnimeBrief? {
        // Widget 會呼叫這個方法讀取 App 最新存下來的動漫摘要。
        guard let data = userDefaults.data(forKey: Key.latestAnimeBrief) else { return nil }
        return try? decoder.decode(AnimeBrief.self, from: data)
    }

    func saveLatestAnimeBrief(_ brief: AnimeBrief) {
        // App refresh 後把整理好的 AnimeBrief 存起來，Widget 只負責讀取與顯示。
        guard let data = try? encoder.encode(brief) else { return }
        userDefaults.set(data, forKey: Key.latestAnimeBrief)
    }

    func loadLatestTodayAnimeBrief() -> AnimeBrief? {
        // Widget 專用：永遠只讀今日放送資料，避免被 App 目前選的分類影響。
        guard let data = userDefaults.data(forKey: Key.latestTodayAnimeBrief) else { return nil }
        return try? decoder.decode(AnimeBrief.self, from: data)
    }

    func saveLatestTodayAnimeBrief(_ brief: AnimeBrief) {
        guard let data = try? encoder.encode(brief) else { return }
        userDefaults.set(data, forKey: Key.latestTodayAnimeBrief)
    }
}

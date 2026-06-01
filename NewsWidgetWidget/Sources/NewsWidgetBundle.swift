import SwiftUI
import WidgetKit

// WidgetKit 每次顯示畫面時都會使用一筆 TimelineEntry。
// date 是 WidgetKit 排程用時間；brief 是我們真正要呈現的資料。
struct AnimeWidgetEntry: TimelineEntry {
    let date: Date
    let brief: AnimeBrief
}

// TimelineProvider 負責告訴 WidgetKit：現在、預覽、未來時間點要顯示什麼資料。
struct AnimeWidgetProvider: TimelineProvider {
    // placeholder 用於 Widget Gallery 或資料尚未準備好時的骨架預覽。
    func placeholder(in context: Context) -> AnimeWidgetEntry {
        AnimeWidgetEntry(date: .now, brief: MockAnimeRepository.fallbackBrief)
    }

    // snapshot 用於 Widget Gallery 快速預覽，不需要完整 timeline。
    func getSnapshot(in context: Context, completion: @escaping (AnimeWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    // timeline 是 Widget 的正式更新資料。
    // 注意：policy 設定的是希望下次更新時間，iOS 不保證準點執行。
    func getTimeline(in context: Context, completion: @escaping (Timeline<AnimeWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    // Widget 只讀取已整理好的 AnimeBrief，不在 extension 裡頻繁呼叫 Jikan API。
    private func makeEntry() -> AnimeWidgetEntry {
        let store = AppGroupSettingsStore()
        let brief = store.loadLatestTodayAnimeBrief() ?? MockAnimeRepository.fallbackTodayBrief
        return AnimeWidgetEntry(date: .now, brief: brief)
    }
}

// Widget 的 SwiftUI 畫面。
// 這裡應該保持輕量，重點是掃讀動畫標題，而不是完整作品列表。
struct AnimeWidgetEntryView: View {
    let entry: AnimeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.brief.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(entry.brief.updatedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Widget 空間有限，先只顯示前三部動畫。
                ForEach(Array(entry.brief.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.brief.mode.tint)
                            .frame(width: 16, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(2)

                            if let airingDay = item.airingDay {
                                Text(airingDay)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        // iOS 17+ Widget 背景寫法，讓系統在不同 widget context 套用正確背景。
        .containerBackground(.background, for: .widget)
    }
}

// Widget 本體設定。
struct AnimeWidget: Widget {
    // kind 是 WidgetKit 用來識別這個 widget 的 id。
    let kind = "AnimeWidget"

    var body: some WidgetConfiguration {
        // StaticConfiguration 表示這個 widget 目前沒有使用者可調整的 intent configuration。
        StaticConfiguration(kind: kind, provider: AnimeWidgetProvider()) { entry in
            AnimeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Anime Widget")
        .description("顯示今天會播放的動畫，作為追番提醒。")
        // 支援的桌面/主畫面 widget 尺寸。
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Widget Extension 的進入點。
@main
struct NewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        AnimeWidget()
    }
}

#Preview(as: .systemMedium) {
    // Xcode Preview 用的 widget 預覽資料。
    AnimeWidget()
} timeline: {
    AnimeWidgetEntry(date: .now, brief: MockAnimeRepository.fallbackBrief)
}

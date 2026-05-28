import Foundation
import SwiftUI

// Widget 可以顯示的動漫資料模式。
// 每個 case 都對應到一種 Jikan API 使用情境。
enum AnimeWidgetMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case todaySchedule
    case seasonal
    case topAiring
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todaySchedule:
            "今日放送"
        case .seasonal:
            "本季新番"
        case .topAiring:
            "熱門連載"
        case .upcoming:
            "即將開播"
        }
    }

    var subtitle: String {
        switch self {
        case .todaySchedule:
            "依每週放送表顯示今天會播出的動畫"
        case .seasonal:
            "顯示目前季度正在播出的動畫"
        case .topAiring:
            "顯示 MyAnimeList 熱門連載排行"
        case .upcoming:
            "顯示未來季度即將播出的作品"
        }
    }

    var systemImage: String {
        switch self {
        case .todaySchedule:
            "calendar"
        case .seasonal:
            "sparkles.tv"
        case .topAiring:
            "flame"
        case .upcoming:
            "clock.badge"
        }
    }

    var tint: Color {
        switch self {
        case .todaySchedule:
            .blue
        case .seasonal:
            .purple
        case .topAiring:
            .orange
        case .upcoming:
            .teal
        }
    }

    // Jikan API 顯示用 path。
    // 這個字串會在畫面上顯示，幫助你知道目前模式對應哪個資料來源。
    var jikanPath: String {
        switch self {
        case .todaySchedule:
            "/schedules?filter=\(Self.todayScheduleFilter)"
        case .seasonal:
            "/seasons/now?limit=10"
        case .topAiring:
            "/top/anime?filter=airing&limit=10"
        case .upcoming:
            "/seasons/upcoming?limit=10"
        }
    }

    // URLSession 實際組 URL 時使用的 endpoint path，不含 query。
    var jikanEndpointPath: String {
        switch self {
        case .todaySchedule:
            "schedules"
        case .seasonal:
            "seasons/now"
        case .topAiring:
            "top/anime"
        case .upcoming:
            "seasons/upcoming"
        }
    }

    // URLSession 實際組 URL 時使用的 query items。
    // 用 URLQueryItem 比手刻字串安全，之後新增參數也比較不容易漏掉 ? 或 &。
    var jikanQueryItems: [URLQueryItem] {
        switch self {
        case .todaySchedule:
            [
                URLQueryItem(name: "filter", value: Self.todayScheduleFilter),
                URLQueryItem(name: "limit", value: "10")
            ]
        case .seasonal:
            [URLQueryItem(name: "limit", value: "10")]
        case .topAiring:
            [
                URLQueryItem(name: "filter", value: "airing"),
                URLQueryItem(name: "limit", value: "10")
            ]
        case .upcoming:
            [URLQueryItem(name: "limit", value: "10")]
        }
    }

    private static var todayScheduleFilter: String {
        let weekday = Calendar.current.component(.weekday, from: .now)

        return switch weekday {
        case 1:
            "sunday"
        case 2:
            "monday"
        case 3:
            "tuesday"
        case 4:
            "wednesday"
        case 5:
            "thursday"
        case 6:
            "friday"
        default:
            "saturday"
        }
    }
}

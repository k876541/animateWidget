//
//  NewsWidgetApp.swift
//  NewsWidget
//
//  Created by Ryan Chang on 2026/5/22.
//

import SwiftUI

// App 的進入點。
// SwiftUI App 生命週期會從這個 @main type 開始建立第一個畫面。
@main
struct NewsWidgetApp: App {
    var body: some Scene {
        // WindowGroup 代表 App 的主要視窗。
        // 目前第一個畫面是 AnimeHomeView，負責 Widget 模式設定與動漫摘要。
        WindowGroup {
            AnimeHomeView()
        }
    }
}

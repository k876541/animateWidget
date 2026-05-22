//
//  NewsWidgetApp.swift
//  NewsWidget
//
//  Created by Ryan Chang on 2026/5/22.
//

import SwiftUI
import CoreData

@main
struct NewsWidgetApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

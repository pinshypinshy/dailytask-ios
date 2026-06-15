//
//  DailyTaskApp.swift
//  DailyTask
//
//  @main エントリ。全 @Model を含む ModelContainer を構築し、RootTabView へ注入する
//  （構成書 §1, §6.1）。
//

import SwiftUI
import SwiftData

@main
struct DailyTaskApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            TaskItem.self,
            Tag.self,
            DailySnapshot.self,
            TaskTagRecord.self,
            BackupFile.self,
        ])
    }
}

//
//  RootTabView.swift
//  DailyTask
//
//  TabView 3構成のルート（構成書 §6.1）。
//  Achievement / Backup の ViewModel は各タブ View が modelContext から自前で構築する。
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            TodayTasksView()
                .tabItem { Label("今日", systemImage: "checklist") }

            AchievementChartView()
                .tabItem { Label("達成状況", systemImage: "chart.line.uptrend.xyaxis") }

            BackupListView()
                .tabItem { Label("保存データ", systemImage: "externaldrive") }
        }
        .task {
            // 初回起動時にデフォルトの保存ファイル（空データ）を1件用意する。
            let sync = FileSyncService(context: context, codec: BackupCodec(), validator: BackupValidator())
            try? sync.seedDefaultFileIfNeeded()
        }
    }
}

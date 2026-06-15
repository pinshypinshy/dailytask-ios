//
//  RootTabView.swift
//  DailyTask
//
//  TabView 3構成のルート（構成書 §6.1）。
//  Achievement / Backup の ViewModel は各タブ View が modelContext から自前で構築する。
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayTasksView()
                .tabItem { Label("今日", systemImage: "checklist") }

            AchievementChartView()
                .tabItem { Label("達成状況", systemImage: "chart.line.uptrend.xyaxis") }

            BackupListView()
                .tabItem { Label("保存データ", systemImage: "externaldrive") }
        }
    }
}

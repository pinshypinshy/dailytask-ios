//
//  EmptyStateView.swift
//  DailyTask
//
//  空状態の汎用表示（構成書 §6.2 / 設計書 §2.1）。
//  例：「今日のタスクはありません」「データがありません」。
//

import SwiftUI

struct EmptyStateView: View {
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView(message, systemImage: systemImage)
    }
}

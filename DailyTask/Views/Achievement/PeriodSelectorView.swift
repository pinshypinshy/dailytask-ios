//
//  PeriodSelectorView.swift
//  DailyTask
//
//  期間切り替え（週/月）と前後移動（構成書 §6.3 / 設計書 §2.2）。
//

import SwiftUI

struct PeriodSelectorView: View {
    @Binding var period: AchievementViewModel.Period
    var onPrev: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
            }

            Picker("期間", selection: $period) {
                Text("週").tag(AchievementViewModel.Period.week)
                Text("月").tag(AchievementViewModel.Period.month)
            }
            .pickerStyle(.segmented)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
        }
    }
}

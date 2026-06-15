//
//  AchievementChartView.swift
//  DailyTask
//
//  達成状況グラフ（構成書 §6.3 / 設計書 §2.2）。
//  Swift Charts の折れ線。横軸＝日、縦軸＝達成率0〜100%。noData は点を打たない。
//  ViewModel は modelContext から自前で構築する。
//

import SwiftUI
import SwiftData
import Charts

struct AchievementChartView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var vm: AchievementViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    ChartContent(vm: vm, tags: tags)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("達成状況")
        }
        .task {
            if vm == nil { vm = AchievementViewModel(context: context) }
            vm?.reload()
        }
    }

    // MARK: - 本体（vm 確定後）

    private struct ChartContent: View {
        @Bindable var vm: AchievementViewModel
        let tags: [Tag]

        /// rate のみ抽出（noData は点を打たない＝チャートに含めない）。
        private var plotted: [(date: Date, percent: Double)] {
            vm.points.compactMap { point in
                if case let .rate(value) = point.value {
                    return (point.date, value * 100)
                }
                return nil
            }
        }

        /// 期間全体（noData 含む）の日付範囲。空データでも軸を期間幅で固定する。
        private var xDomain: ClosedRange<Date> {
            let dates = vm.points.map(\.date)
            guard let lower = dates.min(), let upper = dates.max() else {
                return Date.now...Date.now
            }
            // 終端の点が切れないよう1日ぶん余白を足す。
            let padded = Calendar.current.date(byAdding: .day, value: 1, to: upper) ?? upper
            return lower...padded
        }

        /// 週は「日付＋曜日」を毎日、月は5日おきの目盛りを表示する。
        @AxisContentBuilder
        private var xAxisMarks: some AxisContent {
            if vm.period == .week {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            VStack(spacing: 2) {
                                Text(date, format: .dateTime.day())
                                Text(date.formatted(.dateTime.weekday(.short)))
                            }
                        }
                    }
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                PeriodSelectorView(period: $vm.period,
                                   onPrev: vm.moveBackward,
                                   onNext: vm.moveForward)
                    .padding(.horizontal)

                Chart(plotted, id: \.date) { item in
                    LineMark(
                        x: .value("日", item.date, unit: .day),
                        y: .value("達成率", item.percent)
                    )
                    PointMark(
                        x: .value("日", item.date, unit: .day),
                        y: .value("達成率", item.percent)
                    )
                }
                .chartXScale(domain: xDomain)
                .chartXAxis { xAxisMarks }
                .chartYScale(domain: 0...100)
                .frame(height: 260)
                .padding(.horizontal)
                .overlay {
                    if plotted.isEmpty {
                        EmptyStateView(message: "データがありません",
                                       systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                TagFilterView(selected: $vm.selectedTagIDs, tags: tags)

                Spacer()
            }
            .padding(.top)
        }
    }
}

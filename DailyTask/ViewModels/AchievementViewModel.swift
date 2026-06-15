//
//  AchievementViewModel.swift
//  DailyTask
//
//  達成状況グラフの派生状態・副作用を集約（構成書 §5, §6.3 / 設計書 §2.2, §4.1）。
//  当日はタスク実体からリアルタイム算出、過去は DailySnapshot を参照（案A）。
//
//  案A段階のタグフィルタ挙動：
//   - タグ未選択           → 全体の達成率。
//   - タグ1つ選択          → 当日は和集合、過去は Snapshot.perTag の単体値。
//   - タグ複数選択         → 当日は和集合。過去日は抑止（noData、点を打たない）。
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AchievementViewModel {
    enum Period { case week, month }

    var period: Period { didSet { reload() } }
    var anchorDate: Date              // 表示中の週/月の基準
    var selectedTagIDs: Set<UUID> { didSet { reload() } }
    var points: [(date: Date, value: AchievementValue)]

    private let context: ModelContext
    private let snapshotManager: SnapshotManager
    private let calculator = AchievementCalculator()
    private let aggregator = TagAggregator()
    private let calendar = Calendar.current

    init(context: ModelContext,
         period: Period = .week,
         anchorDate: Date = .now,
         selectedTagIDs: Set<UUID> = []) {
        self.context = context
        self.snapshotManager = SnapshotManager(context: context)
        self.period = period
        self.anchorDate = anchorDate
        self.selectedTagIDs = selectedTagIDs
        self.points = []
        reload()
    }

    /// 表示期間内の各日について達成率を算出し points を再構築する。
    func reload() {
        let today = Date.now.dayKey
        var result: [(date: Date, value: AchievementValue)] = []
        for day in daysInCurrentPeriod() {
            let value: AchievementValue
            if day == today {
                value = todayValue(today: today)
            } else if day < today {
                value = pastValue(for: day)
            } else {
                value = .noData          // 未来日は点を打たない
            }
            result.append((date: day, value: value))
        }
        points = result
    }

    /// 一期間ぶん前へ移動。
    func moveBackward() {
        anchorDate = shiftedAnchor(by: -1)
        reload()
    }

    /// 一期間ぶん後へ移動。
    func moveForward() {
        anchorDate = shiftedAnchor(by: 1)
        reload()
    }

    // MARK: - 内部

    private var periodComponent: Calendar.Component {
        period == .week ? .weekOfYear : .month
    }

    private func shiftedAnchor(by delta: Int) -> Date {
        calendar.date(byAdding: periodComponent, value: delta, to: anchorDate) ?? anchorDate
    }

    private func daysInCurrentPeriod() -> [Date] {
        let unit: Calendar.Component = period == .week ? .weekOfYear : .month
        guard let interval = calendar.dateInterval(of: unit, for: anchorDate) else { return [] }
        var days: [Date] = []
        var day = interval.start.dayKey
        let end = interval.end.dayKey   // 排他的終端
        while day < end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private func todayValue(today: Date) -> AchievementValue {
        let tasks = fetchTasks(on: today)
        if selectedTagIDs.isEmpty {
            return calculator.rateForToday(tasks: tasks)
        }
        return aggregator.aggregateToday(selectedTagIDs, from: tasks)
    }

    private func pastValue(for day: Date) -> AchievementValue {
        guard let snap = snapshotManager.snapshot(for: day) else { return .noData }
        if selectedTagIDs.isEmpty {
            return calculator.rate(from: snap)
        }
        // 案A：過去日の和集合は再計算しない。単体タグのみ Snapshot.perTag から表示。
        if selectedTagIDs.count == 1, let tagID = selectedTagIDs.first {
            guard let count = snap.perTag[tagID], count.total > 0 else { return .noData }
            return .rate(Double(count.completed) / Double(count.total))
        }
        return .noData   // 過去日 × 複数タグ選択は抑止
    }

    private func fetchTasks(on day: Date) -> [TaskItem] {
        let key = day.dayKey
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.date == key })
        return (try? context.fetch(descriptor)) ?? []
    }
}

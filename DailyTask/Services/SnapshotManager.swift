//
//  SnapshotManager.swift
//  DailyTask
//
//  DailySnapshot の確定・更新・参照（設計書 §1.4, §4.2 / 構成書 §4.1）。
//  確定時に表示用集計値（total/completed/perTag）と種データ（taskRecords）の両方を書き込む。
//
//  更新タイミング（確定事項）：当日タスクの編集の都度 upsert ＋ 日付繰り越し時に確定。
//  案A段階：taskRecords は書くだけ・読まない。
//

import Foundation
import SwiftData

@MainActor
final class SnapshotManager {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// その日のタスク編集時、または日付繰り越し時に呼ぶ。
    /// 集計値と種データの両方を再計算し、当日分の DailySnapshot を upsert する。
    func updateSnapshot(for date: Date) throws {
        let day = date.dayKey
        let tasks = try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.date == day })
        )

        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count

        var perTag: [UUID: TagCount] = [:]
        for task in tasks {
            for tagID in task.tagIDs {
                var count = perTag[tagID] ?? TagCount()
                count.total += 1
                if task.isCompleted { count.completed += 1 }
                perTag[tagID] = count
            }
        }

        let records = tasks.map {
            TaskTagRecord(taskID: $0.id, isCompleted: $0.isCompleted, tagIDs: $0.tagIDs)
        }

        if let existing = snapshot(for: day) {
            // 既存の種データを破棄して入れ替え（cascade 整合を保つ）。
            for old in existing.taskRecords { context.delete(old) }
            existing.totalCount = total
            existing.completedCount = completed
            existing.perTag = perTag
            existing.taskRecords = records
        } else {
            let snap = DailySnapshot(date: day,
                                     totalCount: total,
                                     completedCount: completed,
                                     perTag: perTag,
                                     taskRecords: records)
            context.insert(snap)
        }
        try context.save()
    }

    /// 日付が変わった際の確定処理。
    /// 1) 当日より前でスナップショット未確定の日を確定する（繰り越し前の完了状態を記録）。
    /// 2) 習慣型タスク（isRecurring）は当日へ繰り越し、完了状態をリセットする。
    ///    単発型はその日のまま残し、Today からは見えなくなる（新しい日は空から始まる）。
    /// 確定を先に行うことで、前日分の達成率は繰り越し前の値で正しく保存される。
    func rolloverIfNeeded(now: Date) throws {
        let today = now.dayKey
        let pastTasks = try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.date < today })
        )

        // 1) 未確定 Snapshot を確定（繰り越しでタスクが移動する前に集計する）。
        let days = Set(pastTasks.map { $0.date })
        for day in days where snapshot(for: day) == nil {
            try updateSnapshot(for: day)
        }

        // 2) 習慣型タスクを当日へ移し、完了状態をリセット。
        for task in pastTasks where task.isRecurring {
            task.date = today
            task.isCompleted = false
        }
        try context.save()
    }

    /// 指定日の Snapshot を取得（過去グラフ参照用）。
    func snapshot(for date: Date) -> DailySnapshot? {
        let day = date.dayKey
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date == day }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// 期間内の Snapshot を日付昇順で取得。
    func snapshots(in range: ClosedRange<Date>) -> [DailySnapshot] {
        let lower = range.lowerBound.dayKey
        let upper = range.upperBound.dayKey
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= lower && $0.date <= upper },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

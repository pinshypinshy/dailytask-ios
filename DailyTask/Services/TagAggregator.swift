//
//  TagAggregator.swift
//  DailyTask
//
//  タグフィルタ集計（設計書 §2.2, §4.1 / 構成書 §4.3）。
//  選択タグの和集合・重複排除（複数タグに属するタスクも分母で1回だけ計上）。
//
//  案A段階：当日のタスク実体に対してのみ和集合を算出する（aggregateToday）。
//  過去日の和集合（aggregatePast）は案B拡張用で、現在は呼ばれない（UI で過去日×複数タグ選択を抑止）。
//

import Foundation

struct TagAggregator {
    /// 当日：選択タグのいずれかに属するユニークタスクを返す（和集合・二重計上なし）。
    /// TaskItem は実体として一意のため、フィルタ結果も自動的に重複排除される。
    func tasksMatchingAnyTag(_ tagIDs: Set<UUID>, from tasks: [TaskItem]) -> [TaskItem] {
        guard !tagIDs.isEmpty else { return [] }
        return tasks.filter { !Set($0.tagIDs).isDisjoint(with: tagIDs) }
    }

    /// 当日：和集合のユニークタスクから分母・分子を算出。
    /// 選択タグに属するタスクが0件なら noData（0/0）。
    func aggregateToday(_ selected: Set<UUID>, from tasks: [TaskItem]) -> AchievementValue {
        let matched = tasksMatchingAnyTag(selected, from: tasks)
        guard !matched.isEmpty else { return .noData }
        let completed = matched.filter { $0.isCompleted }.count
        return .rate(Double(completed) / Double(matched.count))
    }

    /// 【案B拡張用・現在は未使用】過去日：種データ taskRecords から和集合・重複排除して算出。
    /// 案A段階ではこのパスは呼ばれない（過去日の複数タグ選択は UI で抑止）。
    func aggregatePast(_ selected: Set<UUID>, from records: [TaskTagRecord]) -> AchievementValue {
        guard !selected.isEmpty else { return .noData }
        // taskID で重複排除しつつ和集合に属するレコードを抽出。
        var seen = Set<UUID>()
        let matched = records.filter { record in
            guard !Set(record.tagIDs).isDisjoint(with: selected) else { return false }
            return seen.insert(record.taskID).inserted
        }
        guard !matched.isEmpty else { return .noData }
        let completed = matched.filter { $0.isCompleted }.count
        return .rate(Double(completed) / Double(matched.count))
    }
}

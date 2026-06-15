//
//  AchievementCalculator.swift
//  DailyTask
//
//  達成率算出（設計書 §4.1 / 構成書 §4.2）。
//  当日はタスク実体からリアルタイム算出、過去は DailySnapshot の集計値から算出（再計算しない）。
//  分母が0（0/0）の場合は noData とし、0% と区別する（点を打たない）。
//

import Foundation

enum AchievementValue: Equatable {
    case rate(Double)   // 0.0〜1.0
    case noData         // 0/0。0% と区別
}

struct AchievementCalculator {
    /// 当日: tasks から直接算出。
    func rateForToday(tasks: [TaskItem]) -> AchievementValue {
        guard !tasks.isEmpty else { return .noData }
        let completed = tasks.filter { $0.isCompleted }.count
        return .rate(Double(completed) / Double(tasks.count))
    }

    /// 過去: Snapshot の集計値から算出（案A：集計値のみ参照、taskRecords は読まない）。
    func rate(from snapshot: DailySnapshot) -> AchievementValue {
        guard snapshot.totalCount > 0 else { return .noData }
        return .rate(Double(snapshot.completedCount) / Double(snapshot.totalCount))
    }
}

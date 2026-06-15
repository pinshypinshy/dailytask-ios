//
//  DailySnapshot.swift
//  DailyTask
//
//  達成率の分母が後から改変されるのを防ぐ日次確定記録（設計書 §1.4 / 構成書 §2.3）。
//  表示用の集計値（totalCount / completedCount / perTag）と、将来の和集合再計算用の
//  種データ（taskRecords）を併せ持つ。
//
//  案A段階：表示ロジックは集計値のみを参照し、taskRecords は読まない（書くだけ）。
//

import Foundation
import SwiftData

@Model
final class DailySnapshot {
    @Attribute(.unique) var date: Date          // 対象日（正規化済み）

    // --- 表示用（案A：現在の達成率描画はこれだけを使う）---
    var totalCount: Int                          // 全体の分母
    var completedCount: Int                      // 全体の分子
    var perTag: [UUID: TagCount]                 // タグ単体の集計値（Codable辞書）

    // --- 種データ（現在は書くだけ・読まない。将来の案B拡張で和集合再計算に使用）---
    @Relationship(deleteRule: .cascade)
    var taskRecords: [TaskTagRecord]

    init(date: Date,
         totalCount: Int,
         completedCount: Int,
         perTag: [UUID: TagCount] = [:],
         taskRecords: [TaskTagRecord] = []) {
        self.date = date
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.perTag = perTag
        self.taskRecords = taskRecords
    }
}

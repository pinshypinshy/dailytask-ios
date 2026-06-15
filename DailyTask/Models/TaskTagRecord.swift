//
//  TaskTagRecord.swift
//  DailyTask
//
//  種データ。その日に存在した各タスクが「どのタグ集合に属し、完了していたか」を
//  1件単位で保存する。将来の案B拡張で過去日まで遡って和集合・重複排除を
//  再計算するための入力（構成書 §2.5）。
//
//  案A段階では SnapshotManager が書き込むのみで、表示ロジックからは参照しない。
//

import Foundation
import SwiftData

@Model
final class TaskTagRecord {
    var taskID: UUID
    var isCompleted: Bool
    var tagIDs: [UUID]      // そのタスクがその日に属していたタグ集合

    init(taskID: UUID, isCompleted: Bool, tagIDs: [UUID]) {
        self.taskID = taskID
        self.isCompleted = isCompleted
        self.tagIDs = tagIDs
    }
}

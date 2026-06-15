//
//  TaskItem.swift
//  DailyTask
//
//  1日分のタスク1件（内部正本）。多対多はタスク側に tagIDs を保持して
//  双方向解決する（設計書 §1.2 / 構成書 §2.1）。
//
//  構成書では型名 `Task` だが、Swift Concurrency の Task との衝突を避けるため
//  `TaskItem` に改名した（確定シグネチャからの命名変更。フィールド構成は不変）。
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var isFavorite: Bool
    var isCompleted: Bool
    var date: Date          // 時刻正規化済みの「属する日」
    var tagIDs: [UUID]      // 多対多をタスク側で保持
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         isFavorite: Bool = false,
         isCompleted: Bool = false,
         date: Date,
         tagIDs: [UUID] = [],
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.isCompleted = isCompleted
        self.date = date
        self.tagIDs = tagIDs
        self.createdAt = createdAt
    }
}

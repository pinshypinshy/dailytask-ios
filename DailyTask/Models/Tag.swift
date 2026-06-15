//
//  Tag.swift
//  DailyTask
//
//  タスク分類タグ（内部正本）。「含まれるタスク」は保持せず、
//  Task.tagIDs から導出する（設計書 §1.3 / 構成書 §2.2）。
//

import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String     // プリセットから選択した16進文字列

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

//
//  TaskDTO.swift
//  DailyTask
//
//  tasks[] 要素の Codable 表現（ファイル入出力の中間表現・構成書 §3.2）。
//  SwiftData 非依存。id / tagIDs は検証段階では String、反映時に UUID 化する。
//  date は ISO 8601（日付）形式の文字列。
//

import Foundation

struct TaskDTO: Codable {
    let id: String          // 検証段階では String、反映時に UUID 化
    let name: String
    let isFavorite: Bool
    let isCompleted: Bool
    let date: String        // ISO 8601（日付）
    let tagIDs: [String]
}

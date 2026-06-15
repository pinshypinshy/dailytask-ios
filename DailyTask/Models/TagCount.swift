//
//  TagCount.swift
//  DailyTask
//
//  perTag の値型。設計書原文のタプル (Int, Int) は Codable 非対応のため
//  Codable struct に置換した（構成書 §2.4 / §8 確定事項②）。
//

import Foundation

struct TagCount: Codable {
    var total: Int
    var completed: Int

    init(total: Int = 0, completed: Int = 0) {
        self.total = total
        self.completed = completed
    }
}

//
//  DateNormalizer.swift
//  DailyTask
//
//  date の時刻正規化と日付繰り越し判定（設計書 §4.2 / 構成書 §4.7）。
//  日キー変換そのものは Date.dayKey（Support）に委譲し、本型はロジックの入口を担う。
//

import Foundation

struct DateNormalizer {
    /// 時刻を切り落とした「属する日」を返す。
    func dayKey(for date: Date) -> Date {
        date.dayKey
    }

    /// last と now が別の日であれば true（＝繰り越しが必要）。
    func isNewDay(last: Date, now: Date) -> Bool {
        dayKey(for: last) != dayKey(for: now)
    }
}

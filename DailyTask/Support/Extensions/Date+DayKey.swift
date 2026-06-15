//
//  Date+DayKey.swift
//  DailyTask
//
//  日付のみ正規化キー（構成書 §7.3）。時刻を切り落とした「属する日」を返す。
//  TaskItem.date / DailySnapshot.date の正規化、達成率グラフの日次キーに用いる。
//
//  時刻正規化・繰り越し判定そのものは Services/DateNormalizer が担い、
//  本拡張はその基礎となる「日キー」変換だけを提供する。
//

import Foundation

extension Date {
    /// 現在カレンダーで時刻を切り落とした日付キー（その日の 00:00:00）。
    var dayKey: Date {
        Calendar.current.startOfDay(for: self)
    }
}

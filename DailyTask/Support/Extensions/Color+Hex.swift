//
//  Color+Hex.swift
//  DailyTask
//
//  colorHex（プリセット16進文字列）を SwiftUI Color へ変換する共有拡張。
//  TaskEditor / TagEditor / TagFilter / PresetColorPicker など複数 View が参照するため
//  横断ユーティリティとして Support に置く。
//

import SwiftUI

extension Color {
    /// "#RRGGBB"（先頭 # 任意）から Color を生成する。解釈不能時は灰色。
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# \n"))
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value), cleaned.count == 6 else {
            self = .gray
            return
        }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

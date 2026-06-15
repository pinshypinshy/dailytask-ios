//
//  PresetColors.swift
//  DailyTask
//
//  許可された colorHex プリセットの定義（構成書 §7.1）。
//  MVP ではタグカラーは自由選択せず、この一覧から選ぶ（設計書 §5 対象外: 自由選択）。
//  検証ルール5（colorHex が許可プリセットか）は isAllowed(_:) で判定する。
//

import Foundation

enum PresetColors {
    /// 許可された colorHex 一覧（大文字 6桁・先頭 # 付きで正規化された表現）。
    static let all: [String] = [
        "#4A90D9",   // ブルー
        "#50C878",   // グリーン
        "#E94F4F",   // レッド
        "#F5A623",   // オレンジ
        "#9B59B6",   // パープル
        "#F8C146",   // イエロー
        "#1ABC9C",   // ティール
        "#E91E8C",   // ピンク
        "#7F8C8D"    // グレー
    ]

    /// 与えられた hex が許可プリセットに含まれるか。
    /// 比較は大文字小文字を無視し、許容表現の揺れを吸収する。
    static func isAllowed(_ hex: String) -> Bool {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return all.contains { $0.uppercased() == normalized }
    }
}

//
//  TagDTO.swift
//  DailyTask
//
//  tags[] 要素の Codable 表現（ファイル入出力の中間表現・構成書 §3.3）。
//  SwiftData 非依存。id は検証段階では String、内部DB反映時に UUID 化する。
//

import Foundation

struct TagDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
}

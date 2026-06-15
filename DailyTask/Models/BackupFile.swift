//
//  BackupFile.swift
//  DailyTask
//
//  エクスポート／インポート用ファイルのメタ情報（設計書 §1.5 / 構成書 §2.6）。
//  fileName は Documents ディレクトリ内の実ファイルに対応する。
//

import Foundation
import SwiftData

@Model
final class BackupFile {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var isActive: Bool        // アプリ表示に反映中か（複数中1つ）
    var lastModified: Date

    init(id: UUID = UUID(),
         fileName: String,
         isActive: Bool = false,
         lastModified: Date = .now) {
        self.id = id
        self.fileName = fileName
        self.isActive = isActive
        self.lastModified = lastModified
    }
}

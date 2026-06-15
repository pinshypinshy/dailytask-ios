//
//  BackupCodec.swift
//  DailyTask
//
//  SwiftData ⇔ DTO ⇔ JSON の相互変換（設計書 §3.1, §4.3 / 構成書 §4.4）。
//  encode: 内部モデル → DTO → JSON Data。decode: JSON Data → DTO（パースのみ）。
//
//  日付フォーマットと既知バージョンはここを単一情報源とし、
//  BackupValidator / FileSyncService が参照する（書き出し・検証・反映の表現を一致させる）。
//

import Foundation

struct BackupCodec {
    /// 書き出すスキーマの最新バージョン（書き出しはこの値を用いる）。
    /// v2 で TaskDTO.isRecurring（習慣型フラグ）を追加。v1 は当該フィールド欠落として後方互換で読める。
    static let currentVersion = 2

    /// インポートで受理する既知バージョン（検証ルール2の判定基準）。
    static let knownVersions: Set<Int> = [1, 2]

    /// JSON 上の date 表現（ISO 8601 の日付のみ）。round-trip の単一情報源。
    /// 日キー（端末ローカル）との整合のため TimeZone.current を用いる。
    static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }()

    /// 内部モデル → DTO → JSON Data（書き出し用）。
    func encode(tasks: [TaskItem], tags: [Tag]) throws -> Data {
        let tagDTOs = tags.map {
            TagDTO(id: $0.id.uuidString, name: $0.name, colorHex: $0.colorHex)
        }
        let taskDTOs = tasks.map { task in
            TaskDTO(id: task.id.uuidString,
                    name: task.name,
                    isFavorite: task.isFavorite,
                    isCompleted: task.isCompleted,
                    isRecurring: task.isRecurring,
                    date: Self.isoDateFormatter.string(from: task.date),
                    tagIDs: task.tagIDs.map { $0.uuidString })
        }
        let root = BackupFileDTO(version: Self.currentVersion, tags: tagDTOs, tasks: taskDTOs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(root)
    }

    /// JSON Data → DTO（検証前のパースのみ。反映はしない）。
    /// 検証ルール1（パース可否）はここの throw で判定する。
    /// JSON 構文崩れは parseFailed、必須キー欠落・型不一致は missingOrTypeMismatch に対応付ける。
    func decode(_ data: Data) throws -> BackupFileDTO {
        do {
            return try JSONDecoder().decode(BackupFileDTO.self, from: data)
        } catch DecodingError.dataCorrupted {
            throw ValidationError(rule: .parseFailed)
        } catch is DecodingError {
            throw ValidationError(rule: .missingOrTypeMismatch)
        }
    }
}

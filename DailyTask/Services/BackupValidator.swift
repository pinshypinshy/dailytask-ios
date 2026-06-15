//
//  BackupValidator.swift
//  DailyTask
//
//  JSON スキーマ検証（設計書 §3.2 の7ルール / 構成書 §4.5, §8 確定事項③）。
//  全ルールを実施し、違反が1つでもあれば throws して保存／追加を拒否する。
//  エラーは汎用に留め、フィールドパスや行番号などの詳細位置情報は持たない。
//
//  ルール1（パース可否）は BackupCodec.decode の throw で判定済み。
//  本バリデータは残り6ルール（version / 必須・型 / date / colorHex / 孤立参照 / id重複）を担う。
//

import Foundation

struct BackupValidator {
    /// 全ルールを順に適用。最初の違反で throws。
    func validate(_ dto: BackupFileDTO) throws {
        try validateVersion(dto)
        try validateRequiredFieldsAndTypes(dto)
        try validateDateFormat(dto)
        try validateColorHex(dto)
        try validateTagReferences(dto)
        try validateUniqueIDs(dto)
    }

    /// ルール2: version が既知か。
    func validateVersion(_ dto: BackupFileDTO) throws {
        guard dto.version == BackupCodec.currentVersion else {
            throw ValidationError(rule: .unknownVersion)
        }
    }

    /// ルール3: 必須フィールドの存在と型一致。
    /// 存在・基本型は Codable decode が保証済みのため、ここでは "uuid" 型として
    /// 宣言されたフィールド（id / tagIDs 各要素）が実際に UUID 解釈可能かを検証する。
    func validateRequiredFieldsAndTypes(_ dto: BackupFileDTO) throws {
        for tag in dto.tags {
            guard UUID(uuidString: tag.id) != nil else {
                throw ValidationError(rule: .missingOrTypeMismatch)
            }
        }
        for task in dto.tasks {
            guard UUID(uuidString: task.id) != nil else {
                throw ValidationError(rule: .missingOrTypeMismatch)
            }
            for ref in task.tagIDs {
                guard UUID(uuidString: ref) != nil else {
                    throw ValidationError(rule: .missingOrTypeMismatch)
                }
            }
        }
    }

    /// ルール4: date が ISO 8601（日付）形式か。
    func validateDateFormat(_ dto: BackupFileDTO) throws {
        for task in dto.tasks {
            guard BackupCodec.isoDateFormatter.date(from: task.date) != nil else {
                throw ValidationError(rule: .invalidDate)
            }
        }
    }

    /// ルール5: colorHex が許可プリセットか。
    func validateColorHex(_ dto: BackupFileDTO) throws {
        for tag in dto.tags {
            guard PresetColors.isAllowed(tag.colorHex) else {
                throw ValidationError(rule: .invalidColor)
            }
        }
    }

    /// ルール6: tagIDs が実在する tags[].id を参照しているか（孤立参照検出）。
    /// UUID は大文字小文字を無視して同一視するため、比較は正規化（大文字）して行う。
    func validateTagReferences(_ dto: BackupFileDTO) throws {
        let known = Set(dto.tags.map { $0.id.uppercased() })
        for task in dto.tasks {
            for ref in task.tagIDs {
                guard known.contains(ref.uppercased()) else {
                    throw ValidationError(rule: .orphanTagReference)
                }
            }
        }
    }

    /// ルール7: id の重複がないか（tags 内・tasks 内それぞれ）。
    func validateUniqueIDs(_ dto: BackupFileDTO) throws {
        let tagIDs = dto.tags.map { $0.id.uppercased() }
        guard Set(tagIDs).count == tagIDs.count else {
            throw ValidationError(rule: .duplicateID)
        }
        let taskIDs = dto.tasks.map { $0.id.uppercased() }
        guard Set(taskIDs).count == taskIDs.count else {
            throw ValidationError(rule: .duplicateID)
        }
    }
}

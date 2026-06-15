//
//  ValidationError.swift
//  DailyTask
//
//  検証違反の型（構成書 §7.2 / §8 確定事項③）。
//  ルール種別は内部判定・ログ・テスト用に保持するが、UI 表示は汎用文言に統一し、
//  フィールドパスや行番号などの詳細位置情報は持たない／出さない。
//

import Foundation

struct ValidationError: Error {
    enum Rule {
        case parseFailed            // 1. JSON としてパース不可
        case unknownVersion         // 2. version が未知
        case missingOrTypeMismatch  // 3. 必須フィールド欠落・型不一致
        case invalidDate            // 4. date が ISO 8601（日付）形式でない
        case invalidColor           // 5. colorHex が許可プリセット外
        case orphanTagReference     // 6. tagIDs が実在 tag を参照していない（孤立参照）
        case duplicateID            // 7. id の重複
    }

    /// 内部用（ログ・テスト）。UI には出さない。
    let rule: Rule

    /// ユーザー向けの固定・汎用メッセージ（位置情報を含まない）。
    /// エラー UI はこの文言に統一し、文法仕様は公式サイト掲載で代替する。
    static let userFacingMessage =
        "形式が正しくないため保存できません。文法は公式サイトを参照してください。"
}

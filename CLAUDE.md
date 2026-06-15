# CLAUDE.md

このファイルは Claude Code がこのプロジェクトで作業する際の指示・規約・コンテキストを定義する。詳細な仕様は設計書を参照すること。

## プロジェクト概要

iOS 向けタスク管理アプリ（MVP）。その日限りの単発型タスクを管理し、達成率をグラフ化し、JSON ファイルでエクスポート／インポートできる。

- ルートディレクトリ: `DailyTask/`
- 注意: 設計書・構成書内のコード例ではルートが `TaskApp/` と表記されているが、本プロジェクトのルートは `DailyTask/` とする。新規ファイルは `DailyTask/` 配下に作成すること。

## 参照すべき設計ドキュメント

実装判断に迷ったら、まず以下を参照する。本 CLAUDE.md は要約であり、正は設計書側にある。

- `task_app_design.md` — 設計書（MVP）。データモデル・画面仕様・検証ルール・主要ロジックの正本。
- `task_app_structure_v2.md` — ファイル構成書（実装ガイド確定版 v2）。ディレクトリ構成・各ファイルの責務・主要シグネチャ。v1 申し送り5項目はここで確定済み（§8）。

## 技術スタック

- iOS / SwiftUI
- SwiftData（内部正本のデータ永続化）
- Swift Charts（達成状況グラフ）
- Codable（JSON 入出力）

## アーキテクチャ方針

### 二層構造（正本と表現の分離）

- 正本は SwiftData。JSON ファイルはエクスポート／インポート用の表現に過ぎず、正本にしない。
- ファイルの役割は橋渡し: 「読み込み時に検証 → 内部DBへ反映」「内部更新時に書き出し」。
- 理由: 同期バグと文法バグによる全損を避けるため。

### レイヤ構成

- `Models/` — SwiftData の `@Model`（内部正本）。
- `DTO/` — ファイル入出力用の中間表現（`Codable struct`、SwiftData 非依存）。`@Model` を直接 Codable にしない。JSON スキーマと内部モデルの変更を独立させるため。
- `Services/` — ロジック層。View から分離する。
- `ViewModels/` — ハイブリッド方針（下記）。
- `Views/` — TabView 3構成。`Today/` `Achievement/` `Backup/`。
- `Components/` `Support/` — 横断的な小UI・ユーティリティ。

### ViewModel ハイブリッド方針

- Today タブは ViewModel を置かない。`@Query` で View が直接 SwiftData を購読する。タスク操作は `modelContext` 経由または薄い補助関数で実装。
- Achievement / Backup タブのみ ViewModel を採用する（派生状態・副作用が集まるため）。

## データモデル要約

詳細な型定義は構成書 §2 を参照。

- **Task** — 1日分のタスク1件。`id / name / isFavorite / isCompleted / date / tagIDs / createdAt`。多対多はタスク側の `tagIDs: [UUID]` で双方向解決する。`date` は時刻正規化済みの「属する日」。
- **Tag** — 分類タグ。`id / name / colorHex`。「含まれるタスク」は保持せず `Task.tagIDs` から導出する（相互参照による不整合を防ぐため）。
- **DailySnapshot** — 達成率の分母が後から改変されるのを防ぐ日次確定記録。表示用集計値（`totalCount / completedCount / perTag`）＋将来の和集合再計算用の種データ（`taskRecords`）を併せ持つ。
- **TagCount** — `perTag` の値型（`Codable struct`）。設計書原文のタプル `(Int, Int)` は Codable 非対応のため struct 化した。
- **TaskTagRecord** — 種データ。各タスクがその日にどのタグ集合に属し完了していたかを1件単位で保存。現段階では SnapshotManager が書き込むのみで、表示ロジックからは参照しない。
- **BackupFile** — エクスポート／インポート用ファイルのメタ情報。`id / fileName / isActive / lastModified`。

## 主要ロジックの要点

詳細は設計書 §4・構成書 §4 を参照。

- **達成率算出**: 当日はタスク実体からリアルタイム算出、過去は DailySnapshot を参照（再計算しない）。`0/0` は「データなし」とし、0% と区別して点を打たない。
- **タグフィルタ集計**: 選択タグの**和集合**・重複排除（複数タグに属するタスクも分母で1回だけ計上）。
- **日付繰り越し**: 日付が変わると前日分が DailySnapshot として確定。新しい日は空のタスクリストから始まる（単発型のため繰り越さない）。
- **ファイル同期**: 内部DB更新 → `isActive` なファイルへ書き出し。ファイル編集保存 → パース → 検証 → 通過時のみ内部DBへ反映。

## 案A / 案B の段階方針（重要）

現段階は**案A**。実装時はこの区別を守ること。

- 表示ロジックは DailySnapshot の集計値のみを参照する。`taskRecords`（種データ）は**書くだけで読まない**。
- 過去日に対する複数タグ選択フィルタは、UI 側で抑止またはタグ単体表示に限定する。
- 将来の案Bでは `TagAggregator.aggregatePast` を有効化するだけで、過去日まで遡って和集合が効くようになる（データ追加のみで後方互換）。
- したがって、案A段階でも種データの書き込みは欠かさないこと。

## JSON 検証

保存・追加時に以下7ルールを全て適用し、1つでも違反すれば保存／追加を**拒否**する（設計書 §3.2）。

1. JSON としてパース可能か（`BackupCodec.decode` の throw で判定）。
2. `version` が既知か。
3. 必須フィールドの存在と型一致。
4. `date` が ISO 8601（日付）形式か。
5. `colorHex` が許可プリセットか。
6. `tagIDs` が実在する `tags[].id` を参照しているか（孤立参照検出）。
7. `id` の重複がないか。

- エラー UI は汎用文言に統一し、フィールドパス・行番号などの詳細位置情報は出さない。文法仕様は公式サイト掲載で代替する。
- 違反のルール種別（`ValidationError.Rule`）は内部判定・ログ・テスト用に保持してよいが、UI には出さない。

## ファイル保存先

- 保存実体は `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` 配下の JSON。`BackupFile.fileName` がこのディレクトリ内のファイルに対応。
- `Info.plist` に `UIFileSharingEnabled` と `LSSupportsOpeningDocumentsInPlace` を設定し、Files.app / iCloud Drive から直接編集可能にする。
- インポートは `.fileImporter` でユーザーが任意 JSON を選択 → 検証 → 取り込み。取り込んだファイルは Documents 配下へコピーする方針を推奨（`isActive` 同期の都合）。
- `Application Support`（ユーザーから隠れる）／`Caches`（OS 削除リスク）は不採用。

## コーディング規約

- `@Model` クラスは `final class`、`id` は `@Attribute(.unique)`。
- DTO 内の `id` は検証段階では `String` で保持し、内部DB反映時に `UUID` 化する。
- SwiftData に触れる Service / ViewModel は `@MainActor` を付す（構成書のシグネチャに準拠）。
- 構成書 §2〜§7 の主要シグネチャは合意済みの基盤。シグネチャを変更する場合は理由を明示し、勝手に変えない。
- View からロジックを直接書かず、Services 層に寄せる。Today タブのタスク操作のみ例外的に View 近傍で扱う。
- 値型で済むものは struct、SwiftData 永続化が必要なものだけ `@Model`。

## MVP 対象外（実装しないこと）

以下は拡張候補であり、MVP では実装しない。指示なく着手しない。

- 繰り返し・習慣型タスク。
- 月表示でのデータ点間引き・集約表示。
- タグカラーの自由選択（MVP はプリセット固定）。
- 複数ファイル間の差分マージ。
- 案B（過去日の和集合再計算の有効化）。

## ビルド方法

- Xcode で `DailyTask` プロジェクトを開き、iOS シミュレータまたは実機向けにビルド・実行する。
- 注意: 本プロジェクトのビルド設定・スキーム名・最低 iOS バージョン・テストターゲット構成は未確認。実際のプロジェクト設定に合わせて追記すること。

## Claude Code への作業指示

- 仕様判断に迷ったら推測で進めず、設計書・構成書の該当箇所を参照する。それでも曖昧なら確認を取る。
- 確定済みシグネチャ（構成書 §2〜§7）と確定事項（§8）に反する実装をしない。
- 案A / 案B の段階区別を常に意識する。種データは書くが読まない。
- ファイルの新規作成・大規模編集の前に、影響範囲と方針を提示してから着手する。

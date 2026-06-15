# タスク管理アプリ ファイル構成書（MVP実装ガイド・確定版 v2）

本書は `task_app_design.md`（設計書）を実装に落とすための、ディレクトリ構成・各ファイルの責務・主要シグネチャをまとめたもの。シグネチャは宣言のみで中身は実装しない。実装フェーズの合意基盤として用いる。v1 で挙げた申し送り5項目は本書で確定済み（§8参照）。

- 前提: iOS / SwiftUI + SwiftData、Swift Charts（グラフ）、Codable（JSON入出力）
- 正本は SwiftData。JSONファイルはエクスポート／インポート用の二層構造。

### v1からの確定差分（要点）
- **和集合集計**: 案A（表示は軽い集計値）を採用しつつ、`DailySnapshot` に「その日のタスク×タグ対応」を**種データ**として保存。将来の案B拡張時に過去日も遡って和集合再計算が可能。
- **perTag永続化**: タプルではなく Codable struct 辞書 `[UUID: TagCount]`。
- **JSON検証**: 7ルールの検証は実施し不正は拒否するが、エラー表示は汎用に留める（文法詳細は公式サイト掲載で代替）。
- **ファイル保存先**: Documents ＋ Files.app 公開。
- **ViewModel**: ハイブリッド（Todayは`@Query`直結、Achievement／BackupはViewModel）。

---

## 1. ディレクトリ構成

```
TaskApp/
├── App/
│   └── TaskAppApp.swift              # @main エントリ。ModelContainer 構築・注入
│
├── Models/                           # SwiftData @Model（内部正本）
│   ├── Task.swift                    # Task エンティティ
│   ├── Tag.swift                     # Tag エンティティ
│   ├── DailySnapshot.swift           # 日次確定スナップショット（集計値＋種データ）
│   ├── TagCount.swift                # perTag の値型（Codable struct）
│   ├── TaskTagRecord.swift           # 種データ：その日のタスク×タグ集合の対応
│   └── BackupFile.swift              # エクスポート／インポート用ファイルのメタ情報
│
├── DTO/                              # ファイル入出力用の中間表現（SwiftData非依存）
│   ├── BackupFileDTO.swift           # JSONルート（version / tags / tasks）の Codable 表現
│   ├── TaskDTO.swift                 # tasks[] 要素の Codable 表現
│   └── TagDTO.swift                  # tags[] 要素の Codable 表現
│
├── Services/                         # ロジック層（Viewから分離）
│   ├── SnapshotManager.swift         # DailySnapshot の確定・更新・参照（種データの書き込み含む）
│   ├── AchievementCalculator.swift   # 達成率算出（当日リアルタイム / 過去はSnapshot参照）
│   ├── TagAggregator.swift           # タグフィルタ集計（和集合・重複排除）
│   ├── BackupCodec.swift             # SwiftData ⇔ DTO ⇔ JSON の変換（エンコード/デコード）
│   ├── BackupValidator.swift         # JSONスキーマ検証（§3.2 の7ルール、結果は通過/拒否）
│   ├── FileSyncService.swift         # 内部DB→ファイル書き出し / ファイル→内部DB反映
│   └── DateNormalizer.swift          # date の時刻正規化・日付繰り越し判定
│
├── ViewModels/                       # ハイブリッド方針：Achievement / Backup のみ採用
│   ├── AchievementViewModel.swift
│   └── BackupViewModel.swift
│
├── Views/
│   ├── RootTabView.swift             # TabView 3構成のルート
│   │
│   ├── Today/                        # §2.1 今日のタスク（ViewModelなし。@Query直結）
│   │   ├── TodayTasksView.swift
│   │   ├── TaskRowView.swift         # 1行：名前・お気に入り・実行済み
│   │   ├── TaskEditorView.swift      # 追加・編集フォーム
│   │   └── TagEditorView.swift       # タグの追加・編集・削除
│   │
│   ├── Achievement/                  # §2.2 達成状況グラフ
│   │   ├── AchievementChartView.swift
│   │   ├── PeriodSelectorView.swift  # 週/月切り替え・前後移動
│   │   └── TagFilterView.swift       # タグ複数選択フィルタ
│   │
│   └── Backup/                       # §2.3 保存データ
│       ├── BackupListView.swift      # ファイル一覧・isActive選択
│       ├── BackupDetailEditorView.swift  # 編集・保存（検証→反映）
│       └── ValidationErrorView.swift # 検証エラー（汎用メッセージ）表示
│
├── Components/                       # 横断的な小UI
│   ├── EmptyStateView.swift          # 空状態（「今日のタスクはありません」等）
│   └── ColorPicker/
│       └── PresetColorPicker.swift   # プリセットカラー選択（colorHex）
│
└── Support/
    ├── PresetColors.swift            # 許可カラープリセット定義
    ├── ValidationError.swift         # 検証エラーの型（ルール種別のみ。詳細表示はしない）
    └── Extensions/
        └── Date+DayKey.swift         # 日付のみ正規化キー等のユーティリティ
```

---

## 2. Models（SwiftData 正本）

### 2.1 Task.swift
役割: 1日分のタスク1件。多対多はタスク側に `tagIDs` を保持して双方向解決する（設計書§1.2）。

```swift
import SwiftData
import Foundation

@Model
final class Task {
    @Attribute(.unique) var id: UUID
    var name: String
    var isFavorite: Bool
    var isCompleted: Bool
    var date: Date          // 時刻正規化済みの「属する日」
    var tagIDs: [UUID]       // 多対多をタスク側で保持
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         isFavorite: Bool = false,
         isCompleted: Bool = false,
         date: Date,
         tagIDs: [UUID] = [],
         createdAt: Date = .now)
}
```

### 2.2 Tag.swift
役割: タスク分類タグ。「含まれるタスク」は保持せず、`Task.tagIDs` から導出（設計書§1.3）。

```swift
@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String     // プリセットから選択した16進文字列

    init(id: UUID = UUID(), name: String, colorHex: String)
}
```

### 2.3 DailySnapshot.swift
役割: 達成率の分母が後から改変されるのを防ぐ日次確定記録（設計書§1.4）。
**表示用の集計値**（`totalCount` / `completedCount` / `perTag`）と、**将来の和集合再計算用の種データ**（`taskRecords`）を併せ持つ。現段階（案A）では表示ロジックは集計値のみを参照し、`taskRecords` は読まない。

```swift
@Model
final class DailySnapshot {
    @Attribute(.unique) var date: Date          // 対象日（正規化済み）

    // --- 表示用（案A：現在の達成率描画はこれだけを使う）---
    var totalCount: Int                          // 全体の分母
    var completedCount: Int                      // 全体の分子
    var perTag: [UUID: TagCount]                 // タグ単体の集計値（Codable辞書）

    // --- 種データ（現在は書くだけ・読まない。将来の案B拡張で和集合再計算に使用）---
    @Relationship(deleteRule: .cascade)
    var taskRecords: [TaskTagRecord]

    init(date: Date,
         totalCount: Int,
         completedCount: Int,
         perTag: [UUID: TagCount] = [:],
         taskRecords: [TaskTagRecord] = [])
}
```
補足: 設計書原文の `perTag: [UUID:(Int,Int)]` のタプルは Codable 非対応のため、値型を `TagCount`（Codable struct）に置換した（v1申し送り②の確定）。`taskRecords` は v1申し送り①の折衷案で追加（種データ）。

### 2.4 TagCount.swift
役割: `perTag` の値型。タプルの代替（設計書§1.4 のタプルを Codable struct 化）。

```swift
struct TagCount: Codable {
    var total: Int
    var completed: Int
}
```

### 2.5 TaskTagRecord.swift
役割: 種データ。その日に存在した各タスクが「どのタグ集合に属し、完了していたか」を1件単位で保存。これにより将来、任意のタグ組み合わせの和集合・重複排除を過去日まで遡って再計算できる。現段階では SnapshotManager が書き込むのみで、表示ロジックからは参照しない。

```swift
@Model
final class TaskTagRecord {
    var taskID: UUID
    var isCompleted: Bool
    var tagIDs: [UUID]      // そのタスクがその日に属していたタグ集合

    init(taskID: UUID, isCompleted: Bool, tagIDs: [UUID])
}
```

### 2.6 BackupFile.swift
役割: エクスポート／インポート用ファイルのメタ情報（設計書§1.5）。

```swift
@Model
final class BackupFile {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var isActive: Bool        // アプリ表示に反映中か（複数中1つ）
    var lastModified: Date

    init(id: UUID = UUID(), fileName: String, isActive: Bool = false, lastModified: Date = .now)
}
```

---

## 3. DTO（ファイル入出力の中間表現）

SwiftData の `@Model` を直接 Codable にせず、入出力専用の `Codable struct` を分離する。JSON スキーマ（§3.1）と内部モデルの変更を独立させられる。

### 3.1 BackupFileDTO.swift
```swift
struct BackupFileDTO: Codable {
    let version: Int
    let tags: [TagDTO]
    let tasks: [TaskDTO]
}
```

### 3.2 TaskDTO.swift
```swift
struct TaskDTO: Codable {
    let id: String          // 検証段階では String、反映時に UUID 化
    let name: String
    let isFavorite: Bool
    let isCompleted: Bool
    let date: String        // ISO 8601（日付）
    let tagIDs: [String]
}
```

### 3.3 TagDTO.swift
```swift
struct TagDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
}
```

---

## 4. Services（ロジック層）

### 4.1 SnapshotManager.swift
役割: DailySnapshot の確定・更新・参照（設計書§1.4, §4.2）。確定時に表示用集計値と種データ（`taskRecords`）の両方を書き込む。

```swift
@MainActor
final class SnapshotManager {
    init(context: ModelContext)

    /// その日のタスク編集時、または日付繰り越し時に呼ぶ。
    /// 集計値（total/completed/perTag）と種データ（taskRecords）の両方を再計算・upsert。
    func updateSnapshot(for date: Date) throws

    /// 日付が変わった際の確定処理。前日分を確定し、必要なら当日分を初期化。
    func rolloverIfNeeded(now: Date) throws

    /// 指定日のSnapshotを取得（過去グラフ参照用）。
    func snapshot(for date: Date) -> DailySnapshot?

    /// 期間内のSnapshotを取得。
    func snapshots(in range: ClosedRange<Date>) -> [DailySnapshot]
}
```

### 4.2 AchievementCalculator.swift
役割: 達成率算出。当日はリアルタイム、過去は Snapshot 参照（設計書§4.1）。0/0は「データなし」。

```swift
enum AchievementValue {
    case rate(Double)   // 0.0〜1.0
    case noData         // 0/0。0%と区別
}

struct AchievementCalculator {
    /// 当日: tasks から直接算出。
    func rateForToday(tasks: [Task]) -> AchievementValue

    /// 過去: Snapshot の集計値から算出（再計算しない）。
    func rate(from snapshot: DailySnapshot) -> AchievementValue
}
```

### 4.3 TagAggregator.swift
役割: タグフィルタ時の集計。選択タグの**和集合**・重複排除（設計書§2.2, §4.1）。
現段階（案A）では当日のタスク実体に対してのみ和集合を算出する。過去日の和集合は、将来の案B拡張時に `DailySnapshot.taskRecords`（種データ）を入力として有効化する。

```swift
struct TagAggregator {
    /// 当日：選択タグのいずれかに属するユニークタスクを返す（和集合・二重計上なし）。
    func tasksMatchingAnyTag(_ tagIDs: Set<UUID>, from tasks: [Task]) -> [Task]

    /// 当日：和集合のユニークタスクから分母・分子を算出。
    func aggregateToday(_ selected: Set<UUID>, from tasks: [Task]) -> AchievementValue

    /// 【案B拡張用・現在は未使用】過去日：種データ taskRecords から和集合・重複排除して算出。
    /// 案A段階ではこのパスは呼ばれない（過去日の複数タグ選択はUIで抑止）。
    func aggregatePast(_ selected: Set<UUID>, from records: [TaskTagRecord]) -> AchievementValue
}
```
注意（案A段階のUI挙動）: 過去日に対する複数タグ選択フィルタは、当面UI側で抑止またはタグ単体表示に限定する。種データは保存され続けるため、`aggregatePast` を有効化するだけで過去日まで遡って和集合が効くようになる。

### 4.4 BackupCodec.swift
役割: SwiftData ⇔ DTO ⇔ JSON の相互変換（設計書§3.1, §4.3）。

```swift
struct BackupCodec {
    /// 内部モデル → DTO → JSON Data（書き出し用）。
    func encode(tasks: [Task], tags: [Tag]) throws -> Data

    /// JSON Data → DTO（検証前のパースのみ。反映はしない）。
    func decode(_ data: Data) throws -> BackupFileDTO
}
```

### 4.5 BackupValidator.swift
役割: JSONスキーマ検証（設計書§3.2 の7ルール）。**検証は全ルール実施し、違反が1つでもあれば保存／追加を拒否する。** ただしエラー表示は汎用に留め、フィールドパスや行番号などの詳細は出さない（文法仕様は公式サイト掲載で代替）。

```swift
struct BackupValidator {
    /// 全7ルールを適用。違反があれば throws（汎用エラー）。詳細位置情報は含めない。
    func validate(_ dto: BackupFileDTO) throws

    // 個別ルール（テスト容易性のため分割。返すのは成否のみ）
    func validateVersion(_ dto: BackupFileDTO) throws
    func validateRequiredFieldsAndTypes(_ dto: BackupFileDTO) throws
    func validateDateFormat(_ dto: BackupFileDTO) throws
    func validateColorHex(_ dto: BackupFileDTO) throws
    func validateTagReferences(_ dto: BackupFileDTO) throws   // 孤立参照検出
    func validateUniqueIDs(_ dto: BackupFileDTO) throws
}
```
補足: パース可否（ルール1）は `BackupCodec.decode` の throw で判定し、残り6ルールを本バリデータが担う。エラーUIは「形式が正しくないため保存できません。文法は公式サイトを参照してください」程度の汎用文言（v1申し送り③の確定）。

### 4.6 FileSyncService.swift
役割: 二層構造の橋渡し（設計書§2.3, §4.3）。内部更新→書き出し、ファイル編集→検証→反映。保存先は Documents（§7.4）。

```swift
@MainActor
final class FileSyncService {
    init(context: ModelContext,
         codec: BackupCodec,
         validator: BackupValidator)

    /// 内部DB更新時、isActive なファイルへ書き出し（Documents配下）。
    func exportToActiveFile() throws

    /// ファイル編集保存時。パース→検証→通過時のみ内部DBへ反映。失敗時は反映せず拒否。
    func importFromFile(_ data: Data) throws

    /// ファイル追加時の検証付き取り込み。
    func addFile(name: String, data: Data) throws -> BackupFile
}
```

### 4.7 DateNormalizer.swift
役割: date の時刻正規化と日付繰り越し判定（設計書§4.2）。

```swift
struct DateNormalizer {
    func dayKey(for date: Date) -> Date           // 時刻を切り落とした「日」
    func isNewDay(last: Date, now: Date) -> Bool   // 繰り越し要否
}
```

---

## 5. ViewModels（ハイブリッド方針）

Today は `@Query` でViewが直接DBを購読するためViewModelを置かない。派生状態・副作用が集まる Achievement / Backup のみ ViewModel を採用する。

```swift
@Observable final class AchievementViewModel {
    enum Period { case week, month }
    var period: Period
    var anchorDate: Date          // 表示中の週/月の基準
    var selectedTagIDs: Set<UUID>
    var points: [(date: Date, value: AchievementValue)]
    func moveBackward(); func moveForward()
    // 案A段階：過去日 × 複数タグ選択は抑止 or タグ単体表示に限定
}

@Observable final class BackupViewModel {
    var files: [BackupFile]
    var hasValidationError: Bool        // 詳細は持たず、汎用エラー表示のフラグのみ
    func setActive(_ file: BackupFile)
    func save(_ editedText: String)     // 検証→拒否（汎用エラー） or 反映
}
```

（Today用のタスク操作は View 内で `modelContext` 経由、または薄い補助関数として実装。ViewModelは設けない。）

---

## 6. Views

### 6.1 RootTabView.swift
役割: 3タブ（今日のタスク／達成状況グラフ／保存データ）のルート。

```swift
struct RootTabView: View {
    var body: some View   // TabView { TodayTasksView; AchievementChartView; BackupListView }
}
```

### 6.2 Today/
- `TodayTasksView`: 当日Task一覧を `@Query` で取得。お気に入りを上部ピン留め（設計書§2.1）。空状態は `EmptyStateView`。
- `TaskRowView`: タスク名・お気に入りトグル・実行済みチェックボックス。
- `TaskEditorView`: 追加・編集フォーム（名前・タグ選択）。
- `TagEditorView`: タグ追加・編集・削除。削除時はTask維持・tagIDs除去・過去Snapshot保持（設計書§2.1）。

```swift
struct TodayTasksView: View {
    @Query var tasks: [Task]
    var body: some View
}
struct TaskRowView: View {
    let task: Task
    var onToggleFavorite: () -> Void
    var onToggleCompleted: () -> Void
    var body: some View
}
struct TaskEditorView: View { /* @Binding draft */ var body: some View }
struct TagEditorView: View { var body: some View }
```

### 6.3 Achievement/
- `AchievementChartView`: Swift Charts の折れ線。横軸=時間、縦軸=達成率0〜100%。noData は点を打たない（設計書§2.2）。
- `PeriodSelectorView`: 週/月切り替え、左右矢印で前後移動（デフォルト今週）。
- `TagFilterView`: タグ複数選択。和集合表示（過去日は案A段階で抑止）。

```swift
struct AchievementChartView: View {
    @State var vm: AchievementViewModel
    var body: some View
}
struct PeriodSelectorView: View {
    @Binding var period: AchievementViewModel.Period
    var onPrev: () -> Void
    var onNext: () -> Void
    var body: some View
}
struct TagFilterView: View {
    @Binding var selected: Set<UUID>
    let tags: [Tag]
    var body: some View
}
```

### 6.4 Backup/
- `BackupListView`: ファイル一覧。isActive を1つ選択。追加可。
- `BackupDetailEditorView`: 編集→保存時に検証。不正なら拒否。
- `ValidationErrorView`: 汎用エラーメッセージ表示（詳細位置情報は出さない）。

```swift
struct BackupListView: View {
    @State var vm: BackupViewModel
    var body: some View
}
struct BackupDetailEditorView: View { var body: some View }
struct ValidationErrorView: View {
    // 汎用メッセージのみ。文法詳細は公式サイト誘導
    var body: some View
}
```

---

## 7. Support / 横断

### 7.1 PresetColors.swift
```swift
enum PresetColors {
    static let all: [String]                 // 許可された colorHex 一覧
    static func isAllowed(_ hex: String) -> Bool
}
```

### 7.2 ValidationError.swift
役割: 検証違反の型。ルール種別は内部判定・ログ用に保持するが、UI表示は汎用文言に統一し、フィールドパスや行番号は持たない（v1申し送り③の確定）。

```swift
struct ValidationError: Error {
    enum Rule {
        case parseFailed, unknownVersion, missingOrTypeMismatch,
             invalidDate, invalidColor, orphanTagReference, duplicateID
    }
    let rule: Rule                 // 内部用（ログ・テスト）。UIには出さない
    // ユーザー向けは固定の汎用メッセージを別途用意（例：「形式が正しくないため保存できません」）
}
```

### 7.3 Date+DayKey.swift
```swift
extension Date {
    var dayKey: Date   // 時刻を切り落とした日付キー
}
```

### 7.4 ファイル保存先（確定方針）
- 保存実体: `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` 配下にJSONを置く。`BackupFile.fileName` がこのディレクトリ内のファイルに対応。
- 外部公開: `Info.plist` に `UIFileSharingEnabled` と `LSSupportsOpeningDocumentsInPlace` を設定し、Files.app / iCloud Drive から直接編集可能にする。
- インポート: SwiftUI の `.fileImporter` でユーザーが任意JSONを選択 → 検証 → 取り込み。
- 不採用: `Application Support`（ユーザーから隠れる）／`Caches`（OS削除リスクで全損方針に反する）。

---

## 8. 確定事項（v1申し送りの結論）

| # | 項目 | 確定内容 |
|---|---|---|
| 1 | 和集合集計 | 案A（表示は集計値）を採用。加えて `DailySnapshot.taskRecords` に種データを保存。現在は読まないが、将来 `TagAggregator.aggregatePast` を有効化すれば過去日まで遡って和集合が効く。案A→案Bの拡張はデータ追加のみで後方互換。 |
| 2 | perTag 永続化 | タプル不可のため `TagCount`（Codable struct）に置換し `[UUID: TagCount]` で保持。 |
| 3 | JSON検証エラー | 7ルールの検証は実施し不正は保存／追加を拒否。エラーUIは汎用文言に統一し、位置情報・行番号は出さない。文法仕様は公式サイト掲載で代替。 |
| 4 | ファイル保存先 | Documents 配下＋Files.app公開（`UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`、`.fileImporter`）。 |
| 5 | ViewModel | ハイブリッド。Today は `@Query` 直結でVMなし、Achievement / Backup のみ VM を採用。 |

### 残る実装時の小確認（致命的でない）
- 種データ `taskRecords` を毎日のSnapshotに持たせる場合の、確定タイミング（編集の都度更新か、繰り越し時のみか）の最終決定。
- `.fileImporter` で取り込んだファイルを Documents 配下へコピーするか、参照のみとするか（`isActive` 同期の都合上、コピー前提を推奨）。

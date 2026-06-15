//
//  BackupViewModel.swift
//  DailyTask
//
//  保存データ画面の派生状態・副作用を集約（構成書 §5, §6.4 / 設計書 §2.3）。
//  検証は FileSyncService に委譲し、失敗時は反映せず汎用エラーフラグのみ立てる
//  （詳細位置情報は持たない・出さない＝§8 確定事項③）。
//

import Foundation
import SwiftData

@MainActor
@Observable
final class BackupViewModel {
    var files: [BackupFile]
    var hasValidationError: Bool        // 詳細は持たず、汎用エラー表示のフラグのみ

    private let context: ModelContext
    private let sync: FileSyncService
    private let snapshotManager: SnapshotManager

    init(context: ModelContext) {
        self.context = context
        self.sync = FileSyncService(context: context,
                                    codec: BackupCodec(),
                                    validator: BackupValidator())
        self.snapshotManager = SnapshotManager(context: context)
        self.files = []
        self.hasValidationError = false
        reloadFiles()
    }

    /// BackupFile 一覧を再取得する。
    func reloadFiles() {
        let descriptor = FetchDescriptor<BackupFile>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])
        files = (try? context.fetch(descriptor)) ?? []
    }

    /// 指定ファイルを isActive にし、その内容を内部DBへ反映する。
    /// 反映に失敗（検証 NG・読込不可）した場合は active 切り替えを行わずエラーを立てる。
    func setActive(_ file: BackupFile) {
        guard let data = readData(of: file) else {
            hasValidationError = true
            return
        }
        do {
            try sync.importFromFile(data)
            refreshSnapshotsAfterImport()
            for f in files { f.isActive = (f.id == file.id) }
            try context.save()
            hasValidationError = false
            reloadFiles()
        } catch {
            hasValidationError = true
        }
    }

    /// 編集テキストを保存する。検証 → 拒否（汎用エラー）or 反映。
    /// 反映成功時は内部DB（正本）から active ファイルへ書き戻して同期する。
    func save(_ editedText: String) {
        let data = Data(editedText.utf8)
        do {
            try sync.importFromFile(data)       // パース→検証→反映（失敗時はここで throw）
            refreshSnapshotsAfterImport()
            try sync.exportToActiveFile()       // 正本から active ファイルへ正規化して書き戻し
            hasValidationError = false
            reloadFiles()
        } catch {
            hasValidationError = true
        }
    }

    /// 検証付きでファイルを追加（Documents へコピー・active 化はしない）。
    func addFile(name: String, data: Data) {
        do {
            _ = try sync.addFile(name: name, data: data)
            hasValidationError = false
            reloadFiles()
        } catch {
            hasValidationError = true
        }
    }

    /// 指定ファイルの現在のテキストを返す（編集画面の初期表示用）。
    func text(of file: BackupFile) -> String {
        guard let data = readData(of: file) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - 内部

    /// 反映でタスクが入れ替わった後、当日 Snapshot を再計算し過去日を確定する。
    private func refreshSnapshotsAfterImport() {
        try? snapshotManager.updateSnapshot(for: .now)
        try? snapshotManager.rolloverIfNeeded(now: .now)
    }

    private func readData(of file: BackupFile) -> Data? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file.fileName)
        return try? Data(contentsOf: url)
    }
}

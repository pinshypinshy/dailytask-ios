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
    /// 戻り値は保存成否（成功 true / 検証 NG・反映失敗 false）。
    @discardableResult
    func save(_ editedText: String) -> Bool {
        let data = Data(editedText.utf8)
        do {
            try sync.importFromFile(data)       // パース→検証→反映（失敗時はここで throw）
            refreshSnapshotsAfterImport()
            try sync.exportToActiveFile()       // 正本から active ファイルへ正規化して書き戻し
            hasValidationError = false
            reloadFiles()
            return true
        } catch {
            hasValidationError = true
            return false
        }
    }

    /// 指定したファイルを削除する（Documents 上の実体 + BackupFile レコード）。
    /// 正本は SwiftData 側にあるため、active ファイルを削除してもアプリ表示データは失われない。
    func delete(_ filesToDelete: [BackupFile]) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for file in filesToDelete {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(file.fileName))
            context.delete(file)
        }
        try? context.save()
        reloadFiles()
    }

    /// 空データ（タスク・タグ0件）の新規ファイルを作成する。active 化はしない。
    /// 検証を通る正規 JSON（`{"version":n,"tags":[],"tasks":[]}`）を生成して追加する。
    func createNewFile(named rawName: String) {
        guard let data = try? BackupCodec().encode(tasks: [], tags: []) else {
            hasValidationError = true
            return
        }
        addFile(name: uniqueName(from: rawName), data: data)
    }

    /// 新規作成時のデフォルト候補名（既存と重複しないもの）。
    func suggestedNewFileName() -> String {
        uniqueName(from: "DailyTask")
    }

    /// 既存ファイル名と衝突しない名前（拡張子なし）を返す。
    private func uniqueName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (trimmed.isEmpty ? "DailyTask" : trimmed)
            .replacingOccurrences(of: ".json", with: "")
        let existing = Set(files.map { $0.fileName })
        if !existing.contains(base + ".json") { return base }
        var i = 2
        while existing.contains("\(base)-\(i).json") { i += 1 }
        return "\(base)-\(i)"
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

    /// 指定ファイルの実体 URL（Documents 配下）。共有／書き出し用。
    /// 実ファイルが存在しない場合は nil。
    func fileURL(of file: BackupFile) -> URL? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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

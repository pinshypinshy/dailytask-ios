//
//  FileSyncService.swift
//  DailyTask
//
//  二層構造の橋渡し（設計書 §2.3, §4.3 / 構成書 §4.6, §7.4）。
//  内部DB更新 → isActive なファイルへ書き出し。
//  ファイル編集保存／追加 → パース → 検証 → 通過時のみ内部DBへ反映（失敗時は反映せず拒否）。
//  保存先は Documents 配下。インポートしたファイルは Documents へコピーする方針。
//

import Foundation
import SwiftData

@MainActor
final class FileSyncService {
    private let context: ModelContext
    private let codec: BackupCodec
    private let validator: BackupValidator

    init(context: ModelContext,
         codec: BackupCodec,
         validator: BackupValidator) {
        self.context = context
        self.codec = codec
        self.validator = validator
    }

    /// 内部DB更新時、isActive なファイルへ書き出し（Documents 配下）。
    /// active が無ければデフォルトファイルを作成して active にする。
    func exportToActiveFile() throws {
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let data = try codec.encode(tasks: tasks, tags: tags)

        let active = try context.fetch(
            FetchDescriptor<BackupFile>(predicate: #Predicate { $0.isActive })
        ).first

        let file: BackupFile
        if let active {
            file = active
        } else {
            let def = BackupFile(fileName: "DailyTask.json", isActive: true)
            context.insert(def)
            file = def
        }

        try data.write(to: fileURL(file.fileName), options: .atomic)
        file.lastModified = .now
        try context.save()
    }

    /// ファイル編集保存時。パース → 検証 → 通過時のみ内部DBへ反映。失敗時は反映せず拒否。
    func importFromFile(_ data: Data) throws {
        let dto = try codec.decode(data)
        try validator.validate(dto)
        try reflect(dto)
    }

    /// ファイル追加時の検証付き取り込み。検証通過後、Documents へコピーして BackupFile を登録する。
    /// 反映（active 化）は行わない（active 切り替えは BackupViewModel.setActive の責務）。
    func addFile(name: String, data: Data) throws -> BackupFile {
        let dto = try codec.decode(data)
        try validator.validate(dto)

        let fileName = name.hasSuffix(".json") ? name : name + ".json"
        try data.write(to: fileURL(fileName), options: .atomic)

        let file = BackupFile(fileName: fileName, isActive: false)
        context.insert(file)
        try context.save()
        return file
    }

    // MARK: - 反映（DTO → 内部DB）

    /// 検証通過済み DTO を内部DBへ反映する。
    /// MVP は全置換：既存 Tag / TaskItem を削除し、ファイル内容で再構築する。
    /// DailySnapshot は過去グラフ保持のため削除しない。
    private func reflect(_ dto: BackupFileDTO) throws {
        for task in try context.fetch(FetchDescriptor<TaskItem>()) { context.delete(task) }
        for tag in try context.fetch(FetchDescriptor<Tag>()) { context.delete(tag) }

        for dtoTag in dto.tags {
            guard let id = UUID(uuidString: dtoTag.id) else {
                throw ValidationError(rule: .missingOrTypeMismatch)
            }
            context.insert(Tag(id: id, name: dtoTag.name, colorHex: dtoTag.colorHex))
        }

        for dtoTask in dto.tasks {
            guard let id = UUID(uuidString: dtoTask.id) else {
                throw ValidationError(rule: .missingOrTypeMismatch)
            }
            guard let parsedDate = BackupCodec.isoDateFormatter.date(from: dtoTask.date) else {
                throw ValidationError(rule: .invalidDate)
            }
            let tagIDs = try dtoTask.tagIDs.map { raw -> UUID in
                guard let uuid = UUID(uuidString: raw) else {
                    throw ValidationError(rule: .missingOrTypeMismatch)
                }
                return uuid
            }
            context.insert(TaskItem(id: id,
                                    name: dtoTask.name,
                                    isFavorite: dtoTask.isFavorite,
                                    isCompleted: dtoTask.isCompleted,
                                    isRecurring: dtoTask.isRecurring ?? false,
                                    date: parsedDate.dayKey,
                                    tagIDs: tagIDs))
        }
        try context.save()
    }

    // MARK: - Documents パス

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(_ name: String) -> URL {
        documentsDirectory().appendingPathComponent(name)
    }
}

//
//  TagEditorView.swift
//  DailyTask
//
//  タグの追加・編集・削除（構成書 §6.2 / 設計書 §2.1）。
//  タグ削除時は Task 自体は残し、各 Task の tagIDs から該当IDを除去する。
//  過去の DailySnapshot.perTag は保持する（過去グラフを壊さないため）。
//

import SwiftUI
import SwiftData

struct TagEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newName: String = ""
    @State private var newHex: String = PresetColors.all.first ?? "#4A90D9"

    var body: some View {
        NavigationStack {
            Form {
                Section("タグを追加") {
                    TextField("タグ名", text: $newName)
                    PresetColorPicker(selectedHex: $newHex)
                    Button("追加") { addTag() }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("タグ一覧") {
                    if tags.isEmpty {
                        Text("タグがありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            HStack {
                                Circle().fill(Color(hex: tag.colorHex)).frame(width: 14, height: 14)
                                Text(tag.name)
                            }
                        }
                        .onDelete(perform: deleteTags)
                    }
                }
            }
            .navigationTitle("タグの管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func addTag() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(Tag(name: name, colorHex: newHex))
        newName = ""
        persistAndSync()
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            let id = tag.id
            // 各 Task の tagIDs から除去（Task 自体は残す）。
            if let all = try? context.fetch(FetchDescriptor<TaskItem>()) {
                for task in all where task.tagIDs.contains(id) {
                    task.tagIDs.removeAll { $0 == id }
                }
            }
            context.delete(tag)
        }
        persistAndSync()
    }

    /// 保存 → 当日 Snapshot 更新 → active ファイルへ書き出し。
    private func persistAndSync() {
        try? context.save()
        let snapshotManager = SnapshotManager(context: context)
        try? snapshotManager.updateSnapshot(for: .now)
        let sync = FileSyncService(context: context, codec: BackupCodec(), validator: BackupValidator())
        try? sync.exportToActiveFile()
    }
}

//
//  TaskEditorView.swift
//  DailyTask
//
//  タスクの追加・編集フォーム（名前・お気に入り・タグ選択）（構成書 §6.2）。
//  追加と編集の双方を扱い、確定結果はクロージャで親へ返す（永続化は親の責務）。
//

import SwiftUI

struct TaskEditorView: View {
    let tags: [Tag]
    let onCommit: (_ name: String, _ isFavorite: Bool, _ tagIDs: [UUID]) -> Void

    @State private var name: String
    @State private var isFavorite: Bool
    @State private var selectedTagIDs: Set<UUID>
    private let title: String
    @Environment(\.dismiss) private var dismiss

    init(task: TaskItem? = nil,
         tags: [Tag],
         onCommit: @escaping (String, Bool, [UUID]) -> Void) {
        self.tags = tags
        self.onCommit = onCommit
        _name = State(initialValue: task?.name ?? "")
        _isFavorite = State(initialValue: task?.isFavorite ?? false)
        _selectedTagIDs = State(initialValue: Set(task?.tagIDs ?? []))
        self.title = task == nil ? "タスクを追加" : "タスクを編集"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タスク名", text: $name)
                    Toggle("お気に入り", isOn: $isFavorite)
                }
                Section("タグ") {
                    if tags.isEmpty {
                        Text("タグがありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            Button { toggle(tag.id) } label: {
                                HStack {
                                    Circle().fill(Color(hex: tag.colorHex)).frame(width: 12, height: 12)
                                    Text(tag.name).foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagIDs.contains(tag.id) {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onCommit(name.trimmingCharacters(in: .whitespacesAndNewlines),
                                 isFavorite,
                                 Array(selectedTagIDs))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedTagIDs.contains(id) { selectedTagIDs.remove(id) }
        else { selectedTagIDs.insert(id) }
    }
}

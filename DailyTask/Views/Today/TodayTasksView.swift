//
//  TodayTasksView.swift
//  DailyTask
//
//  今日のタスク一覧（構成書 §6.2 / 設計書 §2.1）。
//  ViewModel を置かず @Query で直接 SwiftData を購読し、操作は modelContext ＋
//  薄い補助関数で行う（ハイブリッド方針：Today は VM なし）。
//  お気に入りは上部にピン留め。空状態は EmptyStateView。
//

import SwiftUI
import SwiftData

struct TodayTasksView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    @State private var showingTags = false
    @State private var selectedTagIDs: Set<UUID> = []

    /// 当日分のみ抽出し、お気に入り優先・作成日時順に並べる。
    private var todayTasks: [TaskItem] {
        let today = Date.now.dayKey
        return allTasks
            .filter { $0.date == today }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// 選択タグの和集合で当日タスクを絞り込む（設計書 §4.1）。未選択時は全件。
    /// Today は当日のみのため案Aの過去日抑止の対象外。
    private var filteredTasks: [TaskItem] {
        let selection = activeSelection
        guard !selection.isEmpty else { return todayTasks }
        return todayTasks.filter { !Set($0.tagIDs).isDisjoint(with: selection) }
    }

    /// 既に削除されたタグが選択に残らないよう、実在するタグIDのみへ絞る。
    private var activeSelection: Set<UUID> {
        selectedTagIDs.intersection(Set(tags.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !tags.isEmpty && !todayTasks.isEmpty {
                    TagFilterBar(selected: $selectedTagIDs, tags: tags)
                    Divider()
                }
                content
            }
            .navigationTitle("今日のタスク")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingTags = true } label: { Label("タグ", systemImage: "tag") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Label("追加", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                TaskEditorView(tags: tags) { name, isFavorite, tagIDs in
                    addTask(name: name, isFavorite: isFavorite, tagIDs: tagIDs)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorView(task: task, tags: tags) { name, isFavorite, tagIDs in
                    applyEdit(task, name: name, isFavorite: isFavorite, tagIDs: tagIDs)
                }
            }
            .sheet(isPresented: $showingTags) {
                TagEditorView()
            }
            .task { runRollover() }
        }
    }

    /// タスク一覧本体。空状態は「未登録」と「絞り込み該当なし」を区別する。
    @ViewBuilder
    private var content: some View {
        if todayTasks.isEmpty {
            EmptyStateView(message: "今日のタスクはありません", systemImage: "checklist")
        } else if filteredTasks.isEmpty {
            EmptyStateView(message: "該当するタスクはありません", systemImage: "line.3.horizontal.decrease.circle")
        } else {
            List {
                ForEach(filteredTasks) { task in
                    TaskRowView(
                        task: task,
                        onToggleFavorite: { toggleFavorite(task) },
                        onToggleCompleted: { toggleCompleted(task) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = task }
                }
                .onDelete(perform: deleteTasks)
            }
        }
    }

    // MARK: - タスク操作（薄い補助関数）

    private func addTask(name: String, isFavorite: Bool, tagIDs: [UUID]) {
        guard !name.isEmpty else { return }
        let task = TaskItem(name: name,
                            isFavorite: isFavorite,
                            date: Date.now.dayKey,
                            tagIDs: tagIDs)
        context.insert(task)
        persistAndSync()
    }

    private func applyEdit(_ task: TaskItem, name: String, isFavorite: Bool, tagIDs: [UUID]) {
        guard !name.isEmpty else { return }
        task.name = name
        task.isFavorite = isFavorite
        task.tagIDs = tagIDs
        persistAndSync()
    }

    private func toggleFavorite(_ task: TaskItem) {
        task.isFavorite.toggle()
        persistAndSync()
    }

    private func toggleCompleted(_ task: TaskItem) {
        task.isCompleted.toggle()
        persistAndSync()
    }

    private func deleteTasks(at offsets: IndexSet) {
        let items = filteredTasks
        for index in offsets { context.delete(items[index]) }
        persistAndSync()
    }

    // MARK: - 永続化・同期

    /// 保存 → 当日 Snapshot 更新 → active ファイルへ書き出し（設計書 §4.3）。
    private func persistAndSync() {
        try? context.save()
        let snapshotManager = SnapshotManager(context: context)
        try? snapshotManager.updateSnapshot(for: .now)
        let sync = FileSyncService(context: context, codec: BackupCodec(), validator: BackupValidator())
        try? sync.exportToActiveFile()
    }

    /// 起動・表示時の日付繰り越し確定（前日以前の未確定 Snapshot を確定）。
    private func runRollover() {
        let snapshotManager = SnapshotManager(context: context)
        try? snapshotManager.rolloverIfNeeded(now: .now)
    }
}

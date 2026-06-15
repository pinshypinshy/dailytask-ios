//
//  BackupListView.swift
//  DailyTask
//
//  保存ファイル一覧（構成書 §6.4 / 設計書 §2.3）。
//  isActive を1つ選択（反映）。ファイル追加は .fileImporter で検証付き取り込み。
//  ViewModel は modelContext から自前で構築する。
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupListView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: BackupViewModel?
    @State private var importing = false
    @State private var editingFile: BackupFile?
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<BackupFile.ID> = []
    @State private var creatingNew = false
    @State private var newFileName = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    listContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("保存データ")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let vm, !vm.files.isEmpty {
                        Button(editMode.isEditing ? "完了" : "選択") { toggleEditing() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editMode.isEditing {
                        Button { editSelected() } label: {
                            Label("編集", systemImage: "square.and.pencil")
                                .labelStyle(.titleAndIcon)
                        }
                        .disabled(selection.count != 1)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editMode.isEditing {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label(selection.isEmpty ? "削除" : "削除 (\(selection.count))",
                                  systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                        .disabled(selection.isEmpty)
                    } else {
                        Menu {
                            Button { startNewFile() } label: {
                                Label("新規作成", systemImage: "doc.badge.plus")
                            }
                            Button { importing = true } label: {
                                Label("ファイルを開く", systemImage: "folder")
                            }
                        } label: {
                            Label("追加", systemImage: "plus")
                        }
                    }
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("新規作成", isPresented: $creatingNew) {
                TextField("ファイル名", text: $newFileName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("作成") { vm?.createNewFile(named: newFileName) }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("空のデータでファイルを作成します。")
            }
            .alert("削除しますか？", isPresented: $confirmingDelete) {
                Button("削除", role: .destructive) { if let vm { deleteSelected(vm) } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("選択した \(selection.count) 件のファイルを削除します。この操作は取り消せません。")
            }
        }
        .task {
            if vm == nil { vm = BackupViewModel(context: context) }
            vm?.reloadFiles()
        }
    }

    // MARK: - 一覧

    @ViewBuilder
    private func listContent(_ vm: BackupViewModel) -> some View {
        if vm.files.isEmpty {
            EmptyStateView(message: "保存ファイルがありません", systemImage: "externaldrive")
        } else {
            List(selection: $selection) {
                Section(footer: Text("タップで反映先を切り替え。左スワイプで編集・書き出し。「選択」で削除。")) {
                    ForEach(vm.files) { file in
                        Button { if !editMode.isEditing { vm.setActive(file) } } label: {
                            row(file)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("編集") { editingFile = file }
                                .tint(.gray)
                            if let url = vm.fileURL(of: file) {
                                ShareLink(item: url) {
                                    Label("書き出し", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
                Section {
                    helpLinkRow
                }
            }
            .navigationDestination(item: $editingFile) { file in
                BackupDetailEditorView(vm: vm, file: file)
            }
            .alert("保存できません",
                   isPresented: Binding(get: { vm.hasValidationError },
                                        set: { vm.hasValidationError = $0 })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(ValidationError.userFacingMessage)
            }
        }
    }

    private func row(_ file: BackupFile) -> some View {
        HStack {
            Image(systemName: file.isActive ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(file.isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading) {
                Text(file.fileName)
                    .foregroundStyle(.primary)
                Text(file.lastModified.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - ヘルプ

    private var helpLinkRow: some View {
        Link(destination: URL(string: "https://dailytask.yuki-hiraishi.com")!) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Color.accentColor)
                Text("JSONファイルの指定の文法を公式サイトで確認する")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: - 選択・削除

    private func toggleEditing() {
        withAnimation {
            editMode = editMode.isEditing ? .inactive : .active
        }
        if !editMode.isEditing { selection.removeAll() }
    }

    private func editSelected() {
        guard let vm, let file = vm.files.first(where: { selection.contains($0.id) }) else { return }
        withAnimation { editMode = .inactive }
        selection.removeAll()
        editingFile = file
    }

    private func deleteSelected(_ vm: BackupViewModel) {
        let targets = vm.files.filter { selection.contains($0.id) }
        vm.delete(targets)
        selection.removeAll()
        if vm.files.isEmpty { withAnimation { editMode = .inactive } }
    }

    // MARK: - 新規作成

    private func startNewFile() {
        newFileName = vm?.suggestedNewFileName() ?? "DailyTask"
        creatingNew = true
    }

    // MARK: - インポート

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let vm else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                vm.hasValidationError = true
                return
            }
            vm.addFile(name: url.lastPathComponent, data: data)
        case .failure:
            vm.hasValidationError = true
        }
    }
}

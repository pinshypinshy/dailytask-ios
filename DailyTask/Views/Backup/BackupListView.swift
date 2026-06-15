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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Label("追加", systemImage: "plus") }
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
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
            List {
                ForEach(vm.files) { file in
                    NavigationLink {
                        BackupDetailEditorView(vm: vm, file: file)
                    } label: {
                        row(file)
                    }
                    .swipeActions(edge: .leading) {
                        Button("反映") { vm.setActive(file) }
                            .tint(.accentColor)
                    }
                }
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
                Text(file.lastModified.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

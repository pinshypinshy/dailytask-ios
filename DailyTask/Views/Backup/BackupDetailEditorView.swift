//
//  BackupDetailEditorView.swift
//  DailyTask
//
//  保存ファイルの編集・保存（構成書 §6.4 / 設計書 §2.3）。
//  保存時に検証 → 不正なら拒否（汎用エラー表示）、通過時のみ内部DBへ反映。
//

import SwiftUI

struct BackupDetailEditorView: View {
    @Bindable var vm: BackupViewModel
    let file: BackupFile

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if vm.hasValidationError {
                ValidationErrorView()
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(8)
        }
        .navigationTitle(file.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { vm.save(text) }
            }
        }
        .onAppear { text = vm.text(of: file) }
    }
}

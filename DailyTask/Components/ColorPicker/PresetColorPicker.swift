//
//  PresetColorPicker.swift
//  DailyTask
//
//  プリセットカラー選択（構成書 §6/§7.1）。MVP はプリセット固定（自由選択は対象外）。
//  選択結果は colorHex 文字列として双方向バインドする。
//

import SwiftUI

struct PresetColorPicker: View {
    @Binding var selectedHex: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PresetColors.all, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if hex.uppercased() == selectedHex.uppercased() {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay {
                        Circle().stroke(.primary.opacity(0.15), lineWidth: 1)
                    }
                    .onTapGesture { selectedHex = hex }
                    .accessibilityLabel(hex)
            }
        }
    }
}

//
//  TagFilterView.swift
//  DailyTask
//
//  タグ複数選択フィルタ（構成書 §6.3 / 設計書 §2.2）。
//  当日は和集合表示。過去日の複数タグ選択は案A段階で抑止（VM 側で noData 化）。
//

import SwiftUI

struct TagFilterView: View {
    @Binding var selected: Set<UUID>
    let tags: [Tag]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !tags.isEmpty {
                Text("タグフィルタ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags) { tag in
                            chip(for: tag)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for tag: Tag) -> some View {
        let isOn = selected.contains(tag.id)
        let color = Color(hex: tag.colorHex)
        Button {
            toggle(tag.id)
        } label: {
            Text(tag.name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isOn ? color.opacity(0.20) : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule().stroke(isOn ? color : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(isOn ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }
}

//
//  TagFilterBar.swift
//  DailyTask
//
//  タグ複数選択の絞り込みバー（横断的な小UI）。横スクロールのチップを並べ、
//  タップで選択／解除する。選択集合は親が `selected` で保持し、絞り込みは
//  選択タグの和集合（設計書 §4.1）で行う想定。未選択は「絞り込みなし」を表す。
//
//  構成書 §6.3 の TagFilterView と同じ汎用シグネチャ（selected / tags）を踏襲し、
//  Today・Achievement の双方から再利用できるよう Components に置く。
//

import SwiftUI

struct TagFilterBar: View {
    @Binding var selected: Set<UUID>
    let tags: [Tag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    chip(for: tag)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(for tag: Tag) -> some View {
        let isOn = selected.contains(tag.id)
        let color = Color(hex: tag.colorHex)
        return Button {
            toggle(tag.id)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(tag.name)
                    .font(.subheadline)
            }
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
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

//
//  TaskRowView.swift
//  DailyTask
//
//  今日のタスク1行：タスク名・お気に入りトグル・実行済みチェックボックス（構成書 §6.2）。
//  操作はクロージャで親（TodayTasksView）へ委譲する。
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var onToggleFavorite: () -> Void
    var onToggleCompleted: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleCompleted) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.name)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            if task.isRecurring {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("毎日繰り返す")
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: task.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(task.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}

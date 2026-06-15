//
//  ValidationErrorView.swift
//  DailyTask
//
//  検証エラーの汎用メッセージ表示（構成書 §6.4 / §8 確定事項③）。
//  位置情報・行番号などの詳細は出さず、固定の汎用文言のみ。文法は公式サイト誘導。
//

import SwiftUI

struct ValidationErrorView: View {
    var body: some View {
        Label(ValidationError.userFacingMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
    }
}

//
//  BackupFileDTO.swift
//  DailyTask
//
//  JSON ルート（version / tags / tasks）の Codable 表現（構成書 §3.1）。
//  BackupCodec がこの型に decode し、BackupValidator が7ルール検証を行う。
//

import Foundation

struct BackupFileDTO: Codable {
    let version: Int
    let tags: [TagDTO]
    let tasks: [TaskDTO]
}

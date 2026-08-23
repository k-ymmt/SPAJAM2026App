//
//  MemberResult.swift
//  SPAJAM2026App
//
//  結果共有(rooms/{code}/results)に届いたメンバーの結果をまとめる。
//  リザルト画面 ver1 は自分の心拍だけを表示するため画面では使わないが、
//  ルームへ送る `TripSession.memberResult`(bpmBars)と、メンバー一覧の組み立てはここに残す。
//

import SwiftUI

/// 結果発表に並ぶメンバー 1 人分の結果
struct MemberResult: Identifiable {
    var id: String { name }
    var name: String
    var color: Color
    var isMe = false
    var total: Int
    var achievedMissionIds: Set<String>
    /// 時間帯ごとの心拍変動量(グラフ用・正規化済み 0...1)
    var bpmBars: [Double]

    /// 他のメンバーに順番に割り当てる色
    static let memberColors: [Color] = [
        .appAccentSoft,
        Color(red: 0.769, green: 0.643, blue: 0.420),
        Color(red: 0.45, green: 0.62, blue: 0.55),
        Color(red: 0.55, green: 0.50, blue: 0.72),
    ]

    /// 実同期: 自分(ローカル)+ルームに届いた他メンバーの結果
    static func party(for session: TripSession, results: [TripMemberResult], myUid: String?) -> [MemberResult] {
        let me = MemberResult(
            name: "あなた",
            color: .appAccent,
            isMe: true,
            total: session.totalScore,
            achievedMissionIds: Set(session.records.map(\.missionId)),
            bpmBars: session.myBars
        )
        let others = results
            .filter { $0.id != myUid }
            .enumerated()
            .map { index, result in
                MemberResult(
                    name: result.name,
                    color: memberColors[index % memberColors.count],
                    total: result.total,
                    achievedMissionIds: Set(result.achievedMissionIds),
                    bpmBars: result.bpmBars.count == 6 ? result.bpmBars : [0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
                )
            }
        return [me] + others
    }
}

extension TripSession {
    /// 自分の心拍サンプルを 6 区間の変動量に集計(サンプルが無ければダミー波形)
    var myBars: [Double] {
        let samples = heartRateSamples.map(\.bpm)
        guard samples.count >= 6 else { return [0.35, 0.6, 0.45, 0.8, 0.5, 0.9] }
        let chunk = max(1, samples.count / 6)
        let mean = samples.reduce(0, +) / Double(samples.count)
        return (0..<6).map { i in
            let slice = samples.dropFirst(i * chunk).prefix(chunk)
            guard !slice.isEmpty else { return 0.3 }
            let dev = slice.reduce(0) { $0 + abs($1 - mean) } / Double(slice.count)
            return min(1.0, 0.25 + dev / 30)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
